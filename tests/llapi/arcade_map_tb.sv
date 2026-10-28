`timescale 1ns/1ps
module arcade_map_tb;
reg [31:0] buttons1=0,buttons2=0;
reg valid1=0,valid2=0,osd_active=0;
reg [15:0] usb1=16'h1234,usb2=16'h5678;
wire [15:0] joy1,joy2;
wire [3:0] start,coin;
wire osd_request;
jtframe_llapi_arcade_map #(.BUTTONS(3)) dut(.*);
task check(input [15:0] j1,j2,input [3:0] st,co,input osd);
begin
#1;
if(joy1!==j1 || joy2!==j2 || start!==st || coin!==co || osd_request!==osd)
 $fatal(1,"got joy=%h/%h start=%h coin=%h osd=%b expected %h/%h %h %h %b",joy1,joy2,start,coin,osd_request,j1,j2,st,co,osd);
end endtask
initial begin
check(16'h1234,16'h5678,0,0,0);
buttons1=32'h01000001; valid1=1;
check(16'h0011,16'h1234,0,0,0);
buttons2=32'h02000002; valid2=1;
check(16'h0011,16'h0022,0,0,0);
valid1=0; check(16'h1234,16'h0022,0,0,0);
valid1=1; buttons1=32'h10; buttons2=32'h10;
check(0,0,0,3,0);
buttons1=32'h20; buttons2=32'h40;
check(0,0,3,0,0);
buttons1=0; buttons2=32'h20;
check(0,0,1,0,0); // Existing arcade convention: Start P1 from either port.
buttons2=0; buttons1=32'h04000021;
check(0,0,0,0,1);
buttons1=0; buttons2=32'h04000021;
check(0,0,0,0,1);
buttons1=32'h07000017; buttons2=32'h02000002; osd_active=1;
check(0,0,0,0,0);
osd_active=0; buttons1=32'hff; buttons2=0;
check(16'h70,0,3,1,0); // Coin/Start stay out of JTFRAME's game-button fields.
valid1=0; valid2=0;
check(16'h1234,16'h5678,0,0,0);
$display("PASS: independent players, both USB fallback allocations, three buttons, coin slots, arcade Start convention, OSD on either port and disconnected input rejection");
$finish;
end
endmodule
