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
# Decode no game ROMs and use the official RoboCop MRAs supplied with this pilot.
# Strict JTFRAME timing acceptance stays enabled for all attempts.
success=0
for seed in 1 2 3; do
    if jtcore cop -mister --nodbg --nolinter --clean --seed "$seed" > "pilot-reports/seed-$seed.log" 2>&1; then
        success=1
        printf '%s\n' "$seed" > pilot-reports/accepted-seed.txt
        break
    fi
    cp -f log/mister/jtcop* pilot-reports/ 2>/dev/null || true
    if ! grep -q '^FAIL$' "pilot-reports/seed-$seed.log"; then
        tail -100 "pilot-reports/seed-$seed.log"
        exit 1
    fi
done
if test "$success" != 1; then
    echo 'No seed passed compilation and strict timing acceptance.'
    exit 1
fi
python3 tests/llapi/check-cop-timing.py
