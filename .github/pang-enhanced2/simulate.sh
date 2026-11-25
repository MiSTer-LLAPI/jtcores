#!/usr/bin/env bash
set -euo pipefail
support=$(cd "$(dirname "$0")" && pwd)
root=${1:?Indica a pasta jtcores com o patch aplicado.}
bash "$support/simulate-cabinet.sh" "$root"
python3 "$support/creditos_pausa.py" "$root"
hdl="$root/modules/jtframe/target/mister/hdl"
image=$(mktemp)
trap 'rm -f "$image"' EXIT
iverilog -g2012 -DJTFRAME_ENHANCED_CONTROLS -DJTFRAME_ENHANCED_FIXED_OPTIONS \
    -DJTFRAME_LLAPI_HOLD_AUTOFIRE -DJTFRAME_LLAPI_EXTRA_ACTIONS \
    -s snac_wires_tb -o "$image" "$support/snac_wires_tb.sv" \
    "$hdl/jtframe_serial_arcade.sv" "$hdl/jtframe_llapi_arcade.sv" \
    "$hdl/jtframe_snac_turbo.sv" "$hdl/jtframe_llapi_protocol.sv" "$hdl/joydb15.v"
vvp -N "$image"
