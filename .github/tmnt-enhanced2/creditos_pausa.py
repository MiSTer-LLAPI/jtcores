from pathlib import Path
from tempfile import TemporaryDirectory
import sys
import itertools
import subprocess

jtframe = Path(sys.argv[1]).resolve() / 'modules/jtframe'
board = (jtframe / 'hdl/jtframe_board.v').read_text()
block=board[board.index('reg  show_credits;'):board.index('    jtframe_credits #(')]
enables=board[board.index('        `ifdef JTFRAME_CHEAT',board.index('    jtframe_credits #(')):board.index('        // output image',board.index('    jtframe_credits #('))]
spec='\n'.join(line if '`' in line else line.replace('.enable (','assign visible =').replace('.enable     (','assign visible =').replace('),',';') for line in enables.splitlines() if '`' in line or '.enable' in line)
fixture="""module check_credits;
  reg clk_sys=0, locked=0, dip_pause=1, osd_shown=0;
  reg [3:0] game_start=15, game_joystick1=15, game_joystick2=15;
  reg [127:0] status=0;
  reg vertical=0;
  reg [7:0] vram_ctrl=0;
  wire visible;
  always #5 clk_sys=~clk_sys;
"""+block+'\n`endif\n'+spec+"""
  localparam EFFECTIVE_FIXED =
`ifdef JTFRAME_ENHANCED_FIXED_OPTIONS
`ifdef JTFRAME_ENHANCED_CONTROLS
    1;
`else
    0;
`endif
`else
    0;
`endif
  integer state;
  reg expected,raw;
  initial begin
    for (state=0;state<32;state=state+1) begin
      {locked,dip_pause,osd_shown,status[12],vram_ctrl[0]}=state;
      @(negedge clk_sys);
      raw=locked || !dip_pause;
`ifdef JTFRAME_CREDITS_DEFAULT_OFF
      raw=raw && status[12];
`else
      raw=raw && !status[12];
`endif
`ifdef JTFRAME_CREDITS_AON
      raw=1;
`endif
      if(EFFECTIVE_FIXED) raw=locked || (!dip_pause && status[12]);
`ifdef JTFRAME_ENHANCED_CONTROLS
      if(osd_shown && !EFFECTIVE_FIXED) raw=0;
`endif
`ifdef JTFRAME_CHEAT
      expected=raw || vram_ctrl[0];
`elsif JTFRAME_CREDITS_AON
      expected=EFFECTIVE_FIXED ? raw : 1;
`else
      expected=raw;
`endif
      if(visible!==expected) $fatal(1,"visible=%b expected=%b state=%d",visible,expected,state);
    end
    $finish;
  end
endmodule
"""
with TemporaryDirectory() as generated:
    w=Path(generated)
    (w/'credit_tb.sv').write_text(fixture)
    for fixed,enhanced,default_off,aon,cheat in itertools.product([False,True],repeat=5):
     flags=[k for k,v in [('JTFRAME_ENHANCED_FIXED_OPTIONS',fixed),('JTFRAME_ENHANCED_CONTROLS',enhanced),('JTFRAME_CREDITS_DEFAULT_OFF',default_off),('JTFRAME_CREDITS_AON',aon),('JTFRAME_CHEAT',cheat)] if v]
     cmd=['iverilog','-g2012','-DMISTER','-DJTFRAME_CREDITS',*['-D'+f for f in flags],'-o',w/'credits.vvp',w/'credit_tb.sv']
     subprocess.run(cmd,check=True,capture_output=True)
     subprocess.run(['vvp',w/'credits.vvp'],check=True,capture_output=True)
    print('PASS: 1024 credits/OSD cases incl. existing configs, opt-out, default credits polarity, locked screen and independent cheat video.')

# Feed SPI frames from Main's Select operation into the compiled HPS receiver.
root = Path(__file__).resolve().parent
sources = jtframe / 'target/mister/hdl'
with TemporaryDirectory() as scratch:
    work = Path(scratch)
    harness = work / 'board-credits.sv'
    harness.write_text("""
module credits_from_board(input clk_sys, input [127:0] status, input dip_pause, osd_shown, output visible);
    wire locked=0, vertical=0;
    wire [3:0] game_start=15, game_joystick1=15, game_joystick2=15;
    wire [7:0] vram_ctrl=0;
""" + block + "\n`endif\n" + spec + "\nendmodule\n")
    binary = work / 'select'
    subprocess.run(['iverilog','-g2012','-s','credit_select_tb','-DMISTER','-DJTFRAME_CREDITS',
        '-DJTFRAME_ENHANCED_CONTROLS','-DJTFRAME_UNIFIED_LLAPI','-DJTFRAME_ENHANCED_FIXED_OPTIONS',
        '-o',binary,harness,root/'creditos_select_tb.sv',sources/'sys/hps_io.sv',
        sources/'jtframe_llapi_arcade.sv',sources/'jtframe_llapi_protocol.sv'], check=True)
    subprocess.run(['vvp', binary],cwd=root,check=True)
