module rotary_modifier_tb;
reg clk=0;always #1 clk=!clk;
reg rst=0,en=1,inhibit=0,vb=0;
reg [8:0] pad=0;reg right=0;
wire [7:0] game;wire start;
jtframe_rotary_pad dut(clk,rst,en,inhibit,vb,pad,right,game,start);
task tick;begin @(negedge clk);end endtask
task check(input [7:0] want,input st); begin
    tick();if({game,start}!=={want,st})$fatal(1,"pad=%h got %h/%b expected %h/%b",pad,game,start,want,st);end
endtask
initial begin
 rst=1;tick();rst=0;tick();
 pad='h03b;check('h3b,0); // movement, fire, jump stay immediate
 pad='h080;check(0,0);pad='h0b1;check('hb0,0); // turn right without horizontal movement
 pad='h0b2;check('h70,0);pad='h080;check(0,0);pad=0;check(0,0);
 pad='h001;check(1,0);pad='h081;check('h80,0);pad='h001;check(1,0);
 pad='h080;check(0,0);pad=0;check(0,1);
 vb=1;check(0,1);vb=0;check(0,1);vb=1;check(0,0);vb=0;tick();
 pad='h184;check(4,0);pad='h080;check(0,0);pad=0;check(0,0);
 pad='h094;inhibit=1;check('h14,0);inhibit=0;pad='h080;check(0,0);pad=0;check(0,0);
 pad='h080;en=0;check(0,1);en=1;check(0,0);pad=0;check(0,0);
 right=1;en=0;pad='h0f3;check('hf3,1);
 $display("PASS compact Start tap/hold, both rotations, simultaneous fire/jump, both key orders, coin/OSD/mode suppression");$finish;
end
endmodule
