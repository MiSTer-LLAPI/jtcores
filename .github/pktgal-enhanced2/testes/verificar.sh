#!/bin/sh
set -eu
test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
src="$test_dir/../fontes"
ref="$test_dir/referencia"
tmp=$(mktemp -d)
trap 'rm -f "$tmp/menu" "$tmp/dual" "$tmp/seletor" "$tmp/poll"; rmdir "$tmp"' EXIT
python3 "$test_dir/creditos_pausa.py"
for policy in adaptive fixed; do
    flag=
    if [ "$policy" = fixed ]; then flag=-DJTFRAME_ENHANCED_FIXED_OPTIONS; fi
    iverilog -g2012 -s hps_menu_tb -DJTFRAME_UNIFIED_LLAPI -DJTFRAME_ENHANCED_CONTROLS $flag \
        -o "$tmp/menu" "$src/hps_io.sv" "$src/jtframe_llapi_protocol.sv" \
        "$src/jtframe_llapi_arcade.sv" "$test_dir/controller_guide_tb.sv"
    vvp "$tmp/menu"
done
for repoll_off in 0 1; do
    iverilog -g2012 -s verify_combo -DJTFRAME_ENHANCED_FIXED_OPTIONS -DJTFRAME_ENHANCED_CONTROLS -DJTFRAME_LLAPI_HOLD_AUTOFIRE \
        -Pverify_combo.FINAL_TAIL=160 "-Pverify_combo.REPOLL_OFF=$repoll_off" -o "$tmp/dual" "$src/jtframe_llapi_protocol.sv" \
        "$src/jtframe_llapi_arcade.sv" "$ref/llapi_05.sv" "$test_dir/dois_comandos_tb.sv"
    vvp "$tmp/dual"
    iverilog -g2012 -s verify_gp_mux -DJTFRAME_ENHANCED_FIXED_OPTIONS -DJTFRAME_ENHANCED_CONTROLS -DJTFRAME_LLAPI_HOLD_AUTOFIRE \
        -DJTFRAME_SNAC_PCE_NES "-Pverify_gp_mux.REPOLL_OFF=$repoll_off" -o "$tmp/seletor" \
        "$src/jtframe_llapi_protocol.sv" "$src/jtframe_llapi_arcade.sv" "$src/jtframe_serial_arcade.sv" \
        "$src/joydb15.v" "$ref/stock_arcade.sv" "$ref/stock_serial.sv" "$ref/gpa_fixture.sv" \
        "$test_dir/seletor_snac_tb.sv"
    vvp "$tmp/seletor"
done

for repoll_on in 0 1; do
    iverilog -g2012 -s bench -Pbench.S=6 "-Pbench.REPOLL=$repoll_on" \
        -o "$tmp/poll" "$src/jtframe_llapi_protocol.sv" "$ref/llapi_05.sv" "$test_dir/poll_tb.sv"
    vvp "$tmp/poll"
done
