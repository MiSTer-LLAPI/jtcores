`timescale 1ns/1ps
module narc_autofire_tb;
    reg clk=0, rst=1, osd=0, vb=0;
    reg [2:0] mode=0;
    reg [7:0] type1=27, type2=3;
    reg [31:0] p1=0, p2=0;
    reg [2:0] extra1=0,extra2=0;
    reg [8:0] pad1=0,pad2=0;
    reg [15:0] db1=0,db2=0;
    wire [15:0] joy1,joy2;
    wire [3:0] start,coin;
    wire [19:0] info;
    always #5 clk=~clk;
    jtframe_serial_arcade #(.BUTTONS(5)) dut (
        .clk_50(clk),.clk_sys(clk),.info_clk(clk),.rst(rst),.mode(mode),
        .osd_active(osd),.vblank(vb),.repoll_off(1'b0),.loss_resume(1'b0),
        .autofire_enable(1'b1),.autofire_enable2(1'b1),
        .autofire_toggle(1'b0),.autofire_toggle2(1'b0),
        .autofire_rate1(2'd0),.autofire_rate2(2'd0),
        .usb1(16'd0),.usb2(16'd0),.user_in(7'h7f),
        .controller_info(info),.joy1(joy1),.joy2(joy2),.start(start),.coin(coin));
    task settle; repeat(12) @(negedge clk); endtask
    task frame; vb=1;settle();vb=0;settle();endtask
    task expect_inputs(input [15:0] j1,j2,input [3:0] s,c);
        settle();
        if({joy1,joy2,start,coin}!=={j1,j2,s,c})
          $fatal(1,"mode %0d inputs got %h %h %h %h expected %h %h %h %h",mode,joy1,joy2,start,coin,j1,j2,s,c);
    endtask
    integer i;
    initial begin
        force dut.ready50=1'b1;
        force dut.u_llapi.valid1=1'b1; force dut.u_llapi.valid2=1'b1;
        force dut.u_llapi.type1=type1; force dut.u_llapi.type2=type2;
        force dut.u_llapi.buttons1=p1; force dut.u_llapi.buttons2=p2;
        force dut.snac_extra1=extra1; force dut.snac_extra2=extra2;
        force dut.snac_pad=pad1; force dut.snac_pad2=pad2;
        force dut.db1=db1;force dut.db2=db2;
        settle();rst=0;settle();
        for(i=0;i<5;i=i+1) begin
            p1=1<<(i==4 ? 6:i); p2=1<<(i==4 ? 8:i);
            expect_inputs(16'h10<<i,16'h10<<i,0,0);
        end
        p1=32'h20;p2=32'h20;expect_inputs(0,0,3,0);
        p1=32'h10;p2=32'h40;expect_inputs(0,0,0,3);
        p1=0;p2=0;expect_inputs(0,0,0,0);
        p1=1<<7;p2=1<<9;expect_inputs(16'h10,16'h10,0,0);
        repeat(3) frame();expect_inputs(0,0,0,0);
        p1[0]=1;expect_inputs(16'h10,0,0,0);
        p1=0;repeat(3)frame();expect_inputs(0,16'h10,0,0);
        p2=0;expect_inputs(0,0,0,0);
        type1=1;p1=1<<7;expect_inputs(0,0,0,0);
        p1=0;
        for(i=1;i<=4;i=i+1) begin
            mode=i;settle();settle();
            pad1=9'h70;pad2=9'h70;extra1=3;extra2=3;db1='h1f0;db2='h1f0;
            expect_inputs(16'h1f0,i>=3 ? 16'h1f0 : 16'h0,0,0);
            pad1=0;pad2=0;extra1=0;extra2=0;db1=0;db2=0;settle();
            extra1=4;extra2=4;db1='h200;db2='h200;
            expect_inputs(16'h10,i>=3 ? 16'h10 : 16'h0,0,0);
            repeat(3) frame();expect_inputs(0,0,0,0);
            extra1=0;extra2=0;db1=0;db2=0;expect_inputs(0,0,0,0);
        end
        extra1=4;extra2=4;expect_inputs(16'h10,16'h10,0,0);
        osd=1;expect_inputs(0,0,0,0);
        osd=0;expect_inputs(0,0,0,0);
        extra1=0;extra2=0;settle();extra1=4;expect_inputs(16'h10,0,0,0);
        mode=5;expect_inputs(0,0,0,0);
        mode=6;expect_inputs(0,0,0,0);
        $display("PASS NARC five independent actions, Start/Coin, both autofire channels, release and OSD");
        $finish;
    end
endmodule
