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
    "$hdl/jtframe_serial_arcade.sv" "$hdl/jtframe_snac_turbo.sv" "$hdl/sys/hps_io.sv" "$temp/fontes"
python3 "$support/check.py" mras
export JTROOT="$core" JTFRAME="$base" CORES="$core/cores" MODULES="$core/modules"
export JTBIN="$temp" RLS="$temp" MRA="$temp/mra" ROM="$core/rom" POCKET="$base/target/pocket" JTUTIL="$temp"
(cd "$JTFRAME/src/jtframe" && go build -o "$temp/jtframe" .)
controls="$core/pilot-reports/controls"
mkdir -p "$controls"
(
    cd "$controls"
    "$temp/jtframe" cfgstr aliens -t mister --nodbg
    "$temp/jtframe" cfgstr aliens -t mister --nodbg -o quartus > effective.qsf
)
python3 "$support/check.py" menu "$controls/cfgstr.hex"
python3 "$support/verificar-autofire.py" "$controls/cfgstr.hex" "$controls/effective.qsf" \
    "$hdl/jtframe_mister.sv" --manual-only --static-only
project="$core/cores/aliens/mister"
mkdir -p "$project"
(
    cd "$project"
    "$temp/jtframe" mem aliens --target=mister --nodbg
    "$temp/jtframe" files syn aliens --target=mister
)
python3 "$support/check.py" project "$project/files.qip"
check_flags=()
for macro in JTFRAME_JOY_DURL JTFRAME_ENHANCED_CONTROLS JTFRAME_ENHANCED_FIXED_OPTIONS JTFRAME_BUTTONS=3; do
    grep -Eq "VERILOG_MACRO [\"']?${macro}(=1)?[\"']?$" "$controls/effective.qsf"
done
while IFS= read -r macro; do
    check_flags+=("-D$macro")
done < <(sed -n 's/^set_global_assignment -name VERILOG_MACRO "\(.*\)"$/\1/p' "$controls/effective.qsf")
iverilog -g2012 -i "${check_flags[@]}" -I "$core/cores/aliens/hdl" -I "$base/hdl/inc" -I "$project" -s aliens_controls_tb -o "$temp/cabinet" \
    "$support/aliens_controls_tb.sv" "$hdl/jtframe_serial_arcade.sv" "$hdl/jtframe_snac_turbo.sv" \
    "$hdl/jtframe_llapi_arcade.sv" "$hdl/jtframe_llapi_protocol.sv" "$hdl/joydb15.v" \
    "$base/hdl/keyboard/jtframe_joysticks.v" "$core/cores/aliens/hdl/jtaliens_main.v" "$core/cores/aliens/hdl/jtaliens_game.v"
vvp -N "$temp/cabinet"
sh "$temp/testes/verificar.sh"
