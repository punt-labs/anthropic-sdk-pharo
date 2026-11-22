#!/usr/bin/env bash
# Regression tests for test exit codes and lifecycle gates, without Pharo.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC2016 # expanded by the stub shell, not here
stub='sh -c '\''printf "%s\n" "$$SUMMARY"; exit "$$RESULT_EXIT"'\'' stub'

# name|summary|curl exit|expected make exit (0 = pass, 1 = fail)
cases=(
	"pass|'Tests: 2  Passed: 2  Failures: 0  Errors: 0'|0|0"
	"failure|'Tests: 2  Passed: 1  Failures: 1  Errors: 0'|0|1"
	"error|'Tests: 2  Passed: 1  Failures: 0  Errors: 1'|0|1"
	"empty||0|1"
	"malformed|HTTP error page|0|1"
	"connection||7|1"
)

failed=0
for target in test test-fast; do
	for entry in "${cases[@]}"; do
		IFS='|' read -r name summary code expected <<<"$entry"
		status=0
		SUMMARY="$summary" RESULT_EXIT="$code" \
			make -s -C "$root" "$target" CURL="$stub" >/dev/null 2>&1 || status=$?
		if { [ "$expected" -eq 0 ] && [ "$status" -ne 0 ]; } ||
			{ [ "$expected" -ne 0 ] && [ "$status" -eq 0 ]; }; then
			echo "FAIL $target $name: exit=$status"
			failed=1
		else
			echo "ok   $target $name: exit=$status"
		fi
	done
done

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
touch "$fixture/Pharo.image"
cat >"$fixture/curl" <<'STUB'
#!/usr/bin/env bash
for arg do
    if [ "$arg" = "'ping'" ]; then
        exit "$PING_EXIT"
    fi
done
echo reload >>"$CALLS"
case " $* " in
    *" -f "*) ;;
    *) exit 99 ;;
esac
printf '%s\n' "$SUMMARY"
exit "$RESULT_EXIT"
STUB
cat >"$fixture/make" <<'STUB'
#!/usr/bin/env bash
for arg do
    case "$arg" in
        --*) ;;
        *)
            echo "$arg" >>"$CALLS"
            if [ "$arg" = start ]; then exit "$START_EXIT"; fi
            exit 0 ;;
    esac
done
exit 99
STUB

for gate in gate-lint gate-check gate-test-fast; do
    target=${gate#gate-}
    for name in running missing-image start-failure reload-error reload-connection reload-empty reload-malformed success; do
        ping=7 start=0 code=0 expected=1 message='FAIL: could not file in src/'
        image="$fixture/Pharo.image"
        summary="'Loaded 23 packages, normalized 0 methods'"
        events=$'start\nreload'
        case "$name" in
            running) ping=0 expected=0 events="$target" message='' ;;
            missing-image) image="$fixture/missing.image" events='' message="run 'make setup'" ;;
            start-failure) start=1 events=start message='FAIL: could not start the eval server' ;;
            reload-error) summary='Error: reload failed' ;;
            reload-connection) code=7 summary='' ;;
            reload-empty) summary='' ;;
            reload-malformed) summary='HTTP error page' ;;
            success) expected=0 events=$'start\nreload\nsync-ref\n'"$target" message='' ;;
        esac
        : >"$fixture/calls"
        status=0
        output=$(PING_EXIT="$ping" START_EXIT="$start" SUMMARY="$summary" RESULT_EXIT="$code" CALLS="$fixture/calls" \
            make -s -C "$root" "$gate" IMAGE="$image" CURL="bash $fixture/curl" MAKE="bash $fixture/make" 2>&1) || status=$?
        actual=$(<"$fixture/calls")
        if { [ "$expected" -eq 0 ] && [ "$status" -ne 0 ]; } ||
            { [ "$expected" -ne 0 ] && [ "$status" -eq 0 ]; } ||
            [ "$actual" != "$events" ] || [[ "$output" != *"$message"* ]]; then
            printf 'FAIL %s %s: exit=%s\ncalls: %s\n%s\n' "$gate" "$name" "$status" "$actual" "$output"
            failed=1
        else
            echo "ok   $gate $name: exit=$status"
        fi
    done
done
exit "$failed"
