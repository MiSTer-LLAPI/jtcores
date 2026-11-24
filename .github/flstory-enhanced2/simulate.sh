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
    "$hdl/jtframe_serial_arcade.sv" "$hdl/sys/hps_io.sv" "$temp/fontes"
python3 "$support/check.py" mras
iverilog -g2012 -DJTFRAME_LLAPI_SIX_ACTIONS -s six_actions_tb -o "$temp/six" "$support/six_actions_tb.sv" "$hdl/jtframe_llapi_arcade.sv"
vvp "$temp/six"
iverilog -g2012 -DJTFRAME_LLAPI_SIX_ACTIONS -s snac_readers_tb -o "$temp/six-snac" "$support/six_actions_snac_tb.sv" "$hdl/jtframe_serial_arcade.sv"
vvp "$temp/six-snac"
sh "$temp/testes/verificar.sh" 
