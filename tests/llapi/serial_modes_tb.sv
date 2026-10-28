`timescale 1ns/1ps
module serial_modes_tb;
    reg clk50=0,clksys=0;
    always #10 clk50=~clk50;
    always #13 clksys=~clksys;
    reg [1:0] mode=0;
    reg blissbox=0;
    wire [6:0] pins;
    wire [15:0] joy1,joy2;
    wire [3:0] start,coin;
    wire osd;
    reg [15:0] snes_pressed=0;
    integer snes_bit=0;
    wire [6:0] input_pins={1'b1,(mode==1 ? (pins[0] ? ~snes_pressed[0] : ~snes_pressed[snes_bit]) : 1'b1),5'b11111};
    always @(negedge pins[0]) snes_bit=0;
    always @(negedge pins[1]) if(mode==1 && !pins[0] && snes_bit<15) snes_bit=snes_bit+1;
    task scan;begin repeat(150000) @(negedge clk50);end endtask
    jtframe_serial_arcade dut(.clk_50(clk50),.clk_sys(clksys),.rst(1'b0),
        .vblank(1'b0),.osd_active(1'b0),.mode(mode),.saturn_blissbox(blissbox),.user_in(input_pins),
        .user_out(pins),.usb1(16'h1234),.usb2(16'h5678),
        .joy1(joy1),.joy2(joy2),.start(start),.coin(coin),.osd_request(osd));
    task choose(input [1:0] value); begin
        mode=value;
        repeat(20) @(negedge clk50);
        if(pins!==7'h7f) $fatal(1,"port was not released during mode change");
        repeat(8000) @(negedge clk50);
    end endtask
    initial begin
        repeat(8000) @(negedge clk50);
        if(mode!=0 || pins[2]!==0) $fatal(1,"LLAPI is not the initial active mode");
        if(joy1!==16'h1234 || joy2!==16'h5678) $fatal(1,"LLAPI USB fallback regressed");
        choose(1);
        if(pins[6:2]!==5'b11111 || joy2!==16'h1234) $fatal(1,"SNES pin allocation or USB P2");
        snes_pressed=(1<<0)|(1<<4)|(1<<2); scan();
        if(joy1!==16'h18 || coin!==1 || start!==0) $fatal(1,"SNAC game/coin routing");
        snes_pressed=(1<<8)|(1<<3); scan();
        if(joy1!==16'h20 || start!==1 || coin!==0) $fatal(1,"SNAC Start routing");
        snes_pressed=(1<<0)|(1<<3)|(1<<5); scan();
        if(!osd || joy1!==0 || start!==0 || coin!==0) $fatal(1,"SNAC menu/inhibit routing");
        choose(2);
        if((pins|7'h10)!==7'h7f) $fatal(1,"MD drives a pin other than TH");
        choose(3);
        if((pins|7'h50)!==7'h7f) $fatal(1,"Saturn drives a pin other than TH/TR");
        blissbox=1;
        repeat(20) @(negedge clk50);
        if(pins!==7'h7f) $fatal(1,"pinout switch did not release the port");
        repeat(8000) @(negedge clk50);
        if((pins|7'h50)!==7'h7f) $fatal(1,"Bliss-Box pinout drives a data pin");
        choose(0);
        if(pins[2]!==0 || joy1!==16'h1234 || joy2!==16'h5678) $fatal(1,"LLAPI not restored");
        $display("PASS: LLAPI default, exclusive GPIO ownership, released transition, USB P2 and LLAPI restoration");
        $finish;
    end
endmodule
