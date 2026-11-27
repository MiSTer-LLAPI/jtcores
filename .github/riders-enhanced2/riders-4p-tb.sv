module riders_4p_tb;
    reg clk=0;
    reg [8:1] addr=0;
    reg [6:0] joystick1=7'h11, joystick2=7'h22,
              joystick3=7'h33, joystick4=7'h44;
    reg [3:0] cab_1p=4'b1010;
    wire [7:0] dout;
    always #5 clk=~clk;
    jtriders_cab dut(
        .clk(clk), .cpu_cen(1'b0), .cs(1'b0), .LVBL(1'b0),
        .eep_rdy(1'b0), .eep_do(1'b0), .IPLn(3'b0), .addr(addr),
        .joystick1(joystick1), .joystick2(joystick2),
        .joystick3(joystick3), .joystick4(joystick4),
        .cab_1p(cab_1p), .coin(4'b0), .service(4'b0),
        .dip_test(1'b0), .dout(dout)
    );
    task expect_port(input [1:0] port_id, input [7:0] expected);
        begin
            @(negedge clk);
            addr[8]=0;
            addr[2:1]=port_id;
            @(negedge clk);
            if (dout !== expected)
                $fatal(1,"port %0d expected %02h, got %02h",port_id,expected,dout);
        end
    endtask
    initial begin
        expect_port(2'd0,{cab_1p[0],joystick1});
        expect_port(2'd1,{cab_1p[1],joystick2});
        expect_port(2'd2,{cab_1p[2],joystick3});
        expect_port(2'd3,{cab_1p[3],joystick4});
        $display("PASS: Riders cabinet keeps four independent joystick and start ports");
        $finish;
    end
endmodule
