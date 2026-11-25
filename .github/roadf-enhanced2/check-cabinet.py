"""Simulate the official Hyper Sports cabinet register logic."""
from pathlib import Path
import re
import subprocess
import sys
from tempfile import TemporaryDirectory

source = (Path(sys.argv[1]) / "cores/roadf/hdl/jtroadf_main.v").read_text()
inputs = re.search(r"function \[2:0\] rev3\(.*?endfunction", source, re.S)
register = re.search(r"case\( A\[1:0\] \)\s+0: cabinet.*?endcase", source, re.S)
assert inputs and register, "Official cabinet register changed"
bench = """
module cabinet_tb;
reg clk=0;
always #5 clk=~clk;
reg [1:0] A=1;
reg [7:0] cabinet;
reg [6:0] joystick1=127,joystick2=127,joystick3=127,joystick4=127;
reg [3:0] cab_1p=15;
reg [2:0] dipsw_c=7;
reg [7:0] dipsw_a=255;
reg service=1,is_hyper=1;
reg [1:0] coin=3;
reg [27:0] pads;
integer player, bit_index;
"""
bench += inputs[0] + "\nalways @(posedge clk) begin\n" + register[0] + "\nend\n"
bench += """
initial begin
    for (player=0; player<4; player=player+1) begin
        A=player/2+1;
        for (bit_index=4; bit_index<7; bit_index=bit_index+1) begin
            pads=28'hfffffff;
            pads[player*7+bit_index]=0;
            {joystick4,joystick3,joystick2,joystick1}=pads;
            @(negedge clk);
            case (bit_index)
                4: if (cabinet[(player%2)*4+2]!==0) $fatal(1,"right input P%0d",player+1);
                5: if (cabinet[(player%2)*4+1]!==0) $fatal(1,"centre input P%0d",player+1);
                6: if (cabinet[(player%2)*4]!==0) $fatal(1,"left input P%0d",player+1);
            endcase
        end
    end
    $display("PASS: Hyper Sports official cabinet registers, three actions on P1–P4");
    $finish;
end
endmodule
"""
with TemporaryDirectory() as path:
    path = Path(path)
    (path / "cabinet.sv").write_text(bench)
    subprocess.run(["iverilog", "-g2012", "-s", "cabinet_tb", "-o", path / "sim", path / "cabinet.sv"], check=True)
    subprocess.run(["vvp", "-N", path / "sim"], check=True)
