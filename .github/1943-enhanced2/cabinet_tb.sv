// Read the same active-low cabinet registers as the 1943 program.
module controls1943_tb;
    reg clk=0, rst=1, frame=0;
    reg [2:0] mode=0;
    reg [31:0] buttons1=0,buttons2=0;
    reg [8:0] pad1=0,pad2=0;
    reg [15:0] address=16'hc000;
    wire [15:0] joy1,joy2;
    wire [3:0] start,coin;
    always #5 clk=~clk;
    jtframe_serial_arcade #(.BUTTONS(3)) serial(
        .clk_50(clk),.clk_sys(clk),.info_clk(clk),.rst(rst),.vblank(frame),.osd_active(1'b0),
        .mode(mode),.user_in(7'h7f),.usb1(16'd0),.usb2(16'd0),.repoll_off(1'b0),.loss_resume(1'b0),
        .autofire_enable(1'b0),.autofire_enable2(1'b0),.autofire_toggle(1'b0),.autofire_toggle2(1'b0),
        .autofire_rate1(2'd0),.autofire_rate2(2'd0),.joy1(joy1),.joy2(joy2),.start(start),.coin(coin));
    jt1943_main pcb(.clk(clk),.rst(rst),.cpu_cen(1'b1),.LVBL(1'b0),
        .joystick1(~joy1[6:0]),.joystick2(~joy2[6:0]),.cab_1p(~start[1:0]),.coin(~coin[1:0]),
        .service(1'b1),.dipsw_a(8'hf8),.dipsw_b(8'hff));
    task wait_sync; repeat(8) @(negedge clk); endtask
    task next_frame; begin frame=1;wait_sync;frame=0;wait_sync;end endtask
    task read_port(input [2:0] port,input [7:0] expected);
        begin
            address=16'hc000+port;wait_sync;
            if(pcb.in_cs!==1 || pcb.cpu_din!==expected)
                $fatal(1,"mode %d cabinet register %x expected %x got %x",mode,address,expected,pcb.cpu_din);
        end
    endtask
    task tap;
        begin
            pad1[7]=1;repeat(3) next_frame;read_port(0,8'hff);
            pad1[7]=0;repeat(3) next_frame;
        end
    endtask
    integer i,active;
    initial begin
        force serial.u_llapi.valid1_sync=1;force serial.u_llapi.valid2_sync=1;
        force serial.u_llapi.buttons1_sync=buttons1;force serial.u_llapi.buttons2_sync=buttons2;
        force serial.llapi_type_changed=0;
        force serial.port1=pad1;force serial.port2=pad2;
        force pcb.A=address;force pcb.rfsh_n=1;force pcb.mreq_n=0;force pcb.rd_n=0;
        wait_sync;rst=0;repeat(8000) @(negedge clk);
        read_port(0,8'hff);read_port(1,8'hff);read_port(2,8'hff);
        // Gamer-Pro directional bits 24..27, first two action bits and the legacy combined action.
        buttons1=32'h01000001;buttons2=32'h02000002;
        read_port(1,8'hee);read_port(2,8'hdd);
        buttons1=4;buttons2=0;read_port(1,8'h8f);read_port(2,8'hff);
        buttons1=16;buttons2=64;read_port(0,8'hbd);
        buttons1=0;buttons2=0;read_port(0,8'hff);read_port(3,8'hf8);read_port(4,8'hff);
        mode=4;repeat(8000) @(negedge clk);
        pad1=9'h10;pad2=9'h20;read_port(1,8'hef);read_port(2,8'hdf);
        repeat(3) tap;
        active=0;address=16'hc001;for(i=0;i<12;i=i+1) begin next_frame; active=active+(!pcb.cpu_din[4]);end
        if(active!=6) $fatal(1,"SNAC A triple-Start failed");
        read_port(2,8'hdf);
        pad1=0;read_port(1,8'hff);pad1=9'h10;wait_sync;repeat(3) tap;
        for(i=0;i<12;i=i+1) begin next_frame;read_port(1,8'hef);end
        pad1=9'h40;pad2=9'h40;read_port(1,8'h8f);read_port(2,8'h8f);
        pad1=0;pad2=0;read_port(1,8'hff);read_port(2,8'hff);
        $display("PASS 1943 original cabinet: two players, shoot, bomb, combined loop, Start/Coin/DIP, SNAC turbo on/off and release.");
        $finish;
    end
endmodule
