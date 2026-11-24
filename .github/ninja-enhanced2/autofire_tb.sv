// The P1 SNES and P2 Saturn reports exercise the two official MRA cabinet profiles.
module autofire_tb;
    reg clk=0, reset=1, frame=0, osd=0;
    reg rotary=0;
    reg [2:0] mode=0;
    wire manual_only;
    wire [3:0] starts,coins;
    reg [1:0] enable=0, rate=0;
    reg [31:0] buttons1=0, buttons2=0;
    wire [15:0] joy1, joy2;
    always #5 clk=~clk;

    jtframe_serial_arcade #(.BUTTONS(`JTFRAME_BUTTONS)) dut(
        .start(starts),.coin(coins),.rotary_profile(rotary),.manual_autofire_only(manual_only),.clk_50(clk), .clk_sys(clk), .info_clk(clk), .rst(reset),
        .vblank(frame), .osd_active(osd), .repoll_off(1'b0), .mode(mode),
        .user_in(7'h7f), .usb1(16'b0), .usb2(16'b0), .loss_resume(1'b0),
        .autofire_enable(enable[0]), .autofire_enable2(enable[1]),
        .autofire_toggle(1'b0), .autofire_toggle2(1'b0),
        .autofire_rate1(rate), .autofire_rate2(rate), .joy1(joy1), .joy2(joy2)
    );

    task settle; repeat(8) @(negedge clk); endtask
    task next_frame;
        begin frame=1; settle; frame=0; settle; end
    endtask
    task expect_players(input [15:0] expected1, input [15:0] expected2);
        if (joy1 !== expected1 || joy2 !== expected2)
            $fatal(1,"P1/P2 expected %h/%h observed %h/%h",expected1,expected2,joy1,joy2);
    endtask

    integer speed, half_period;
    initial begin
        force dut.u_llapi.valid1_sync=1;
        force dut.u_llapi.valid2_sync=1;
        force dut.u_llapi.buttons1_sync=buttons1;
        force dut.u_llapi.buttons2_sync=buttons2;
        force dut.llapi_type_changed=0;
        settle; reset=0; repeat(8000) @(negedge clk);
        force dut.u_llapi.snes_sync=2'b01;
        force dut.u_llapi.saturn2_sync=1'b1;
        buttons1=8; settle; expect_players(0,0);
        buttons1=2;buttons2=1;settle;expect_players('h10,'h10);
        buttons1=1;buttons2=2;settle;expect_players('h20,'h20);
        buttons1=64;buttons2=512;settle;expect_players(0,0);
        rotary=1;settle;expect_players('h40,'h80);
        buttons1=128;buttons2=256;settle;expect_players('h80,'h40);
        if ({starts,coins} !== 0) $fatal(1,"rotation changed start or coin");
        buttons1=32;buttons2=32;settle;expect_players(0,0);
        if (starts !== 4'b0011) $fatal(1,"independent P1/P2 start");
        buttons1=16;buttons2=64;settle;expect_players(0,0);
        if (coins !== 4'b0011) $fatal(1,"separate P1/P2 coin");
        buttons1=4;buttons2=1;settle;expect_players('h10,'h10);
        buttons1=1;buttons2=2;settle;expect_players('h20,'h20);
        buttons1=4+64;buttons2=2+512;settle;expect_players('h50,'ha0);
        buttons1=0;buttons2=0;settle;expect_players(0,0);
        buttons1=4; settle; expect_players('h10,0);
        buttons1=1; settle; expect_players('h20,0);
        buttons1=0;
        for (speed=0; speed<3; speed=speed+1) begin
            rate=speed; enable=1; settle;
            buttons1=8; buttons2=8; settle; expect_players('h10,0);
            half_period=(speed==0) ? 3 : ((speed==1) ? 6 : 2);
            repeat(half_period-1) begin next_frame; expect_players('h10,0); end
            next_frame; expect_players(0,0);
            repeat(half_period-1) begin next_frame; expect_players(0,0); end
            next_frame; expect_players('h10,0);
            buttons1=0; buttons2=0; settle; expect_players(0,0);
        end
        enable=2; settle;
        buttons1=8; buttons2=8; settle; expect_players(0,'h10);
        osd=1; settle; expect_players(0,0);
        buttons1=0; buttons2=0; osd=0; enable=3; settle;
        buttons1=128+8;buttons2=256+8;settle;expect_players('h90,'h50);
        buttons1=128;buttons2=256;settle;expect_players('h80,'h40);
        rotary=0;settle;expect_players(0,0);
        buttons1=8;buttons2=8;settle;expect_players('h10,'h10);
        buttons1=0;buttons2=0;settle;expect_players(0,0);
        mode=5;settle;if(manual_only!==1) $fatal(1,"PCE manual only");
        mode=6;settle;if(manual_only!==1) $fatal(1,"NES manual only");
        mode=2;rotary=1;force dut.md_three=1;settle;
        if(manual_only!==1) $fatal(1,"Heavy Barrel MD3 manual only");
        rotary=0;settle;if(manual_only!==0) $fatal(1,"Bad Dudes MD3 C Hold");
        rotary=1;force dut.md_three=0;settle;
        if(manual_only!==0) $fatal(1,"Heavy Barrel MD6 X Hold");
        mode=4;force dut.md_three=1;settle;if(manual_only!==0) $fatal(1,"SNES X Hold");
        release dut.md_three;
        $display("PASS Bad Dudes and Heavy Barrel, both players, rotation and three Hold rates");
        $finish;
    end
endmodule
