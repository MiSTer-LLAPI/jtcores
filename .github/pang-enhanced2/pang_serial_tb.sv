// Test boundaries: samples produced by physical readers, and the Z80 address bus.
// ROM selection, both player routes, the gesture, the menu and the cabinet registers are real RTL.
`timescale 1ns/1ps
module pang_serial_tb;
    reg clk=0, rom_clk=0, rst=1, vb=0, osd=0;
    always #5 clk=!clk;
    always #3 rom_clk=!rom_clk;
    reg [63:0] status=0;
    reg [26:0] rom_addr=0;
    reg [7:0] byte_data=0;
    reg rom_write=0, rom=0;
    reg [15:0] cpu_addr=0;
    reg [8:0] pad1=0, pad2=0;
    reg [2:0] extra1=0, extra2=0;
    reg [31:0] report1=0, report2=0;
    reg [1:0] valid=0;
    reg [15:0] usb1=0, usb2=0;
    wire [15:0] db1={4'd0,pad1[8:7],extra1,pad1[6:0]};
    wire [15:0] db2={4'd0,pad2[8:7],extra2,pad2[6:0]};
    wire [1:0] aux={extra2[0],extra1[0]};
    wire valid1=valid[0], valid2=valid[1];
    jtframe_mister #(.BUTTONS(`JTFRAME_BUTTONS)) top(
        .clk_sys(clk), .clk_rom(rom_clk), .clk_llapi(clk), .LVBL(!vb),
        .OSD_STATUS(osd), .USER_IN(7'h7f)
    );
    wire [9:0] joy1,joy2;
    wire [3:0] coin,start;
    jtframe_merge_keyjoy merge(
        .clk(clk), .rst(rst), .board_coin(top.llapi_coin), .board_start(top.llapi_start),
        .joy_coin(4'd0), .joy_start(4'd0), .key_coin(4'd0), .key_start(4'd0),
        .joy1(top.joystick1), .joy2(top.joystick2), .joy3(16'd0), .joy4(16'd0),
        .key_joy1(10'd0), .key_joy2(10'd0), .key_joy3(10'd0), .key_joy4(10'd0),
        .mouse_but_1p(3'd0), .mouse_but_2p(3'd0), .game_joy1(joy1), .game_joy2(joy2),
        .game_coin(coin), .game_start(start)
    );
    jtpang_game game(
        .rst(rst), .clk(clk), .joystick1(joy1[7:0]), .joystick2(joy2[7:0]),
        .coin(coin), .cab_1p(start), .service(1'b1), .mouse_1p(16'd0), .mouse_2p(16'd0),
        .ioctl_addr(rom_addr[25:0]), .ioctl_wr(rom_write), .ioctl_ram(!rom), .header(rom),
        .ioctl_dout(byte_data)
    );
    task settle; repeat(8) @(negedge clk); endtask
    task frame; vb=1; settle; vb=0; settle; endtask
    task header_write(input [26:0] addr, input [7:0] data, input is_rom);
        rom=is_rom; rom_addr=addr; byte_data=data; rom_write=1; settle;
        rom_write=0; rom=0; settle;
    endtask
    task check_profile(input [1:0] wanted);
        if (game.ctrl_type!==wanted || top.no_spare_cab!==(wanted==2) || top.no_spare_sys!==(wanted==2))
            $fatal(1,"Game/menu disagree on ROM profile %d",wanted);
        if (top.u_serial.autofire_enable!==(wanted!=2 && status[8]) ||
            top.u_serial.autofire_enable2!==(wanted!=2 && status[23]) ||
            top.status_menumask[7]!==(wanted==2 || status[63:61]>=5))
            $fatal(1,"Game/menu auxiliary enable mismatch for %d",wanted);
    endtask
    task check_read(input integer port,input [7:0] expect_byte);
        cpu_addr=port; settle;
        if (game.u_main.cpu_din!==expect_byte)
            $fatal(1,"Mode %d profile %d port %d expected %h got %h",status[63:61],game.ctrl_type,port,expect_byte,game.u_main.cpu_din);
    endtask
    task set_mode(input [2:0] m);
        status[63:61]=m;
        repeat (7600) @(negedge clk);
    endtask
    task buttons(input integer player,input [7:0] game_bits,input do_start,input credit);
        reg [31:0] report;
        reg [8:0] physical;
        report=0; report[27:24]=game_bits[3:0]; report[3:0]=game_bits[7:4];
        report[5]=do_start; report[4]=credit;
        physical={credit,do_start,game_bits[6:0]};
        if (player==1) begin report1=report; pad1=physical; extra1={2'd0,game_bits[7]}; end
        else begin report2=report; pad2=physical; extra2={2'd0,game_bits[7]}; end
        settle;
    endtask
    task tap(input integer player,input [7:0] action);
        buttons(player,action,1,0); repeat(3) frame;
        check_read(0,8'hff);
        if (top.llapi_osd!==0 || top.llapi_start!==0) $fatal(1,"Start shortcut leaked into the OSD or cabinet");
        buttons(player,action,0,0); repeat(3) frame;
    endtask
    task count_pulses(input integer player,input integer port_bit,input integer expected);
        integer n,hits;
        hits=0; cpu_addr=player;
        for (n=0;n<12;n=n+1) begin
            frame;
            if (game.u_main.cpu_din[port_bit]!==1'b0 && game.u_main.cpu_din[port_bit]!==1'b1)
                $fatal(1,"Undriven pulse output");
            if (!game.u_main.cpu_din[port_bit]) hits=hits+1;
        end
        if (hits!=expected) $fatal(1,"Mode %d P%d bit %d expected %d active frames, got %d",status[63:61],player,port_bit,expected,hits);
    endtask

    integer m,players,p,bitnum,expected_position,limit;
    initial begin
        force top.rst=rst; force top.status=status; force top.ioctl_addr=rom_addr;
        force top.ioctl_wr=rom_write; force top.ioctl_rom=rom; force top.ioctl_dout=byte_data;
        force top.joyusb_1=usb1; force top.joyusb_2=usb2;
        force top.u_serial.snac_pad=pad1; force top.u_serial.snac_pad2=pad2;
        force top.u_serial.snac_extra1=extra1; force top.u_serial.snac_extra2=extra2;
        force top.u_serial.snac_af=aux; force top.u_serial.db1=db1; force top.u_serial.db2=db2;
        force top.u_serial.u_llapi.valid1_sync=valid1; force top.u_serial.u_llapi.valid2_sync=valid2;
        force top.u_serial.u_llapi.buttons1_sync=report1; force top.u_serial.u_llapi.buttons2_sync=report2;
        force top.u_serial.u_llapi.saturn1_sync=0; force top.u_serial.u_llapi.saturn2_sync=0;
        force game.u_main.A=cpu_addr; force game.u_main.mreq_n=1;
        force game.u_main.iorq_n=0; force game.u_main.rd_n=0; force game.u_main.wr_n=1;
        settle; rst=0; settle;
        for (m=0;m<=6;m=m+1) begin
            set_mode(m); valid=m==0 ? 3 : 0;
            players=(m==0 || m==3 || m==4 || m==6) ? 2 : 1;
            status[8]=1; status[23]=1;
            header_write(15,2,1); check_profile(2);
            header_write(14,0,1); check_profile(2);
            header_write(15,0,0); check_profile(2);
            for(p=1;p<=players;p=p+1) begin
                // Every pad has four directions. NES/PCE have two independent actions.
                limit=m>=5 ? 5 : 7;
                for(bitnum=0;bitnum<=limit;bitnum=bitnum+1) begin
                    buttons(p,1<<bitnum,0,0);
                    repeat(6) begin
                        frame; check_read(p,8'hff ^ (1<<(7-bitnum%4)));
                        check_read(3-p,8'hff);
                    end
                    buttons(p,0,0,0); check_read(p,8'hff);
                end
                buttons(p,0,1,0); check_read(p,8'hfb);
                buttons(p,0,0,1); check_read(0,8'h7f);
                buttons(p,0,0,0); check_read(0,8'hff);
                if(m>0 && m<5) begin
                    // Program the fourth face button with Start x3 on the quiz board.
                    buttons(p,8'h80,0,0); repeat(3) tap(p,8'h80);
                    count_pulses(p,4,6); buttons(p,0,0,0); check_read(p,8'hff);
                    buttons(p,8'h80,0,0); repeat(3) tap(p,8'h80);
                    count_pulses(p,4,12); buttons(p,0,0,0);
                end
            end
            header_write(15,3,1); check_profile(3);
            for(p=1;p<=players;p=p+1) begin
                buttons(p,8'h10,0,0); check_read(p,8'h77);
                buttons(p,8'h20,0,0); check_read(p,8'h7b);
                buttons(p,0,0,0); check_read(p,8'hff);
            end
            header_write(15,0,1); check_profile(0);
            for (p=1;p<=players;p=p+1) begin
                for(bitnum=0;bitnum<=5;bitnum=bitnum+1) begin
                    buttons(p,1<<bitnum,0,0);
                    expected_position=bitnum<4 ? bitnum+4 : 7-bitnum;
                    check_read(p,8'hff ^ (1<<expected_position)); check_read(3-p,8'hff);
                    buttons(p,0,0,0); check_read(p,8'hff);
                end
                buttons(p,0,1,0); check_read(0,p==1 ? 8'hf7 : 8'hfd);
                buttons(p,0,0,1); check_read(0,8'h7f); buttons(p,0,0,0);
                if(m<5) begin
                    buttons(p,8'h80,0,0); count_pulses(p,3,6);
                    buttons(p,0,0,0); check_read(p,8'hff);
                end
                if(m>0) begin
                    buttons(p,8'h10,0,0); repeat(2) tap(p,8'h10); count_pulses(p,3,12);
                    tap(p,8'h10); count_pulses(p,3,6); buttons(p,0,0,0); check_read(p,8'hff);
                    buttons(p,8'h10,0,0); repeat(3) tap(p,8'h10); count_pulses(p,3,12);
                    osd=1; check_read(p,8'hff);
                    osd=0; buttons(p,0,0,0); check_read(p,8'hff);
                end
            end
        end
        set_mode(0); valid=0;
        usb1=8'h10; usb2=8'h20;
        check_read(1,8'hf7); check_read(2,8'hfb);
        $display("PASS Pang: actual USER I/O mux to Z80, 7 modes, two-player routing, shared coin, native USB, quiz uses four answers independently, auxiliary Hold, Start x3 on/off, OSD and release");
        $finish;
    end
endmodule
