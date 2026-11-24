#!/usr/bin/env bash
set -euo pipefail
support="$(cd "$(dirname "$0")" && pwd)"
python3 "$support/check.py" mras
cd "$1"
sh "$support/tests/run.sh"
