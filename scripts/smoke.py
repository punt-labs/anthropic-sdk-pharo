"""Installed-path smoke for anthropic-sdk-pharo observability, standard library only.

Runs ClaudeObservabilitySmoke in a fresh image under isolated HOME directories
and inspects the real files below ~/.punt-labs/anthropic-sdk-pharo: modes,
exact names, rotation bounds, line format, redaction, telemetry rows and the
independent telemetry off switches.
"""

from contextlib import closing
import json
import os
from pathlib import Path
import re
import sqlite3
import stat
import subprocess
import sys

TOOL = "anthropic-sdk-pharo"
BOUND = 5242880
SECRETS = (b"PRIVATE-", b"sk-ant-", b"FIXTURE-KEY", b"FIXTURE-BEARER-SECRET", b"fixture-user",
           b"fixture-pass", b"fixture.example.invalid", b"/private", b"fixture-query",
           b"fixture-fragment", b"smoke.customer@example.invalid", b"localhost", b"127.0.0.1")
LINE = re.compile(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[(DEBUG|INFO|WARNING|ERROR)\] ([a-z][a-z0-9-]*): (.*)")
ATTRIBUTES = {"operation", "outcome", "cause", "retries", "punt.schema.version"}
SPANS = [("ok", "none", 1), ("failed", "auth", 0), ("failed", "server", 2)]


def private(path, mode, is_type):
    meta = path.lstat()
    return is_type(meta.st_mode) and stat.S_IMODE(meta.st_mode) == mode and meta.st_uid == os.getuid()


class Smoke:
    def __init__(self, root, image_dir):
        self.root = root.resolve()
        self.vm = image_dir / "pharo"
        self.image = image_dir / "Pharo.image"
        self.failures = 0

    def check(self, condition, label):
        print(f"{'PASS' if condition else 'FAIL'} {label}", flush=True)
        self.failures += not condition
        return condition

    def launch(self, name, home, expression="ClaudeObservabilitySmoke run", overrides=None):
        directory = self.root / name
        directory.mkdir()
        home.mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, HOME=str(home), PUNT_SMOKE_REPORT=str(directory / "report.json"))
        for key in ("PUNT_TELEMETRY", "ANTHROPIC_SDK_PHARO_TELEMETRY", "PUNT_SMOKE_CONFIG_DISABLED", "PUNT_SMOKE_RECORDS"):
            env.pop(key, None)
        env.update(overrides or {})
        with (directory / "stdout").open("wb") as out, (directory / "stderr").open("wb") as err:
            code = subprocess.run([str(self.vm), "--headless", str(self.image), "--no-default-preferences", "eval", expression],
                                  env=env, cwd=directory, stdin=subprocess.DEVNULL, stdout=out, stderr=err,
                                  timeout=300, check=False).returncode
        if code != 0:
            raise RuntimeError(f"{name}: exit {code}; see {directory / 'stderr'}")
        return directory

    def run_smoke(self, name, home, overrides=None):
        directory = self.launch(name, home, overrides=overrides)
        stdout = (directory / "stdout").read_bytes()
        self.check(stdout.strip() == b"'smoke-ok'", f"{name}: stdout carries only the eval result, no log or telemetry output")
        report = json.loads((directory / "report.json").read_text())
        self.check(report["outcome"] == "ok" and report["worker_stopped"] and report["telemetry_dropped"] == 0
                   and all(value == 0 for value in report["log_drops"].values()),
                   f"{name}: outcome ok, telemetry worker stopped, no telemetry or log drops")
        return report

    def inspect(self, home, backups=0, telemetry=True, runs=1):
        labs = home / ".punt-labs"
        tool = labs / TOOL
        logs = tool / "logs"
        active = logs / f"{TOOL}.log"
        files = [logs / f"{TOOL}.log.{index}" for index in range(backups, 0, -1)] + [active]
        lock = logs / f"{TOOL}.log.rotate.lock"
        database, salt = tool / "telemetry.db", labs / "telemetry.salt"
        self.check(all(private(path, 0o700, stat.S_ISDIR) for path in (labs, tool, logs)), f"{home.name}: .punt-labs/{TOOL}/logs directories 0700, owned by current user")
        self.check(set(logs.iterdir()) == set(files + [lock]), f"{home.name}: exact log/lock names, {backups} backups (maximum 5)")
        sidecars = [Path(str(database) + suffix) for suffix in ("-journal", "-wal", "-shm") if Path(str(database) + suffix).exists()]
        self.check(set(tool.iterdir()) == ({logs, database, *sidecars} if telemetry else {logs}), f"{home.name}: exact tool files")
        extra = [salt] if salt.exists() else []
        self.check(set(labs.iterdir()) == {tool, *extra}, f"{home.name}: no unexpected shared paths")
        owned = files + [lock] + extra + sidecars + ([database] if telemetry else [])
        self.check(all(private(path, 0o600, stat.S_ISREG) for path in owned), f"{home.name}: all {len(owned)} files 0600, owned by current user")
        sizes = [path.stat().st_size for path in files]
        self.check(all(size <= BOUND for size in sizes), f"{home.name}: log files within {BOUND} bytes; sizes={sizes}")
        data = b"".join(path.read_bytes() for path in files)
        text = data.decode("utf-8")
        lines = text[:-1].split("\n") if text.endswith("\n") else []
        self.check(bool(lines) and all(LINE.fullmatch(line) for line in lines), f"{home.name}: {len(lines)} complete lines in timestamp [LEVEL] component: format")
        self.check(not any(ord(char) < 32 and char != "\n" for char in text), f"{home.name}: no raw control characters")
        leaked = [secret.decode() for secret in SECRETS if secret in data]
        self.check(not leaked, f"{home.name}: no prompt, reply, error body, API key, bearer, URL parts, email or host in logs; leaked={leaked}")
        if not telemetry:
            self.check(not database.exists(), f"{home.name}: no telemetry.db created")
            return lines
        with closing(sqlite3.connect(f"file:{database}?mode=ro", uri=True)) as db:
            integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
            rows = db.execute("SELECT signal, name, attributes FROM signals").fetchall()
        attributes = [json.loads(row[2]) for row in rows]
        self.check(integrity == "ok" and all(row[0] == "span" and row[1] == f"{TOOL}.api.request" for row in rows),
                   f"{home.name}: SQLite integrity {integrity}; {len(rows)} {TOOL}.api.request spans")
        self.check(all(set(item) == ATTRIBUTES for item in attributes), f"{home.name}: span attributes exactly {sorted(ATTRIBUTES)}")
        found = sorted((item["outcome"], item["cause"], item["retries"]) for item in attributes if item["operation"] == "messages")
        self.check(found == sorted(SPANS * runs), f"{home.name}: {runs} run(s) of ok/none/1, failed/auth/0, failed/server/2 spans; found={found}")
        blob = database.read_bytes()
        leaked = [secret.decode() for secret in SECRETS if secret in blob]
        self.check(not leaked, f"{home.name}: no content, key, URL or host in database bytes; leaked={leaked}")
        return lines

    def ordinary(self):
        home = self.root / "home-ordinary"
        self.run_smoke("ordinary", home)
        lines = self.inspect(home)
        self.check(any("[INFO] claude-client: API request retry scheduled operation=messages retries=1 maxRetries=2" in line and "errorClass=ClaudeOverloadedError statusCode=529" in line for line in lines), "ordinary: INFO retry record with class and status only")
        self.check(any("[WARNING] claude-client: API request retries exhausted operation=messages retries=2" in line and "statusCode=500" in line for line in lines), "ordinary: WARNING exhaustion record")
        self.check(any("[DEBUG] claude-client: API request failed operation=messages retries=0 errorClass=ClaudeAuthError statusCode=401" in line for line in lines), "ordinary: DEBUG failed outcome record")
        self.check(any("[DEBUG] claude-client: API request completed operation=messages retries=1" in line for line in lines), "ordinary: DEBUG completed outcome record")
        self.check(any("[DEBUG] integration-test: redaction fixture" in line for line in lines), "ordinary: bridged ClaudeTestSignal lands in the shared log, redacted")

    def rotation(self):
        home = self.root / "home-rotation"
        self.run_smoke("rotation", home, {"PUNT_SMOKE_RECORDS": "800"})
        lines = self.inspect(home, backups=5)
        self.check(800 * 47000 > 6 * BOUND, "rotation: 800 ~47 KB records exceed six files (>5 rollovers)")
        tags = [int(match[1]) for match in (re.search(r"TAG-(\d+) p+.* END-\1$", line) for line in lines) if match]
        self.check(bool(tags) and tags == list(range(tags[0], 801)), f"rotation: retained window is contiguous and intact ({len(tags)} records)")
        self.run_smoke("rotation-again", home, {"PUNT_SMOKE_RECORDS": "200"})
        self.inspect(home, backups=5, runs=2)

    def off_switch(self, name, overrides):
        home = self.root / f"home-{name}"
        report = self.run_smoke(name, home, overrides)
        self.check(not report["telemetry_enabled"], f"{name}: telemetry veto leaves no queue")
        self.inspect(home, telemetry=False)
        self.run_smoke(name + "-seed", home)
        database = home / ".punt-labs" / TOOL / "telemetry.db"
        before = database.read_bytes()
        report = self.run_smoke(name + "-again", home, overrides)
        self.check(not report["telemetry_enabled"] and database.read_bytes() == before, f"{name}: veto against an existing database adds no rows (bytes unchanged)")

    def run(self):
        home = self.root / "home-load"
        directory = self.launch("load", home, expression="'loaded'")
        self.check(not (home / ".punt-labs").exists() and (directory / "stdout").read_bytes().strip() == b"'loaded'", "package load starts no logging or telemetry (no ~/.punt-labs)")
        self.ordinary()
        self.rotation()
        self.off_switch("global-off", {"PUNT_TELEMETRY": "off"})
        self.off_switch("tool-off", {"ANTHROPIC_SDK_PHARO_TELEMETRY": "off"})
        self.off_switch("config-off", {"PUNT_SMOKE_CONFIG_DISABLED": "1"})
        print(f"SMOKE {'FAILED' if self.failures else 'OK'}: {self.failures} findings", flush=True)
        return bool(self.failures)


if __name__ == "__main__":
    try:
        sys.exit(Smoke(Path(sys.argv[1]), Path(sys.argv[2]).resolve()).run())
    except (OSError, ValueError, RuntimeError, KeyError, sqlite3.Error, subprocess.TimeoutExpired) as error:
        print(f"FAIL smoke inspection: {error}", file=sys.stderr)
        sys.exit(1)
