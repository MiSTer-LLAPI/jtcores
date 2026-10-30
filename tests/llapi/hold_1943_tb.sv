`timescale 1ns/1ps
module hold_1943_tb #(parameter BUTTONS=3);
reg clk=0,rst=1,frame=0,osd=0;always #5 clk=~clk;
wire [15:0] j1,j2;wire [6:0] uo;wire [3:0] st,co;wire db,menu;
jtframe_serial_arcade #(.BUTTONS(BUTTONS)) dut(.clk_50(clk),.clk_sys(clk),.rst(rst),.vblank(frame),.osd_active(osd),.mode(3'd0),.user_in(7'h7f),.user_out(uo),.usb1(16'd0),.usb2(16'd0),.joy1(j1),.joy2(j2),.start(st),.coin(co),.db15_drive(db),.osd_request(menu));
task settle;begin repeat(12)@(negedge clk);end endtask
task nextframe;begin frame=1;settle();frame=0;settle();end endtask
initial begin
 settle();rst=0;repeat(8000)@(negedge clk);
 force dut.u_llapi.valid1_sync=1;force dut.u_llapi.valid2_sync=1;
 force dut.u_llapi.buttons1_sync=32'h00000008;force dut.u_llapi.buttons2_sync=0;
 settle();if(!j1[4]||j1[6]||j1[5]||j2)$fatal(1,"X must autofire P1 without loop/bomb/P2");
 nextframe();nextframe();nextframe();if(j1[4]||j1[6])$fatal(1,"X off phase");
 force dut.u_llapi.buttons1_sync=32'h00000009;settle();if(!j1[4]||j1[6])$fatal(1,"manual shot overrides off phase without loop");
 force dut.u_llapi.buttons1_sync=0;force dut.u_llapi.buttons2_sync=8;
 settle();if(j1||!j2[4]||j2[6]||j2[5])$fatal(1,"P2 independent autofire without loop/bomb");
 osd=1;settle();if(j1||j2)$fatal(1,"OSD suppresses autofire");
 osd=0;force dut.u_llapi.buttons2_sync=0;settle();if(j1||j2)$fatal(1,"release stops");
 force dut.u_llapi.buttons1_sync=2;settle();if(!j1[5]||j1[4]||j1[6])$fatal(1,"bomb retained");
 force dut.u_llapi.buttons1_sync=4;settle();
 if(BUTTONS==3) begin
  if(!j1[6]||j1[4]||dut.llapi_af[0])$fatal(1,"original third button/loop preserved without autofire");
 end else begin
  if(j1[6]||!j1[4])$fatal(1,"1944 tested bit2 autofire alias preserved");
 end
 $display("PASS free bit3 autofire; old bit2 loop or legacy1944 alias preserved, manual controls, OSD and independent ports");$finish;
end
endmodule
