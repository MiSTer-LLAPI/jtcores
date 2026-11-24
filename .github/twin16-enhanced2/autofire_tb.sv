// Standard 2/3-button mapping. Input reports are injected after synchronization.
module autofire_tb;
    reg clk=0, reset=1, frame=0, osd=0;
    reg [1:0] enable=0, rate=0;
    reg [31:0] buttons1=0, buttons2=0;
    wire [15:0] joy1, joy2;
    always #5 clk=~clk;

    jtframe_serial_arcade #(.BUTTONS(`JTFRAME_BUTTONS)) dut(
        .clk_50(clk), .clk_sys(clk), .info_clk(clk), .rst(reset),
        .vblank(frame), .osd_active(osd), .repoll_off(1'b0), .mode(3'd0),
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
        buttons1=8; settle; expect_players(0,0);
        buttons1=1; settle; expect_players('h10,0);
        buttons1=2; settle; expect_players('h20,0);
        buttons1=0;
        for (speed=0; speed<3; speed=speed+1) begin
            rate=speed; enable=1; settle;
            buttons1=8; buttons2=8; settle; expect_players('h20,0);
            half_period=(speed==0) ? 3 : ((speed==1) ? 6 : 2);
            repeat(half_period-1) begin next_frame; expect_players('h20,0); end
            next_frame; expect_players(0,0);
            repeat(half_period-1) begin next_frame; expect_players(0,0); end
            next_frame; expect_players('h20,0);
            buttons1=0; buttons2=0; settle; expect_players(0,0);
        end
        enable=2; settle;
        buttons1=8; buttons2=8; settle; expect_players(0,'h20);
        osd=1; settle; expect_players(0,0);
        buttons1=0; buttons2=0; osd=0; enable=3; settle;
        buttons1=4; settle;
        if (`JTFRAME_BUTTONS == 3) expect_players('h40,0);
        else expect_players('h10,0);
        $display("PASS LLAPI P1/P2, manual buttons, Off/Hold, three rates, OSD and release");
        $finish;
    end
endmodule
