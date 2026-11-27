module riders_action_tb;
    reg clk=0, rst=1, vb=0, osd=0;
    reg second=0;
    reg [8:0] pad=0;
    wire [15:0] joy1,joy2;
    wire [3:0] start,coin;
    always #5 clk=~clk;
    jtframe_serial_arcade #(.BUTTONS(4)) dut(
        .clk_50(clk),.clk_sys(clk),.rst(rst),.vblank(vb),.osd_active(osd),
        .repoll_off(1'b0),.mode(3'd1),.usb1(16'd0),.usb2(16'd0),.user_in(7'h7f),
        .autofire_second_action(second),.autofire_enable(1'b1),.autofire_enable2(1'b0),
        .autofire_toggle(1'b0),.autofire_toggle2(1'b0),
        .autofire_rate1(2'd0),.autofire_rate2(2'd0),.loss_resume(1'b0),
        .info_clk(clk),.joy1(joy1),.joy2(joy2),.start(start),.coin(coin));
    task frame;
        begin vb=1; repeat(8) @(negedge clk); vb=0; repeat(8) @(negedge clk); end
    endtask
    integer i, count_first, count_second;
    initial begin
        force dut.port1=pad;
        repeat(8) @(negedge clk); rst=0;
        repeat(7600) @(negedge clk);
        // Saturn mode uses the spare third button to request Hold autofire.
        pad[6]=1;
        repeat(20) @(negedge clk);
        count_first=0;
        for(i=0;i<12;i=i+1) begin frame; count_first=count_first+joy1[4]; end
        if(count_first!=6 || joy1[5]!==0)
            $fatal(1,"ordinary games must pulse action 1 only: %d",count_first);
        second=1;
        repeat(20) @(negedge clk);
        count_second=0;
        for(i=0;i<12;i=i+1) begin frame; count_second=count_second+joy1[5]; end
        if(count_second!=6 || joy1[4]!==0)
            $fatal(1,"Golfing Greats must pulse Shot/action 2 only: %d",count_second);
        pad=0; frame;
        if(joy1[4] || joy1[5]) $fatal(1,"released action kept firing");
        $display("PASS: Riders menu autofire selects action 1 or Shot without affecting the other");
        $finish;
    end
endmodule
