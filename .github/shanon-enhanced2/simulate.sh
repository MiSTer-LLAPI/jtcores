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
    "$temp/jtframe" cfgstr shanon -t mister --nodbg
    "$temp/jtframe" cfgstr shanon -t mister --nodbg -o quartus > effective.qsf
)
python3 "$support/check.py" menu "$controls/cfgstr.hex"
python3 "$support/verificar-autofire.py" "$controls/cfgstr.hex" "$controls/effective.qsf" \
    "$hdl/jtframe_mister.sv" --manual-only --static-only
check_flags=()
for macro in SHANON JTFRAME_ENHANCED_CONTROLS JTFRAME_ENHANCED_FIXED_OPTIONS JTFRAME_SNAC_TURBO_MASK=7 JTFRAME_BUTTONS=4; do
    grep -Eq "VERILOG_MACRO [\"']?${macro}(=1)?[\"']?$" "$controls/effective.qsf"
done
while IFS= read -r macro; do
    check_flags+=("-D$macro")
done < <(sed -n 's/^set_global_assignment -name VERILOG_MACRO "\(.*\)"$/\1/p' "$controls/effective.qsf")
iverilog -g2012 -i "${check_flags[@]}" -s shanon_controls_tb -o "$temp/driving" \
    "$support/shanon_controls_tb.sv" "$hdl/jtframe_serial_arcade.sv" "$hdl/jtframe_snac_turbo.sv" \
    "$hdl/jtframe_llapi_arcade.sv" "$hdl/jtframe_llapi_protocol.sv" "$hdl/joydb15.v" \
    "$core/cores/outrun/hdl/jtoutrun_main.v"
vvp -N "$temp/driving"
sh "$temp/testes/verificar.sh"
