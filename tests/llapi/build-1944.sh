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
# Decode no game ROMs and use the official Euro MRA supplied with this pilot.
# Strict JTFRAME timing acceptance stays enabled for all attempts.
success=0
for seed in 1 2 3; do
    if jtcore 1944 -mister --nodbg --nolinter --clean --seed "$seed" > "pilot-reports/seed-$seed.log" 2>&1; then
        success=1
        printf '%s\n' "$seed" > pilot-reports/accepted-seed.txt
        break
    fi
    cp -f log/mister/jt1944* pilot-reports/ 2>/dev/null || true
    if ! grep -q '^FAIL$' "pilot-reports/seed-$seed.log"; then
        tail -100 "pilot-reports/seed-$seed.log"
        exit 1
    fi
done
if test "$success" != 1; then
    echo 'No seed passed compilation and strict timing acceptance.'
    exit 1
fi
python3 tests/llapi/check-1944-timing.py
mkdir -p pilot-build/cores pilot-build/mra pilot-build/reports
cp release/mister/jt1944.rbf pilot-build/cores/jt1944_llapi_snac_20261029_autofire.rbf
cp tests/llapi/1944-LLAPI-Test.mra pilot-build/mra/
cp tests/llapi/1944-README.md pilot-build/LE-ME.md
cp pilot-reports/* pilot-build/reports/
cp cores/1944/mister/output_files/*.summary pilot-build/reports/ 2>/dev/null || true
cp cores/1944/mister/output_files/*.sta.rpt pilot-build/reports/ 2>/dev/null || true
printf 'Source: %s\nUpstream: b222692d4c0c9a26a6cb3c99c6820b1ed4a5d565\nArcade LLAPI: 4d63703988cfb2b8256fc3bdb1a4a09b39cceaba\n' "$(git rev-parse HEAD)" > pilot-build/SOURCE.txt
(cd pilot-build && sha256sum cores/*.rbf mra/*.mra > SHA256SUMS)
