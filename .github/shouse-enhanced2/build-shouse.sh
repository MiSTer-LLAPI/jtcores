#!/usr/bin/env bash
set -euo pipefail
# Run inside Jotego's public jtcore20 build container, with this repo at /jtcores.
cd /jtcores
# The container runs as root; trust only this mounted source checkout.
git config --global --add safe.directory /jtcores
export JTROOT=/jtcores
export JTFRAME=$JTROOT/modules/jtframe
export MODULES=$JTROOT/modules
export CORES=$JTROOT/cores
export JTBIN=$JTROOT/release
export RLS=$JTBIN
export MRA=$JTBIN/mra
export ROM=$JTROOT/rom
export POCKET=$JTFRAME/target/pocket
export JTUTIL=/tmp/llapi-support
export PATH=/tmp/llapi-tools:$JTFRAME/bin:/usr/local/go/bin:$PATH
mkdir -p /tmp/llapi-tools "$JTUTIL" "$JTBIN" pilot-reports
# Set only build variables; do not source scripts that override CODEX_HOME.
(cd "$JTFRAME/src/jtframe" && go build -o /tmp/llapi-tools/jtframe .)
# Decode no game ROMs and use the official Namco System 1 MRAs supplied with this pilot.
# Strict JTFRAME timing acceptance stays enabled for all attempts.
for seed in 1 2 3; do
    log="pilot-reports/seed-$seed.log"
    if jtcore shouse -mister --nodbg --nolinter --clean --seed "$seed" > "$log" 2>&1; then
        if python3 tests/llapi/check-shouse-timing.py; then
            printf '%s\n' "$seed" > pilot-reports/accepted-seed.txt
            exit 0
        fi
    elif ! grep -q '^FAIL$' "$log"; then
        tail -100 "$log"
        exit 1
    fi
    # Preserve enough information to trace failures between seeds.
    evidence="pilot-reports/seed-$seed"
    mkdir -p "$evidence"
    find cores/shouse/mister -type f \( -name 'jtshouse.sta.*' -o -name 'jtshouse.fit.summary' \) -exec cp {} "$evidence/" \;
    if test -f pilot-reports/timing-acceptance.json; then
        mv pilot-reports/timing-acceptance.json "$evidence/"
    fi
done
echo 'No seed passed compilation and timing acceptance.'
exit 1
