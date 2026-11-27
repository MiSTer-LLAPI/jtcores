`timescale 1ns/1ps
module cps15_llapi_six_buttons_tb;
  reg [31:0] b1=0,b2=0;
  reg valid1=1,valid2=1,osd=0,sat1=0,sat2=0;
  reg [15:0] usb1=0,usb2=0;
  wire [15:0] joy1,joy2;
  wire [3:0] start,coin;
  wire osd_request;
  jtframe_llapi_arcade_map #(.BUTTONS(6)) dut(
    .buttons1(b1),.buttons2(b2),.valid1(valid1),.valid2(valid2),
    .osd_active(osd),.saturn1(sat1),.saturn2(sat2),.usb1(usb1),.usb2(usb2),
    .joy1(joy1),.joy2(joy2),.start(start),.coin(coin),.osd_request(osd_request));
  initial begin
    #1;
    b1[3:0]=4'hf; b1[6]=1; b1[7]=1;
    b2[3:0]=4'hf; b2[6]=1; b2[7]=1;
    #1;
    if(joy1[9:4] !== 6'h3f || joy2[9:4] !== 6'h3f)
      $fatal(1,"six actions missing on non-Saturn LLAPI");
    b1=0; b2=0; sat1=1; sat2=1;
    b1[3:0]=4'hf; b1[8]=1; b1[9]=1;
    b2[3:0]=4'hf; b2[8]=1; b2[9]=1;
    #1;
    if(joy1[9:4] !== 6'h3f || joy2[9:4] !== 6'h3f)
      $fatal(1,"six actions missing on Saturn LLAPI");
    osd=1;
    #1;
    if(joy1 !== 0 || joy2 !== 0) $fatal(1,"OSD did not inhibit actions");
    $display("PASS: LLAPI six actions P1/P2, Saturn and OSD");
    $finish;
  end
endmodule
