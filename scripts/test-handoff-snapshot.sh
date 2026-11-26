#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || ! -f $1 ]]; then
    echo 'Usage: make test-handoff-snapshot HANDOFF_RUNTIME_ARCHIVE=/path/to/pharo-handoff-linux-amd64.tar.gz' >&2
    exit 2
fi

root=$(git rev-parse --show-toplevel)
sha=$(sed -n 's/^[[:space:]]*sha256: //p' "$root/.punt-labs/ethos/checks/snapshots/pharo.yaml")
actual=$(sha256sum < "$1")
if [[ ! $sha =~ ^[a-f0-9]{64}$ || ${actual%% *} != "$sha" ]]; then
    echo 'FAIL: runtime archive does not match the Pharo profile SHA-256' >&2
    exit 2
fi

work=$(mktemp -d /tmp/pharo-handoff.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
runtime=$work/runtime
mkdir -p "$runtime" "$root/.tmp"
tar -xzf "$1" -C "$runtime"

prehydrate="| repo |
repo := IceRepositoryCreator new
    location: (OSEnvironment current at: 'ETHOS_HANDOFF_ROOT') asFileReference;
    createRepository.
repo name: (OSEnvironment current at: 'ETHOS_HANDOFF_CHECKOUT_NAME'); register."

echo 'Manual Linux namespace simulation (live Git metadata, not the Ethos runner)'
TIMEFORMAT='elapsed %3R s'
result=0
for gate in gate-check gate-test-fast; do
    scratch=$work/$gate
    mkdir -p "$scratch/home" "$scratch/tmp" "$scratch/checkout-tmp"
    cp -a "$runtime/image" "$scratch/image"
    echo ">> $gate"
    status=0
    time \
        timeout --verbose --signal=TERM --kill-after=10s 10m \
        unshare --user --map-root-user --mount --net --pid --fork --kill-child --mount-proc \
        bash -eu -s -- "$root" "$runtime" "$scratch" "$gate" "$prehydrate" <<'SANDBOX' || status=$?
            root=$1 runtime=$2 scratch=$3 gate=$4 prehydrate=$5
            mount --bind "$root" "$root"
            mount -o remount,bind,ro "$root"
            mount --bind "$scratch/checkout-tmp" "$root/.tmp"
            mount --bind "$runtime" "$runtime"
            mount -o remount,bind,ro "$runtime"
            ip link set lo up
            cd "$root"
            isolated=(-i PATH=/usr/bin:/bin TZ=UTC LANG=C HOME="$scratch/home" TMPDIR="$scratch/tmp"
                ETHOS_HANDOFF_ROOT="$root" ETHOS_HANDOFF_RUNTIME="$runtime" ETHOS_HANDOFF_SCRATCH="$scratch"
                ETHOS_HANDOFF_CHECKOUT_NAME="${root##*/}")
            env "${isolated[@]}" "$runtime/vm/pharo" "$scratch/image/Pharo.image" eval --save "$prehydrate"
            exec env "${isolated[@]}" make "$gate" IMAGE_DIR="$scratch/image" VM="$runtime/vm/pharo" \
                PID_FILE="$scratch/pharo.pid" LOG_FILE="$scratch/pharo.log"
SANDBOX
    case $status in
        124|129|130|137|143) status=2 ;;
    esac
    printf '%s: exit %s\n' "$gate" "$status"
    if (( status != 0 )); then
        result=2
        if [[ -f $scratch/pharo.log ]]; then
            printf '>> %s Pharo log\n' "$gate" >&2
            cat -- "$scratch/pharo.log" >&2 || echo "FAIL: could not read $gate Pharo log" >&2
        fi
    fi
done
exit "$result"
