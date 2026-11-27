#!/usr/bin/env bash
set -euo pipefail
support=$(cd "$(dirname "$0")" && pwd)
source_root=$(cd "$1" && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
python3 "$support/check.py" mras
python3 "$support/creditos_pausa.py" "$source_root"
bash "$support/run-tmnt-serial.sh" "$source_root"

iverilog -g2012 -DJTFRAME_ENHANCED_CONTROLS -DJTFRAME_LLAPI_HOLD_AUTOFIRE -DJTFRAME_TMNT_AUTOFIRE -s tmnt_extra_players_tb -o "$temp/extra" "$support/tmnt-extra-players-tb.sv" "$source_root/modules/jtframe/target/mister/hdl/jtframe_serial_arcade.sv"
vvp -N "$temp/extra"
