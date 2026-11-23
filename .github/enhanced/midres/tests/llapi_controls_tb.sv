
module llapi_controls_tb;
reg [31:0] a=0,b=0;
reg [1:0] snes=1,sat=0;
reg va=1,vb=1,osd=0;
wire [15:0] j1,j2; wire [3:0] st,co; wire osdreq;
jtframe_llapi_arcade_map #(.BUTTONS(5)) map(.buttons1(a),.buttons2(b),.valid1(va),.valid2(vb),.osd_active(osd),.snes(snes),.saturn1(sat[0]),.saturn2(sat[1]),.usb1(16'hc001),.usb2(16'hc002),.joy1(j1),.joy2(j2),.start(st),.coin(co),.osd_request(osdreq));
task check(input [15:0] p1,p2,input [3:0] start,coin,input menu);
begin #1;if ({j1,j2,st,co,osdreq} !== {p1,p2,start,coin,menu})$fatal(1,"got %x %x %b %b %b expected %x %x %b %b %b",j1,j2,st,co,osdreq,p1,p2,start,coin,menu); end endtask
initial begin
 // SNES on P1, modern generic on P2.
 a=1<<2;b=1;check(16,16,0,0,0);
 a=1;b=2;check(32,32,0,0,0);
 a=64;b=128;check(64,128,0,0,0);
 a=128;b=64;check(128,64,0,0,0);
 a=8;b=8;check(0,0,0,0,0);
 a=16;b=32;check(0,0,2,1,0);
 a=32;b=16;check(0,0,1,2,0);
 // Saturn on P2: independent shoulder pair, coin isolated.
 sat=2;a=0;b=256+512;check(0,192,0,0,0);
 b=64;check(0,0,0,2,0);
 b=0;a=(1<<26)+32+4;check(0,0,0,0,1);
 a=0;b=256;osd=1;check(0,0,0,0,0);
 osd=0;vb=0;check(0,16'hc001,0,0,0);
 va=0;check(16'hc001,16'hc002,0,0,0);
 $display("PASS mixed per-port LLAPI SNES, generic and Saturn, independent starts/coins, menu and USB");$finish;
end
endmodule
