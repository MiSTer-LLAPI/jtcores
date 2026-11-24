// The physical report goes through the upstream merge, rotation and RLDU reordering before the 65C02.
module seta_controls_tb;
    reg clk=0,rst=1,frame=0,rotate=0,flipped=0,header=0,wr=0;
    reg [2:0] mode=0;
    reg [8:0] pad1=0,pad2=0;
    reg [31:0] buttons1=0,buttons2=0;
    reg [7:0] data=0;
    reg [21:0] prog_addr=0;
    reg [15:0] sub_addr=0;
    reg [23:1] main_addr=0;
    wire [15:0] joy1,joy2;
    wire [3:0] start,coin,game_start,game_coin;
    wire [9:0] game1,game2;
    wire service,tilt;
    always #5 clk=~clk;
    jtframe_serial_arcade #(.BUTTONS(2)) serial(
        .clk_50(clk),.clk_sys(clk),.info_clk(clk),.rst(rst),.vblank(frame),.osd_active(1'b0),
        .mode(mode),.user_in(7'h7f),.usb1(16'd0),.usb2(16'd0),.repoll_off(1'b0),.loss_resume(1'b0),
        .autofire_enable(1'b0),.autofire_enable2(1'b0),.autofire_toggle(1'b0),.autofire_toggle2(1'b0),
        .autofire_rate1(2'd0),.autofire_rate2(2'd0),.joy1(joy1),.joy2(joy2),.start(start),.coin(coin));
    jtframe_joysticks route(.clk(clk),.rst(rst),.vs(frame),.locked(1'b0),.rot(rotate),.rot_ccw(1'b1),
        .joy1_pos(2'd0),.board_joy1(joy1),.board_joy2(joy2),.board_joy3(16'd0),.board_joy4(16'd0),
        .ana1(16'd0),.ana2(16'd0),.board_coin(coin),.board_start(start),.joy_coin(4'd0),.joy_start(4'd0),
        .key_coin(4'd0),.key_start(4'd0),.key_service(1'b0),.joy_service(1'b0),.key_tilt(1'b0),
        .key_reset(1'b0),.cab_active(1'b0),.cab_inputs(21'd0),.key_joy1(10'd0),.key_joy2(10'd0),
        .key_joy3(10'd0),.key_joy4(10'd0),.joy_test(1'b0),.key_test(1'b0),.mouse_but_1p(3'd0),
        .mouse_but_2p(3'd0),.game_joy1(game1),.game_joy2(game2),.game_coin(game_coin),
        .game_start(game_start),.game_service(service),.game_tilt(tilt));
    jtarblst_game game(.clk(clk),.rst(rst),.cen8(1'b1),.prog_we(wr),.prog_addr(prog_addr),
        .header(header),.prog_data(data),.joystick1(game1[5:0]),.joystick2(game2[5:0]),.cab_1p(game_start),
        .coin(game_coin),.service(service),.tilt(tilt));
    task settle; repeat(16) @(negedge clk); endtask
    task next_frame;begin frame=1;settle;frame=0;settle;end endtask
    task set_game(input board);
        begin
            @(negedge clk);prog_addr=0;data=board;wr=1;header=1;
            @(negedge clk);prog_addr=1;data=~board;
            @(negedge clk);wr=0;header=0;settle;
            if(game.game_id!==board) $fatal(1,"game header");
            flipped=1;settle;if(game.thoffs!==(board ? 16'h1f:16'h1d)) $fatal(1,"normal tile origin");
            flipped=0;settle;if(game.thoffs!==(board ? 16'h1e2:16'h1e0)) $fatal(1,"flipped tile origin");
        end
    endtask
    task read_sub(input [15:0] addr,input [7:0] expected);
        begin
            sub_addr=addr;settle;
            if(game.u_sub.in_cs!==1 || game.u_sub.cpu_din!==expected)
                $fatal(1,"board %d sub %x expected %x got %x",game.game_id,addr,expected,game.u_sub.cpu_din);
        end
    endtask
    task read_main(input [23:0] addr,input [15:0] expected);
        begin
            main_addr=addr[23:1];settle;
            if(game.u_main.cpu_din!==expected) $fatal(1,"board %d main %x expected %x got %x",game.game_id,addr,expected,game.u_main.cpu_din);
        end
    endtask
    task tap;
        begin
            pad1[7]=1;repeat(3) next_frame;if(!game_start[0]) $fatal(1,"Start escaped to the sub CPU");
            pad1[7]=0;repeat(3) next_frame;
        end
    endtask
    reg [3:0] expected[0:3];
    integer board,i,active;
    initial begin
        force serial.port1=pad1;force serial.port2=pad2;
        force serial.u_llapi.valid1_sync=1;force serial.u_llapi.valid2_sync=1;
        force serial.u_llapi.buttons1_sync=buttons1;force serial.u_llapi.buttons2_sync=buttons2;
        force serial.llapi_type_changed=0;force game.flip=flipped;
        force game.u_sub.A=sub_addr;force game.u_main.A=main_addr;
        force game.u_main.ASn=0;force game.u_main.LDSn=0;force game.u_main.UDSn=0;force game.u_main.RnW=1;
        settle;rst=0;repeat(8000) @(negedge clk);
        for(board=0;board<2;board=board+1) begin
            set_game(board[0]);
            read_main(24'h21c000,board?16'hffff:16'h003d);
            read_main(24'h21d000,board?16'hffff:16'h0076);
            read_main(24'h21e000,board?16'hffff:16'h0010);
            read_main(24'h21c004,board?16'hffff:16'h003e);
            read_sub(16'h1000,8'hff);read_sub(16'h1004,8'h00);
            mode=0;rotate=0;repeat(8000) @(negedge clk);
            expected[0]=7;expected[1]=11;expected[2]=13;expected[3]=14;
            for(i=0;i<4;i=i+1) begin
                buttons1=(32'h1<<(24+i))|1;buttons2=(32'h1<<(27-i))|2;
                read_sub(16'h1002,{4'he,expected[i]});read_sub(16'h1006,{4'hd,expected[3-i]});
            end
            rotate=1;expected[0]=14;expected[1]=13;expected[2]=7;expected[3]=11;
            for(i=0;i<4;i=i+1) begin
                buttons1=32'h1<<(24+i);buttons2=0;read_sub(16'h1002,{4'hf,expected[i]});
            end
            rotate=0;buttons1=16;buttons2=64;
            read_sub(16'h1000,8'h7f);read_sub(16'h1006,8'h7f);
            buttons1=0;buttons2=0;mode=4;repeat(8000) @(negedge clk);
            pad1=9'h10;pad2=9'h20;read_sub(16'h1002,8'hef);read_sub(16'h1006,8'hdf);
            repeat(3) tap;read_sub(16'h1006,8'hdf);sub_addr=16'h1002;
            active=0;for(i=0;i<12;i=i+1) begin next_frame;active=active+(!game.u_sub.cpu_din[4]);end
            if(active!=6) $fatal(1,"SNAC 65C02 turbo");
            pad1=0;read_sub(16'h1002,8'hff);pad1=9'h10;settle;repeat(3) tap;
            for(i=0;i<12;i=i+1) begin next_frame;read_sub(16'h1002,8'hef);end
            pad1=0;pad2=0;read_sub(16'h1002,8'hff);read_sub(16'h1006,8'hff);
        end
        $display("PASS Meta Fox and Arbalester board headers, protection signatures and tile origins; RLDU and rotated P1/P2 cabinet inputs, coin, start, zero status, turbo on/off and release.");
        $finish;
    end
endmodule
