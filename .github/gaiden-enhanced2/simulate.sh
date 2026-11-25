#!/usr/bin/env bash
set -euo pipefail
support=$(cd "$(dirname "$0")" && pwd)
hdl="$1/modules/jtframe/target/mister/hdl"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
python3 "$support/check.py" mras
iverilog -g2012 -DJTFRAME_GAIDEN_AUTOFIRE_PROFILE -DJTFRAME_ENHANCED_CONTROLS \
    -DJTFRAME_ENHANCED_FIXED_OPTIONS -s snac_turbo_tb -o "$temp/snac" \
    "$support/snac_turbo_tb.sv" "$hdl/jtframe_serial_arcade.sv" "$hdl/jtframe_llapi_arcade.sv" \
    "$hdl/jtframe_snac_turbo.sv" "$hdl/jtframe_llapi_protocol.sv" "$hdl/joydb15.v"
vvp -N "$temp/snac"
