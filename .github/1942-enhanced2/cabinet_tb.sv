// Drive the original PCB header decoder and its CPU-visible cabinet registers.
module capcom_controls_tb;
    reg sys=0,romclk=0,reset=1,write_en=0,rom_select=0,frame=0;
    reg [2:0] mode=0;
    reg [8:0] pad1=0,pad2=0;
    reg [25:0] download_address=0;
    reg [7:0] data=0;
    reg [15:0] cpu_address=16'hc000;
    reg [31:0] dips=32'h000053a6;
    wire [15:0] joy1,joy2;
    wire [3:0] start,coin;
    wire single_action,menu;
    always #5 sys=~sys;
    always #7 romclk=~romclk;
    jt1942_snac_profile profile(.clk_rom(romclk),.clk_sys(sys),.rom_write(write_en && rom_select),
        .first_byte(download_address==0),.header_data(data),.one_action(single_action));
    jtframe_serial_arcade #(.BUTTONS(2)) serial(
        .clk_50(sys),.clk_sys(sys),.rst(reset),.vblank(frame),.osd_active(1'b0),
        .repoll_off(1'b0),.mode(mode),.one_action(single_action),.info_clk(sys),
        .user_in(7'h7f),.usb1(16'd0),.usb2(16'd0),.loss_resume(1'b0),
        .autofire_enable(1'b0),.autofire_enable2(1'b0),.autofire_toggle(1'b0),.autofire_toggle2(1'b0),
        .autofire_rate1(2'd0),.autofire_rate2(2'd0),.joy1(joy1),.joy2(joy2),
        .start(start),.coin(coin),.osd_request(menu));
    // No special joystick reorder is selected by this family. The cabinet takes active-low inputs.
    jt1942_game pcb(.clk(romclk),.rst(reset),.cen3(1'b1),.cen6(1'b1),
        .header(rom_select && download_address<4),.prog_we(write_en),.prog_data(data),
        .ioctl_addr(download_address),.joystick1(~joy1[5:0]),.joystick2(~joy2[5:0]),
        .cab_1p(~start),.coin(~coin),.dip_pause(1'b1),.service(1'b1),.dipsw(dips));
    task settle; repeat(8) @(negedge sys); endtask
    task next_frame; begin frame=1; settle; frame=0; settle; end endtask
    task put_byte(input [25:0] addr, input [7:0] value, input is_game);
        begin
            @(negedge romclk); download_address=addr;data=value;rom_select=is_game;write_en=1;
            @(negedge romclk); write_en=0;rom_select=0;settle;
        end
    endtask
    task load_game(input [1:0] board, input flipped);
        begin
            put_byte(0,{6'd0,board},1); put_byte(1,{7'd0,flipped},1);
            put_byte(2,0,1);put_byte(3,0,1);put_byte(4,2,1);put_byte(0,2,0);
            if(pcb.game_id!==board || single_action!==(board==2) || pcb.flip_xor!==flipped)
                $fatal(1,"PCB header %0d game=%d action_mask=%b xor=%b",board,pcb.game_id,single_action,pcb.flip_xor);
            reset=1; settle; reset=0; repeat(8000) @(negedge sys);
            if(single_action!==(board==2)) $fatal(1,"soft reset lost PCB selection");
        end
    endtask
    task cabinet(input [2:0] addr, input [7:0] expected);
        begin
            cpu_address=16'hc000+addr; settle;
            if(pcb.u_main.in_cs!==1 || pcb.u_main.cpu_din!==expected)
                $fatal(1,"board %d register %x expected %x got %x",pcb.game_id,addr,expected,pcb.u_main.cpu_din);
        end
    endtask
    task tap(input integer player, input expected_reserved);
        begin
            if(player==1) pad1[7]=1; else pad2[7]=1;
            repeat(3) next_frame;
            if(start[player-1]!==!expected_reserved || menu) $fatal(1,"reserved Start incorrect");
            if(player==1) pad1[7]=0; else pad2[7]=0;
            repeat(3) next_frame;
        end
    endtask
    task check_turbo(input mask_b,input [1:0] board);
        integer i,active;
        begin
            if(mask_b) pad1=9'h20;else pad1=9'h10;settle;
            repeat(3) tap(1,!(mask_b && board==2));
            active=0; for(i=0;i<12;i=i+1)begin
                next_frame;active=active+joy1[mask_b?5:4];
            end
            if(active!==(mask_b && board==2 ? 0:6))$fatal(1,"per-PCB turbo mask or rate");
            if(!(mask_b && board==2)) begin
                repeat(3) tap(1,1);
                for(i=0;i<8;i=i+1)begin next_frame;if(!joy1[mask_b?5:4])$fatal(1,"turbo removal");end
            end
            pad1=0;settle;if(joy1!==0)$fatal(1,"release");
        end
    endtask
    task run_board(input [1:0] board,input flip_xor);
        begin
            load_game(board,flip_xor);
            if(pcb.eff_flip!==flip_xor)$fatal(1,"primary flip");
            dips[16]=1;settle;
            if(pcb.eff_flip!==(flip_xor^(board==1)))$fatal(1,"Vulgus-only flip DIP");
            dips[16]=0;
            // Independent P1/P2 directions and actions across the two actual PCB maps.
            pad1=9'h11;pad2=9'h22;settle;
            if(board==2)begin
                cabinet(0,8'hfe);cabinet(1,8'hfc);cabinet(2,8'hf7);
                pad1=0;pad2=9'h10;settle;cabinet(2,8'hfd);
            end else begin
                cabinet(1,8'hee);cabinet(2,8'hdd);
            end
            pad1=9'h100;pad2=9'h080;settle;
            if(board==2) cabinet(2,8'h6f); else cabinet(0,8'h7d);
            pad1=0;pad2=0;settle;
            cabinet(3,8'ha6);cabinet(4,8'h53);
            check_turbo(0,board);check_turbo(1,board);
        end
    endtask
    initial begin
        force serial.port1=pad1;force serial.port2=pad2;
        force pcb.u_main.A=cpu_address;
        force pcb.u_main.rfsh_n=1'b1;force pcb.u_main.mreq_n=1'b0;force pcb.u_main.irq_ack=1'b0;
        force pcb.flip=1'b0;
        mode=4;settle;
        run_board(0,0); run_board(1,0);run_board(2,1);run_board(1,1);run_board(0,0);
        $display("PASS 1942, Vulgus, flipped Vulgus set 2 and Higemaru: game headers, controls on both ports, action masks, Start/Coin, flip DIP, per-button turbo on/off and reload");
        $finish;
    end
endmodule
