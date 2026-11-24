#!/usr/bin/env bash
set -euo pipefail
support="$(cd "$(dirname "$0")" && pwd)"
core="$(cd "$1" && pwd)"
temp="$(mktemp -d)"
trap 'rm -rf -- "$temp"' EXIT
cp -R "$support/testes" "$temp/testes"
mkdir "$temp/fontes"
base="$core/modules/jtframe"
hdl="$base/target/mister/hdl"
cp "$base/hdl/jtframe_board.v" "$hdl/joydb15.v" "$hdl/jtframe_llapi_protocol.sv" "$hdl/jtframe_llapi_arcade.sv" \
    "$hdl/jtframe_serial_arcade.sv" "$hdl/jtframe_snac_turbo.sv" "$hdl/sys/hps_io.sv" "$temp/fontes"
python3 "$support/check.py" mras
export JTROOT="$core" JTFRAME="$base" CORES="$core/cores" MODULES="$core/modules"
export JTBIN="$temp" RLS="$temp" MRA="$temp/mra" ROM="$core/rom" POCKET="$base/target/pocket" JTUTIL="$temp"
(cd "$JTFRAME/src/jtframe" && go build -o "$temp/jtframe" .)
controls="$core/pilot-reports/controls"
mkdir -p "$controls"
(
    cd "$controls"
    "$temp/jtframe" cfgstr 1942 -t mister --nodbg
    "$temp/jtframe" cfgstr 1942 -t mister --nodbg -o quartus > effective.qsf
    "$temp/jtframe" mem 1942 -t mister --local --inc --nodbg
    "$temp/jtframe" files syn 1942 -t mister --local
    for file in jt1942_game.v jt1942_main.v jt1942_snac_profile.v jt49.v jt12_rst.v jtframe_serial_arcade.sv jtframe_snac_turbo.sv jtframe_llapi_arcade.sv jtframe_llapi_protocol.sv llapi_arcade.sdc; do
        grep -F "/$file" files.qip >/dev/null || { echo "1942 source missing: $file"; exit 1; }
    done
)
python3 "$support/check.py" menu "$controls/cfgstr.hex"

python3 "$support/verificar-autofire.py" "$controls/cfgstr.hex" "$controls/effective.qsf" \
    "$hdl/jtframe_mister.sv" --tb "$support/autofire_tb.sv"
for bench in snac_turbo_tb snac_wires_tb; do
    iverilog -g2012 -DJTFRAME_1942_INPUT_PROFILE -DJTFRAME_ENHANCED_CONTROLS -DJTFRAME_ENHANCED_FIXED_OPTIONS -s "$bench" -o "$temp/$bench" \
        "$support/$bench.sv" "$hdl/jtframe_serial_arcade.sv" "$hdl/jtframe_llapi_arcade.sv" \
        "$hdl/jtframe_snac_turbo.sv" "$hdl/jtframe_llapi_protocol.sv" "$hdl/joydb15.v"
    vvp -N "$temp/$bench"
done
PYTHONDONTWRITEBYTECODE=1 python3 "$support/simulate-cabinet.py" "$core" "$controls" "$temp"
sh "$temp/testes/verificar.sh"
