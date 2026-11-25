#!/usr/bin/env bash
set -euo pipefail
support=$(cd "$(dirname "$0")" && pwd)
source_root=$(cd "$1" && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT
python3 "$support/check.py" mras
python3 "$support/creditos_pausa.py" "$source_root"
bash "$support/run-tmnt-serial.sh" "$source_root"
