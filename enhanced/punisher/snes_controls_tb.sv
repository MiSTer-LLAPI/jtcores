// SPDX-License-Identifier: GPL-3.0-or-later
// Feed normal SNES serial data to both ports and check the CPS action bits.
module snes_controls_tb;
    reg clk = 0, reset = 1, vblank = 0;
    always #5 clk = ~clk;
    reg [1:0] enable = 0;
    reg [15:0] pressed1 = 0, pressed2 = 0;
    integer bit1 = 0, bit2 = 0;
    wire [6:0] pins;
    always @(negedge pins[0]) begin bit1 = 0; bit2 = 0; end
    always @(negedge pins[1]) if (!pins[0] && bit1 < 15) bit1 = bit1 + 1;
    always @(negedge pins[3]) if (!pins[0] && bit2 < 15) bit2 = bit2 + 1;
    wire [6:0] inputs = {~pressed2[bit2], ~pressed1[bit1], 5'b11111};
    wire [15:0] joy1, joy2;
    wire [3:0] start, coin;
    wire osd;
    jtframe_serial_arcade #(.BUTTONS(`JTFRAME_BUTTONS)) dut(
        .clk_50(clk), .clk_sys(clk), .info_clk(clk), .rst(reset), .vblank(vblank),
        .osd_active(1'b0), .loss_resume(1'b0), .mode(3'd4), .repoll_off(1'b0),
        .autofire_enable(enable[0]), .autofire_enable2(enable[1]),
        .autofire_toggle(1'b0), .autofire_toggle2(1'b0),
        .autofire_rate1(2'd0), .autofire_rate2(2'd2),
        .user_in(inputs), .user_out(pins), .usb1(16'd0), .usb2(16'd0),
        .joy1(joy1), .joy2(joy2), .start(start), .coin(coin), .osd_request(osd)
    );
    defparam dut.u_snac.TICK_CYCLES = 8;
    defparam dut.u_snac.SCAN_TICKS = 80;
    localparam [15:0] B = 16'h0001, A = 16'h0100, X = 16'h0200;
    task scan;
        repeat(1400) @(negedge clk);
    endtask
    task frame;
        begin
            vblank = 1; repeat(6) @(negedge clk);
            vblank = 0; repeat(6) @(negedge clk);
        end
    endtask
    // All other pad bits and the cabinet shortcuts must stay quiet.
    task check(input [1:0] p1, input [1:0] p2);
        if (joy1 !== {10'd0,p1,4'd0} || joy2 !== {10'd0,p2,4'd0} ||
            {start,coin,osd} !== 9'd0)
            $fatal(1, "Expected Jump/Attack %b,%b; got joy=%h,%h start=%h coin=%h osd=%b",
                       p1, p2, joy1, joy2, start, coin, osd);
    endtask
    initial begin
        repeat(8) @(negedge clk); reset = 0;
        repeat(18000) @(negedge clk);
        pressed1 = X; pressed2 = X; scan(); check(0,0);
        pressed1 = B; pressed2 = A; scan(); check(1,2);
        pressed1 = A; pressed2 = B; scan(); check(2,1);
        pressed1 = 0; pressed2 = 0; enable = 1; scan();
        pressed1 = X; pressed2 = X; scan(); check(1,0);
        repeat(3) frame(); check(0,0);
        pressed1 = X | B | A; scan(); check(3,0);
        pressed1 = 0; pressed2 = 0; enable = 3; scan(); check(0,0);
        pressed1 = A | X; pressed2 = X; scan(); check(3,1);
        repeat(2) frame(); check(3,0);
        frame(); check(2,0);
        frame(); check(2,1);
        pressed1 = 0; scan(); check(0,1);
        pressed2 = 0; scan(); check(0,0);
        $display("PASS two SNES pads: B=Attack, A=Jump, X=Hold, independent P1/P2 rates and enable");
        $finish;
    end
endmodule
