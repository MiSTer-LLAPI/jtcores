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
    "$temp/jtframe" cfgstr outrun -t mister --nodbg
    "$temp/jtframe" cfgstr outrun -t mister --nodbg -o quartus > effective.qsf
)
python3 "$support/check.py" menu "$controls/cfgstr.hex"
python3 "$support/verificar-autofire.py" "$controls/cfgstr.hex" "$controls/effective.qsf" \
    "$hdl/jtframe_mister.sv" --manual-only --static-only
iverilog -g2012 -i -DJTFRAME_LLAPI_EXTRA_ACTIONS -s outrun_controls_tb -o "$temp/driving" \
    "$support/outrun_controls_tb.sv" "$hdl/jtframe_llapi_arcade.sv" "$core/cores/outrun/hdl/jtoutrun_main.v"
vvp -N "$temp/driving"
iverilog -g2012 -DJTFRAME_LLAPI_EXTRA_ACTIONS -s snac_readers_tb -o "$temp/six-snac" "$support/six_actions_snac_tb.sv" "$hdl/jtframe_serial_arcade.sv"
vvp -N "$temp/six-snac"
iverilog -g2012 -DJTFRAME_LLAPI_EXTRA_ACTIONS -DJTFRAME_ENHANCED_CONTROLS -DJTFRAME_ENHANCED_FIXED_OPTIONS -s six_turbo_tb -o "$temp/six_turbo" "$support/six_turbo_tb.sv" "$hdl/jtframe_serial_arcade.sv" "$hdl/jtframe_llapi_arcade.sv" "$hdl/jtframe_snac_turbo.sv" "$hdl/jtframe_llapi_protocol.sv" "$hdl/joydb15.v"
vvp -N "$temp/six_turbo"
sh "$temp/testes/verificar.sh"
