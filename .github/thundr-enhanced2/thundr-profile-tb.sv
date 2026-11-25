module tb;
reg romclk=0, sysclk=0, download=0, wr=0;
reg [26:0] addr=0;
reg [7:0] data=0;
wire [5:0] mask;
always #5 romclk=~romclk;
always #8 sysclk=~sysclk;
jtthundr_autofire_profile dut(romclk,sysclk,download,wr,addr,data,mask);
task load(input [7:0] b1,b2,input [5:0] expected);
begin
 @(negedge romclk); download=1; wr=1; addr=1; data=b1;
 @(negedge romclk); addr=2; data=b2;
 @(negedge romclk); download=0; wr=0;
 repeat (4) @(negedge sysclk);
 if(mask!==expected) $fatal(1,"Wrong action mask after %h %h",b1,b2);
end
endtask
initial begin
 load(8'h04,8'h88,6'd1);
 load(8'h22,8'h02,6'd3);
 load(8'h0d,8'h00,6'd1);
 load(8'h05,8'h88,6'd1);
 load(8'h3c,8'h80,6'd3);
 load(8'h20,8'h01,6'd1);
 load(8'h22,8'h04,6'd3);
 $display("PASS seven MRA profiles in sequence"); $finish;
end
endmodule
