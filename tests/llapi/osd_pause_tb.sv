`timescale 1ns/1ps
module osd_pause_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,key_pause=0,osd=0;wire manual_pause,dip_pause;
 jtframe_pause p(.clk(clk),.rst(rst),.key_pause(key_pause),.joy_pause(1'b0),
 .osd_pause(1'b0),.adv_frame(1'b0),.lvbl(1'b0),.game_pause(manual_pause));
 jtframe_dip d(.clk(clk),.status(64'd0),.game_pause(manual_pause),.vertical(1'b1),
 .dipflip_xor(1'b0),.hdmi_arx(),.hdmi_ary(),.rotate(),.rot_osdonly(),.rot_control(),
 .osd_pause(),.osd_shown(osd),.game_test(1'b1),.dip_test(),.dip_pause(dip_pause),.dip_flip(),.dip_fxlevel());
 task settle;begin repeat(8) @(negedge clk);end endtask
 task check(input run);begin settle();if(dip_pause!==run) $fatal(1,"pause state expected run=%b actual=%b",run,dip_pause);end endtask
 task toggle_manual;begin key_pause=1;settle();key_pause=0;settle();end endtask
 initial begin
  settle();rst=0;check(1);
  osd=1;check(0);osd=0;check(1);
  repeat(3) begin osd=1;check(0);osd=0;check(1);end
  toggle_manual();check(0);osd=1;check(0);osd=0;check(0);
  toggle_manual();check(1);
  osd=1;check(0);toggle_manual();check(0);osd=0;check(0);
  toggle_manual();check(1);
  $display("PASS OSD open/close, repeated entry, independent manual pause preserved");$finish;
 end
endmodule
