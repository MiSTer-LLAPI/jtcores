#!/usr/bin/env bash
set -euo pipefail
support=$(cd "$(dirname "$0")" && pwd)
root=${1:?Indica a pasta jtcores com a fonte oficial.}
source_file="$root/cores/pang/hdl/jtpang_main.v"
image=$(mktemp)
trap 'rm -f "$image"' EXIT
python3 "$support/check.py" mras
iverilog -g2012 -i -s pang_cabinet_tb -o "$image" "$support/pang_cabinet_tb.sv" "$source_file"
vvp -N "$image"
