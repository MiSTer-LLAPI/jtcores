// Check game-visible Sega I/O from CPU register reads. Only the CPU bus is driven here.
module s18_controls_tb;
    reg clk=0, reset=1, cab3=1, bus_read=0, bus_write=0;
    reg [7:0] game_id=0, p1=0, p2=0, p3=0;
    reg [2:0] starts=7, coins=7;
    reg [1:0] dial_x=0, dial_y=0;
    reg [23:1] address=0;
    reg [8:0] h=0, v=0;
    reg rate57=0;
    wire hsync, vsync;
    always #5 clk=~clk;
    jts18_main dut(.clk(clk),.rst(reset),.game_id(game_id),.cab3(cab3),
        .joystick1(p1),.joystick2(p2),.joystick3(p3),.cab_1p(starts),.coin(coins),
        .dial_x(dial_x),.dial_y(dial_y),.gun_1p_x(9'd64),.gun_1p_y(9'h015),
        .gun_2p_x(9'd256),.gun_2p_y(9'h05c),.dip_test(1'b1),.service(1'b1),.dipsw(16'd0));
    jts18_sync video(.clk(clk),.pxl_cen(1'b1),.is_57Hz(rate57),
        .hdump(h),.vdump(v),.HS(hsync),.VS(vsync));
    task tick; @(negedge clk); endtask
    task read_port(input [15:0] byte_address, input [7:0] expected);
        begin
            address = byte_address >> 1; bus_read=1; tick;
            if(dut.io_dout !== expected)
                $fatal(1,"I/O %h expected %h got %h",byte_address,expected,dut.io_dout);
            bus_read=0; tick;
        end
    endtask
    task read_gun(input [1:0] ch, input [7:0] expected);
        integer i;
        reg [7:0] actual;
        begin
            address=(16'h3010 >> 1) + ch; bus_write=1; tick; bus_write=0; tick;
            for(i=7;i>=0;i=i-1) begin
                bus_read=1; tick; actual[i]=dut.io_dout[7];
                if(dut.io_dout[6:0] !== 7'h7f) $fatal(1,"gun bus framing");
                bus_read=0; tick;
            end
            if(actual!==expected) $fatal(1,"gun %d expected %h got %h",ch,expected,actual);
        end
    endtask
    task test_timing(input mode57, input [8:0] h_start, h_end, v_start, v_end);
        begin
            rate57=mode57;
            h=h_end; v=v_end; tick;
            if({hsync,vsync}!==0) $fatal(1,"initial sync");
            h=h_start; v=v_start; tick;
            if({hsync,vsync}!==2'b10) $fatal(1,"horizontal sync");
            h=h_end; tick;
            if({hsync,vsync}!==2'b01) $fatal(1,"vertical sync");
            v=v_end; tick;
            if({hsync,vsync}!==0) $fatal(1,"sync end");
        end
    endtask
    initial begin
        force dut.io_we=bus_write; force dut.io_rd=bus_read;
        force dut.io_cs=1'b1; force dut.A=address;
        tick; reset=0; repeat(4) tick;
        p1=8'h2b; p2=8'ha5; p3=8'hce;
        read_port(0,8'hb2); read_port(2,8'h5a); read_port(4,8'hec);
        starts=3'b011; coins=3'b011;
        read_port(8,8'hbe);
        starts=3'b111; coins=3'b111;
        read_port(8,8'hff);
        cab3=0; game_id=8'h40; repeat(4) tick;
        starts=3'b011; read_port(4,8'he4);
        starts=3'b111; read_port(4,8'hec);
        game_id=8'h10; tick;
        p1=8'h20; p2=8'h10; p3=8'h10;
        read_port(0,8'hb6); read_port(2,8'hff); read_port(4,8'hff);
        read_gun(0,8'hea); read_gun(1,8'd54); read_gun(2,8'ha3); read_gun(3,8'd218);
        address=(16'h3000>>1); bus_write=1; tick; bus_write=0; tick;
        read_port(16'h3000,0); read_port(16'h3004,0);
        dial_x=2'b01; dial_y=2'b10; tick; dial_x=3; dial_y=3; tick;
        dial_x=2'b10; dial_y=2'b01; tick; dial_x=0; dial_y=0; repeat(3) tick;
        // The cabinet reverses the phase order into the 4701: X increases and Y decreases.
        read_port(16'h3000,8'h01); read_port(16'h3004,8'hff);
        test_timing(0,9'h08e,9'h0ae,9'h0e9,9'h0ed);
        test_timing(1,9'h088,9'h0a8,9'h0eb,9'h0ef);
        $display("PASS: three independent joystick ports, cabinet P3 Start/Coin and Moonwalker, Laser Ghost two gun ADCs, Wally quadrature X/Y, 57/60 Hz sync");
        $finish;
    end
endmodule
