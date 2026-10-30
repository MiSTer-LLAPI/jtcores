`timescale 1ns/1ps
module hold_autofire_tb;
reg clk=0,rst=1,frame=0,a=0,b=0,manual=0,inhibit=0;
wire fa,fb;
always #5 clk=~clk;
hold_autofire p1(clk,rst,frame,a,manual,inhibit,fa);
hold_autofire p2(clk,rst,frame,b,1'b0,inhibit,fb);
task tick;begin @(negedge clk);end endtask
task nextframe;begin frame=1;repeat(4)tick();frame=0;repeat(4)tick();end endtask
initial begin
 repeat(3)tick();rst=0;tick();
 if(fa||fb)$fatal(1,"idle");
 a=1;tick();if(!fa||fb)$fatal(1,"immediate fire and independent P2");
 nextframe();nextframe();if(!fa)$fatal(1,"on duration");
 nextframe();if(fa)$fatal(1,"off phase");
 b=1;tick();if(!fb||fa)$fatal(1,"independent hold phase");
 manual=1;tick();if(!fa)$fatal(1,"manual shot priority");
 manual=0;a=0;tick();if(fa)$fatal(1,"release stops immediately");
 inhibit=1;tick();if(fa||fb)$fatal(1,"OSD inhibition");
 inhibit=0;tick();if(!fb)$fatal(1,"resume clean phase");
 rst=1;tick();if(fa||fb)$fatal(1,"reset releases inputs");
 $display("PASS hold/release, frame rate, independent players, manual shot, OSD and reset");$finish;
end
endmodule
