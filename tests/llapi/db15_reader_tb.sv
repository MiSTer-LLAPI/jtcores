`timescale 1ns/1ps
module db15_reader_tb;
 reg clk=0,sys=0; always #10 clk=~clk; always #13 sys=~sys;
 reg [2:0] mode=0;
 wire [6:0] pins; wire [15:0] joy1,joy2; wire [3:0] start,coin;wire osd;
 reg [23:0] serial=24'hffffff;
 reg [23:0] word=24'hffffff;
 // Physical shift-register model: /LOAD captures both controllers;
 // the rising clock shifts the next serial bit onto DATA.
 always @(negedge pins[0]) serial<=word;
 always @(posedge pins[1]) if(mode==3) begin
   if(!pins[0]) serial<=word;
   else serial<={1'b1,serial[23:1]};
 end
 jtframe_serial_arcade dut(.clk_50(clk),.clk_sys(sys),.rst(1'b0),.vblank(1'b0),
  .osd_active(1'b0),.mode(mode),.user_in({1'b1,serial[0],5'b11111}),
  .user_out(pins),.usb1(16'd0),.usb2(16'd0),.joy1(joy1),.joy2(joy2),
  .start(start),.coin(coin),.osd_request(osd));
 task scan;begin repeat(15000) @(negedge clk);end endtask
 initial begin
  scan(); mode=3;scan();
  if(joy1 || joy2 || start || coin) $fatal(1,"DB15 idle");
  // Serial chain: P1 D C B A R L D U; P2 R L D U;
  // P1 F E Select Start; P2 F E Select Start D C B A.
  word=~((24'd1<<3)|(24'd1<<7)|(24'd1<<14)|(24'd1<<15)|
         (24'd1<<8)|(24'd1<<18)|(24'd1<<19)|(24'd1<<22));scan();
  if(joy1!==16'h18 || joy2!==16'h21 || start!==3 || coin!==3)
    $fatal(1,"DB15 P1/P2 mapping joy=%h/%h start=%h coin=%h",joy1,joy2,start,coin);
  word=~((24'd1<<1)|(24'd1<<15));scan();
  if(!osd || joy1 || joy2 || start || coin) $fatal(1,"original DB15 Start+C menu");
  word=24'hffffff;scan();
  if(joy1 || joy2 || start || coin || osd) $fatal(1,"DB15 released");
  $display("PASS: original DB15 serial shift register, both players, Start/coin and Start+C menu");$finish;
 end
endmodule
