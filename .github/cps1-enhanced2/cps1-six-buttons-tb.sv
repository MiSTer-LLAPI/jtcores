module cps1_six_buttons_tb;
    reg clk=0, reset=1, selected=1, frame_tick=0, osd=0;
    reg [8:0] pad=0;
    reg [2:0] extra=0;
    wire [2:0] extra_fire;
    wire [6:0] game_pad;
    wire game_start,db15_menu;
    always #5 clk=~clk;
    jtframe_snac_turbo #(.BUTTONS(6)) dut(
        .clk(clk),.reset(reset),.selected(selected),.frame_tick(frame_tick),.osd(osd),
        .pad(pad),.extra(extra),.extra_fire(extra_fire),.game_pad(game_pad),
        .game_start(game_start),.db15_menu(db15_menu));
    task frame;
        begin
            @(negedge clk);frame_tick=1;
            @(negedge clk);
            frame_tick=0;
            repeat(7) @(negedge clk);
        end
    endtask
    task tap;
        begin
            pad[7]=1; repeat(3) frame;
            if(game_start) $fatal(1,"Start leaked during turbo gesture");
            pad[7]=0; repeat(3) frame;
        end
    endtask
    integer n,action,high_count;
    initial begin
        repeat(4) @(negedge clk); reset=0;
        for(action=0;action<3;action=action+1) begin
            extra[action]=1; repeat(4) frame;
            if(!extra_fire[action]) $fatal(1,"action %0d should be manual initially",action+4);
            repeat(3) tap;
            high_count=0;
            for(n=0;n<12;n=n+1) begin frame;high_count=high_count+extra_fire[action];end
            if(high_count<=0 || high_count>=12) $fatal(1,"action %0d did not pulse: %0d",action+4,high_count);
            repeat(3) tap;
            for(n=0;n<12;n=n+1) begin frame;if(!extra_fire[action]) $fatal(1,"action %0d did not return to manual",action+4);end
            extra=0;frame;if(extra_fire[action]) $fatal(1,"released action %0d remains active",action+4);
        end
        $display("PASS: CPS1 SNAC actions four through six toggle turbo and return to manual");
        $finish;
    end
endmodule
