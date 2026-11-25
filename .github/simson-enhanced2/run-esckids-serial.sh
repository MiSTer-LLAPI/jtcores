#!/usr/bin/env bash
set -euo pipefail

support=$(cd "$(dirname "$0")" && pwd)
project=${1:?Pass the patched jtcores checkout}
base=$project/modules/jtframe
hdl=$base/target/mister/hdl
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

flags=(-DJTFRAME_ENHANCED_CONTROLS -DJTFRAME_ENHANCED_FIXED_OPTIONS
       -DJTFRAME_LLAPI_HOLD_AUTOFIRE -DJTFRAME_SIMSON_AUTOFIRE
       -DJTFRAME_SNAC_TURBO_MASK=3 -DJTFRAME_BUTTONS=3
       -DJTFRAME_JOY_DURL -DJTFRAME_JOY1_POS)
iverilog -g2012 -i "${flags[@]}" -s esckids_serial_tb -o "$test_dir/serial" \
    "$support/esckids_serial_tb.sv" "$hdl/jtframe_serial_arcade.sv" \
    "$hdl/jtframe_llapi_arcade.sv" "$hdl/jtframe_llapi_protocol.sv" \
    "$hdl/jtframe_snac_turbo.sv" "$hdl/joydb15.v" \
    "$base/hdl/keyboard/jtframe_joysticks.v" "$project/cores/simson/hdl/jtsimson_main.v"
vvp -N "$test_dir/serial"
