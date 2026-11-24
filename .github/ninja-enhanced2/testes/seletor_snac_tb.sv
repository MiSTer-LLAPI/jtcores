`timescale 1ns/1ps
module verify_gp_mux;
    parameter bit REPOLL_OFF=1;
    reg clk=0, rst=1, osd_active=0;
    always #10 clk=~clk;
    reg [2:0] current_mode=0;
    wire [6:0] pins, stock_pins;
    wire [6:0] lines;
    wire [15:0] joy1,joy2,stock_joy1,stock_joy2;
    wire [3:0] start, coin, stock_start, stock_coin;
    wire request,stock_request,db15_drive,stock_db15_drive;
    wire [19:0] guide,stock_guide;
    wire al,ad,bl,bd;
    wire integer polls_a,reports_a,modes_a,polls_b,reports_b,modes_b;
    localparam [15:0] USB1=16'h0200,USB2=16'h0400;
    wire attach_a=current_mode==0 || current_mode==7;
    wire attach_b=current_mode==0;
    assign lines=pins & {1'b1,(bd || !attach_b),(bl || !attach_b),2'b11,(ad || !attach_a),(al || !attach_a)};
    timeout_adapter #(.REPORT_TYPE(27)) pad_a(
        .clk(clk),.host_latch(!attach_a || pins[0]),.host_data(pins[1]),
        .device_latch(al),.device_data(ad),.polls(polls_a),.reports(reports_a),.modes(modes_a));
    timeout_adapter #(.REPORT_TYPE(22)) pad_b(
        .clk(clk),.host_latch(!attach_b || pins[4]),.host_data(pins[5]),
        .device_latch(bl),.device_data(bd),.polls(polls_b),.reports(reports_b),.modes(modes_b));
    jtframe_serial_arcade dut(
        .clk_50(clk),.clk_sys(clk),.rst(rst),.vblank(1'b0),.osd_active(osd_active),.repoll_off(REPOLL_OFF),
        .autofire_enable(1'b0),.autofire_toggle(1'b0),.autofire_enable2(1'b0),.autofire_toggle2(1'b0),
        .autofire_rate1(2'd0),.autofire_rate2(2'd0),.loss_resume(1'b0),
        .info_clk(clk),.controller_info(guide),.mode(current_mode),
        .user_in(lines),.user_out(pins),.usb1(USB1),.usb2(USB2),.joy1(joy1),.joy2(joy2),
        .start(start),.coin(coin),.db15_drive(db15_drive),.osd_request(request));
    jtframe_serial_arcade_stock baseline(
        .clk_50(clk),.clk_sys(clk),.rst(rst),.vblank(1'b0),.osd_active(osd_active),.repoll_off(1'b0),
        .autofire_enable(1'b0),.autofire_toggle(1'b0),.autofire_enable2(1'b0),.autofire_toggle2(1'b0),
        .autofire_rate1(2'd0),.autofire_rate2(2'd0),.loss_resume(1'b0),
        .info_clk(clk),.controller_info(stock_guide),.mode(current_mode),
        .user_in(lines),.user_out(stock_pins),.usb1(USB1),.usb2(USB2),.joy1(stock_joy1),.joy2(stock_joy2),
        .start(stock_start),.coin(stock_coin),.db15_drive(stock_db15_drive),.osd_request(stock_request));
    reg compare_stock=0;
    integer cutoff_polls2,cutoff_modes1;
    task ticks(input integer count);
        repeat(count) @(negedge clk);
    endtask
    task select_mode(input [2:0] selected);
        current_mode=selected;
        ticks(6);
        repeat(7488) begin
            if(pins!==7'h7f) $fatal(1,"mode %d drove connector before release interval",selected);
            @(negedge clk);
        end
        ticks(30);
        if(!dut.ready50) $fatal(1,"mode %d did not settle",selected);
    endtask
    always @(negedge clk) begin
        if(compare_stock && {pins,joy1,joy2,start,coin,request,db15_drive} !==
                            {stock_pins,stock_joy1,stock_joy2,stock_start,stock_coin,stock_request,stock_db15_drive})
            $fatal(1,"mode %d gameplay/pin mismatch against stock",current_mode);
    end
    initial begin
        ticks(25);
        rst=0;
        compare_stock=1;
        ticks(900000);
        if(joy1!==16'h0010 || joy2!==16'h0010 || guide!=={2'b01,8'd22,2'b01,8'd27})
            $fatal(1,"2P guide/play mismatch: %x %04x/%04x",guide,joy1,joy2);
        $display("2P initial full pass guide=%05x joy=%04x/%04x",guide,joy1,joy2);
        osd_active=1;
        ticks(50000);
        if(guide!=={2'b01,8'd22,2'b01,8'd27}) $fatal(1,"2P OSD lost identity");
        compare_stock=0;
        for(integer mode_id=1;mode_id<=6;mode_id++) begin
            select_mode(mode_id[2:0]);
            compare_stock=1;
            ticks(6000);
            compare_stock=0;
        end
        $display("All 6 SNAC selections match stock; all swaps release pins for 150 us");
        select_mode(0);
        osd_active=0;
        ticks(900000);
        if(joy1!==16'h0010 || joy2!==16'h0010 || guide!=={2'b01,8'd22,2'b01,8'd27})
            $fatal(1,"2P did not recover after SNAC swaps");
        $display("2P resumed after swaps; repoll_off=%b",REPOLL_OFF);
        $finish;
    end
endmodule
