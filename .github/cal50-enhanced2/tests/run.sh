#!/bin/sh
set -eu
tests=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
rtl=modules/jtframe/target/mister/hdl
out=$(mktemp -d)
trap 'rm -f "$out/bench"; rmdir "$out"' EXIT
simulate() {
    top=$1
    shift
    iverilog -g2012 -DJTFRAME_LLAPI_ROTARY_ACTIONS -DJTFRAME_ENHANCED_CONTROLS -s "$top" -o "$out/bench" "$@"
    vvp "$out/bench"
}
simulate llapi_controls_tb "$tests/llapi_controls_tb.sv" "$rtl/jtframe_llapi_arcade.sv"
simulate snac_readers_tb "$tests/snac_controls_tb.sv" "$rtl/jtframe_serial_arcade.sv"
simulate rotary_modifier_tb "$tests/rotary_modifier_tb.sv" "$rtl/jtframe_serial_arcade.sv"
simulate rotary_guide_tb "$tests/guide_tb.sv" "$rtl/sys/hps_io.sv"
