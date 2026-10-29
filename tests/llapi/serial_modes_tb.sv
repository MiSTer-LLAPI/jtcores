`timescale 1ns/1ps
module serial_modes_tb;
    reg clk50=0,clksys=0;
    always #10 clk50=~clk50;
    always #13 clksys=~clksys;
    reg [2:0] mode=0;
    wire [6:0] pins;
    wire [15:0] joy1,joy2;
    wire [3:0] start,coin;
    wire osd;
    reg [15:0] snes_pressed=0;
    integer snes_bit=0;
    wire [6:0] snes_pins={1'b1,(mode==4 ? (pins[0] ? ~snes_pressed[0] : ~snes_pressed[snes_bit]) : 1'b1),5'b11111};
    reg [5:0] md_high=6'h3f;
    reg [1:0] md_as=2'b11;
    wire [5:0] md_data=pins[4] ? md_high : {md_as,2'b00,md_high[1:0]};
    wire [6:0] input_pins=mode==2 ?
        {md_data[5],md_data[2],1'b1,md_data[3],md_data[4],md_data[0],md_data[1]} : snes_pins;
    always @(negedge pins[0]) snes_bit=0;
    always @(negedge pins[1]) if(mode==4 && !pins[0] && snes_bit<15) snes_bit=snes_bit+1;
    task scan;begin repeat(150000) @(negedge clk50);end endtask
    jtframe_serial_arcade dut(.clk_50(clk50),.clk_sys(clksys),.rst(1'b0),
        .vblank(1'b0),.osd_active(1'b0),.mode(mode),.user_in(input_pins),
        .user_out(pins),.usb1(16'h1234),.usb2(16'h5678),
        .joy1(joy1),.joy2(joy2),.start(start),.coin(coin),.osd_request(osd));
    task choose(input [2:0] value); begin
        mode=value;
        repeat(20) @(negedge clk50);
        if(pins!==7'h7f) $fatal(1,"port was not released during mode change");
        repeat(8000) @(negedge clk50);
    end endtask
    initial begin
        repeat(8000) @(negedge clk50);
        if(mode!=0 || pins[2]!==0) $fatal(1,"LLAPI is not the initial active mode");
        if(joy1!==16'h1234 || joy2!==16'h5678) $fatal(1,"LLAPI USB fallback regressed");
        choose(4);
        if(pins[6:2]!==5'b11111 || joy2!==16'h1234) $fatal(1,"SNES pin allocation or USB P2");
        snes_pressed=(1<<0)|(1<<4)|(1<<2); scan();
        if(joy1!==16'h18 || coin!==1 || start!==0) $fatal(1,"SNAC game/coin routing");
        snes_pressed=(1<<8)|(1<<3); scan();
        if(joy1!==16'h20 || start!==1 || coin!==0) $fatal(1,"SNAC Start routing");
        snes_pressed=(1<<0)|(1<<3)|(1<<5); scan();
        if(!osd || joy1!==0 || start!==0 || coin!==0) $fatal(1,"SNAC menu/inhibit routing");
        choose(2);
        if((pins|7'h10)!==7'h7f) $fatal(1,"MD drives a pin other than TH");
        md_high=~6'b010001;md_as=~2'b11;scan(); // B,Up,A,Start
        if(joy1!==16'h38 || start!==1 || coin!==0) $fatal(1,"SEGA 3-button full routing");
        md_high=~6'b010010;md_as=~2'b10;scan(); // Down+Start+B menu
        if(!osd || joy1 || start || coin) $fatal(1,"SEGA menu routing");
        md_high=~6'b000010;scan();
        if(coin!==1 || start!==0 || joy1!==4) $fatal(1,"SEGA Down+Start coin");
        choose(1);
        if((pins|7'h50)!==7'h7f) $fatal(1,"Saturn drives a pin other than TH/TR");
        choose(3);
        if((pins|7'h03)!==7'h7f) $fatal(1,"DB15 drives an input pin");
        choose(0);
        if(pins[2]!==0 || joy1!==16'h1234 || joy2!==16'h5678) $fatal(1,"LLAPI not restored");
        $display("PASS: LLAPI default, exclusive GPIO ownership, released transition, USB P2 and LLAPI restoration");
        $finish;
    end
endmodule
