// Drive the Z80 bus and read the cabinet register through the unmodified data mux.
`timescale 1ns/1ps
module pang_cabinet_tb;
    reg clk=0, reset=1;
    always #5 clk=!clk;
    reg [15:0] address=0;
    reg [1:0] profile=0, start=3;
    reg coin=1, service=1, init_n=1, write_n=1, read_n=0;
    reg [7:0] write_data=0;
    reg [7:0] joys[2], mouse[2];
    jtpang_main dut (
        .clk(clk), .rst(reset), .ctrl_type(profile), .init_n(init_n),
        .joystick1(joys[0]), .joystick2(joys[1]), .cab_1p(start),
        .coin(coin), .service(service), .mouse_1p(mouse[0]), .mouse_2p(mouse[1])
    );

    task check_port(input integer port, input [7:0] wanted);
        address=port;
        repeat(2) @(posedge clk);
        @(negedge clk);
        if (dut.cpu_din !== wanted)
            $fatal(1, "Profile %d port %d: returned %h, expected %h",profile,port,dut.cpu_din,wanted);
    endtask

    task select_dial(input bit movement);
        address=1;
        read_n=1;
        write_n=0;
        write_data=movement ? 8'h00 : 8'h80;
        @(posedge clk);
        @(negedge clk);
        read_n=0;
        write_n=1;
    endtask

    integer mode, player, button;
    reg [7:0] wanted;
    initial begin
        force dut.A=address;
        force dut.mreq_n=1;
        force dut.iorq_n=0;
        force dut.rd_n=read_n;
        force dut.wr_n=write_n;
        force dut.cpu_dout=write_data;
        joys[0]='1; joys[1]='1; mouse[0]=0; mouse[1]=0;
        @(negedge clk);
        reset=0;
        for(mode=0;mode<4;mode=mode+1) begin
            profile=mode;
            for(player=0;player<2;player=player+1) begin
                for(button=0;button<8;button=button+1) begin
                    joys[player][button]=0;
                    wanted=8'hff;
                    case(profile)
                        0: if(button<4) wanted[4+button]=0;
                           else if(button<6) wanted[7-button]=0;
                        1: if(button==4) wanted[7]=0;
                        2: wanted[7-(button%4)]=0;
                        3: begin
                            if(button<3) wanted[4+button]=0;
                            if(button==4 || button==5) begin
                                wanted[7]=0;
                                wanted[7-button]=0;
                            end
                        end
                    endcase
                    check_port(player+1,wanted);
                    check_port(2-player,8'hff);
                    joys[player]='1;
                    check_port(player+1,8'hff);
                end
                start[player]=0;
                if (profile==2) begin
                    check_port(player+1,8'hfb);
                    check_port(2-player,8'hff);
                end else check_port(0,player==0 ? 8'hf7 : 8'hfd);
                start='1;
            end
            coin=0; check_port(0,8'h7f); coin=1;
            service=0; check_port(0,profile==2 ? 8'hbe : 8'hbf); service=1;
            check_port(0,8'hff);
        end
        // Super Pang requests first-run EEPROM initialization via P1 Start.
        profile=0; init_n=0; check_port(0,8'hf7); init_n=1; check_port(0,8'hff);
        // Block dial alternates direction/button and position reads at the same port.
        profile=1; mouse[0]=8'h93; mouse[1]=8'h6c;
        select_dial(0); check_port(1,8'hf7); check_port(2,8'hff);
        select_dial(1); check_port(1,8'h27); check_port(2,8'hdb);
        $display("PASS Pang cabinet: both players, four hardware profiles, direction and action bit wiring, start, coin, service, release, EEPROM init and dial");
        $finish;
    end
endmodule
