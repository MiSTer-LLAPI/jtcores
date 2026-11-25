// Exercise Escape Kids cabinet reads through the official Konami CPU data mux.
// Drive the address bus in place of the CPU. Unrelated devices are not needed.
`timescale 1ns/1ps
module esckids_cabinet_tb;
    reg clk = 0, rst = 1;
    always #5 clk = !clk;
    reg [15:0] addr = 0;
    reg [6:0] joy [0:3];
    reg [3:0] start = '1, coin = '1;
    reg service = 1;

    jtsimson_main dut (
        .clk(clk), .rst(rst), .paroda(1'b0), .suratk(1'b0), .simson(1'b0),
        .vendetta(1'b0), .esckids(1'b1), .cab_1p(start), .coin(coin),
        .joystick1(joy[0]), .joystick2(joy[1]), .joystick3(joy[2]),
        .joystick4(joy[3]), .service(service), .dip_test(1'b1)
    );

    task check_register(input [15:0] address, input [7:0] wanted);
        addr = address;
        @(negedge clk);
        if (dut.cpu_din !== wanted)
            $fatal(1, "Escape Kids cabinet address %h expected %h, returned %h", addr, wanted, dut.cpu_din);
    endtask

    integer source, other, bitnum, active_port;
    reg [7:0] expected;
    initial begin
        force dut.A = addr;
        for (source=0; source<4; source=source+1) joy[source] = '1;
        @(negedge clk);
        rst = 0;
        for (source=0; source<4; source=source+1) begin
            for (bitnum=0; bitnum<8; bitnum=bitnum+1) begin
                if (bitnum == 7) coin[source] = 0;
                else joy[source][bitnum] = 0;
                // CPU swaps the two low direction bits. Jump and Dash are bits 4 and 5.
                active_port = bitnum < 2 ? 1 - bitnum : bitnum;
                for (other=0; other<4; other=other+1) begin
                    expected = 8'hff;
                    if (other == source) expected[active_port] = 0;
                    check_register(16'h3f80 + other, expected);
                end
                coin = '1;
                joy[source] = '1;
            end
            start[source] = 0;
            check_register(16'h3f91, {4'hf, start});
            start = '1;
        end
        service = 0;
        check_register(16'h3f91, 8'h0f);
        service = 1;
        check_register(16'h3f91, 8'hff);
        for (other=0; other<4; other=other+1) check_register(16'h3f80 + other, 8'hff);
        $display("PASS Escape Kids native CPU cabinet registers, P1-P4, directions, Jump, Dash, coins, Start, Service and release");
        $finish;
    end
endmodule
