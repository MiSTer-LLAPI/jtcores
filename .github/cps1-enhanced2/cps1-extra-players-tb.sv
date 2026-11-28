module tmnt_extra_players_tb;
    reg clk=0, rst=1, frame=0, osd=0, second=0, enable=1;
    reg [15:0] pad3=0, pad4=0;
    wire [15:0] joy3, joy4;
    always #5 clk=~clk;
    cps1_usb_autofire p3(clk,rst,frame,osd,second,enable,2'd1,pad3,joy3);
    cps1_usb_autofire p4(clk,rst,frame,osd,second,enable,2'd2,pad4,joy4);
    task tick;
        begin frame=1; @(negedge clk); frame=0; @(negedge clk); end
    endtask
    integer action,i;
    initial begin
        repeat(3) @(negedge clk);
        rst=0;
        for(action=4;action<=5;action=action+1) begin
            second=(action==5);
            pad3=16'h0081; pad4=16'h0042;
            repeat(3) @(negedge clk);
            pad3[action]=1; pad4[action]=1;
            for(i=1;i<=24;i=i+1) begin
                tick;
                if(joy3[action] !== ((i/6)%2==0) || joy4[action] !== ((i/2)%2==0))
                    $fatal(1,"P3/P4 speed mismatch at frame %d",i);
                if((joy3 & ~(16'h1<<action)) !== 16'h0081 || (joy4 & ~(16'h1<<action)) !== 16'h0042)
                    $fatal(1,"Unrelated control changed");
            end
            pad3[action]=0; tick;
            if(joy3[action] || !joy4[action]) $fatal(1,"P3 release affected P4");
            osd=1; tick;
            if(joy4[action]) $fatal(1,"OSD failed to inhibit autofire");
            osd=0; pad4[action]=0; tick;
        end
        enable=0; pad3=16'h55aa; pad4=16'haa55; tick;
        if(joy3!==pad3 || joy4!==pad4) $fatal(1,"Disabled passthrough mismatch");
        $display("PASS: independent P3/P4 Hold, speed, release, OSD and passthrough");
        $finish;
    end
endmodule
