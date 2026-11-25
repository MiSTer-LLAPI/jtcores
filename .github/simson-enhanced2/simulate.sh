#!/usr/bin/env bash
set -euo pipefail
support=$(cd "$(dirname "$0")" && pwd)
source_root=$(cd "$1" && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
python3 "$support/check.py" mras
python3 "$support/creditos_pausa.py" "$source_root"
iverilog -g2012 -i -s esckids_cabinet_tb -o "$temp/cabinet" \
    "$support/esckids_cabinet_tb.sv" "$source_root/cores/simson/hdl/jtsimson_main.v"
vvp -N "$temp/cabinet"
bash "$support/run-esckids-serial.sh" "$source_root"
