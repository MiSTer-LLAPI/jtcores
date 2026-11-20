#!/usr/bin/env bash
set -euo pipefail

# Use the macros that jtcore actually passed to Quartus for CPS1.5.
qsf=cores/cps15/mister/jtcps15.qsf
hdl=modules/jtframe/target/mister/hdl
bench_dir=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
flags=()
for name in JTFRAME_LLAPI_HOLD_AUTOFIRE JTFRAME_LLAPI_AUTOFIRE_OPTIONS JTFRAME_ENHANCED_CONTROLS JTFRAME_SNAC_PCE_NES; do
    grep -Eq "^[[:space:]]*set_global_assignment -name VERILOG_MACRO \"${name}(=|\")" "$qsf" || {
        echo "Missing compiled option $name" >&2
        exit 1
    }
    flags+=("-D$name")
done
grep -Eq 'VERILOG_MACRO "JTFRAME_BUTTONS=6"' "$qsf"
flags+=(-DJTFRAME_BUTTONS=6)
if grep -Eq 'VERILOG_MACRO "JTCPS_TURBO(=|")' "$qsf"; then
    echo "Compiled JTCPS_TURBO forces Turbo on even when the OSD selects Off" >&2
    exit 1
fi

for bench in "$bench_dir/snes_controls_tb.sv" tests/llapi/enhanced_controls_tb.sv; do
    top=$(basename "$bench" .sv)
    iverilog -g2012 "${flags[@]}" -s "$top" -o "$tmp/$top" "$bench" \
        "$hdl/jtframe_serial_arcade.sv" "$hdl/jtframe_llapi_arcade.sv" \
        "$hdl/jtframe_llapi_protocol.sv" "$hdl/joydb15.v"
    vvp "$tmp/$top"
done
iverilog -g2012 -DMISTER -Icores/cps15/hdl -s turbo_default_tb \
    -o "$tmp/turbo" tests/llapi/turbo_default_tb.sv
vvp "$tmp/turbo"
