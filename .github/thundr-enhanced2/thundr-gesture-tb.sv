module tb;
reg clk=0, reset=1;
always #5 clk=~clk;
reg [8:0] pad=0;
reg [5:0] mask=1;
wire [6:0] game;
wire start;
jtframe_snac_turbo dut(.clk(clk),.reset(reset),.selected(1'b1),.frame_tick(1'b1),.osd(1'b0),
 .action_mask(mask),.pad(pad),.extra(3'b0),.game_pad(game),.game_start(start));
task taps(input [8:0] action);
begin
 pad=action;
 repeat(4) @(negedge clk);
 repeat(3) begin
   pad=action|9'h080;
   repeat(4) @(negedge clk);
   pad=action;
   repeat(4) @(negedge clk);
 end
end
endtask
initial begin
 repeat(2) @(negedge clk);
 reset=0;
 taps(9'h020);
 if(dut.programmed!==0 || game[5]!==1) $fatal(1,"masked action did not pass through normally");
 mask=3;
 taps(9'h020);
 if(dut.programmed!==2) $fatal(1,"B gesture did not program");
 pad=0;
 @(negedge clk);
 if(game[5]!==0) $fatal(1,"release did not stop fire");
 taps(9'h020);
 if(dut.programmed!==0) $fatal(1,"second gesture did not disable autofire");
 $display("PASS mask, passthrough, enable, release and disable");
 $finish;
end
endmodule
