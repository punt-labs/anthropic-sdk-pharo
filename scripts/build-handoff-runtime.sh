#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
    printf 'Usage on Linux x86_64: %s OUTPUT_DIRECTORY\n' "$0" >&2
    exit 2
fi

repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
output=$(cd -- "$1" && pwd)
work=$(mktemp -d "$output/.pharo-runtime.XXXXXX")
trap 'rm -rf -- "$work"' EXIT

postern_commit=a262bd3543caa33678c85de4a2fcf03e3cb85af3
postern=$work/postern
git init -q "$postern"
git -C "$postern" fetch -q --depth=1 https://github.com/punt-labs/postern.git "$postern_commit"
git -C "$postern" checkout -q --detach "$postern_commit"

seed=$work/seed
"$postern/scripts/postern-bootstrap-pharo" "$seed" 120
"$repo/scripts/fetch-observe"

PHARO_HANDOFF_UPSTREAM="$repo/.tmp/upstream" PHARO_HANDOFF_POSTERN="$postern" \
    "$seed/pharo" "$seed/Pharo.image" eval --save "
    | up postern |
    up := OSEnvironment current at: 'PHARO_HANDOFF_UPSTREAM'.
    postern := OSEnvironment current at: 'PHARO_HANDOFF_POSTERN'.
    Metacello new baseline: 'SQLite3'; repository: 'gitlocal://', up, '/sqlite/src'; lock; load: 'Core'.
    Metacello new baseline: 'GRPC'; repository: 'gitlocal://', up, '/grpc/src'; lock; load.
    Metacello new baseline: 'PharoBackwardCompatibility'; repository: 'gitlocal://', up, '/compat/src'; lock; load.
    Metacello new baseline: 'OpenTelemetry'; repository: 'gitlocal://', up, '/otel/src'; lock; load: #('traces' 'metrics').
    Metacello new baseline: 'PuntObserve'; repository: 'tonel://', up, '/punt-observe/src'; lock; load.
    Metacello new baseline: 'Postern'; repository: 'tonel://', postern, '/src'; lock; load.
    (#(PosternServer PuntLog PuntTelemetry) allSatisfy: [ :name | Smalltalk globals includesKey: name ])
        ifFalse: [ Smalltalk exitFailure ].
    'Pharo handoff image ready'"

bundle=$work/bundle
mkdir -p "$bundle/image" "$bundle/vm"
mv "$seed/Pharo.image" "$seed/Pharo.changes" "$seed/"*.sources "$bundle/image/"
mv "$seed/pharo" "$seed/pharo-vm" "$bundle/vm/"
archive=pharo-handoff-linux-amd64.tar.gz
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
    -C "$bundle" -cf - image vm | gzip -n >"$work/$archive"
mv "$work/$archive" "$output/$archive"
(cd -- "$output" && sha256sum "$archive" >"$archive.sha256")
