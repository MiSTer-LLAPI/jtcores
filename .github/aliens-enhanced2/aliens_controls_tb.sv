// Read the game's CPU I/O addresses with the real serial mux, native four-player
// merge and Konami direction order. Only controller samples and CPU bus are driven.
module aliens_controls_tb;
    reg clk=0, rst=1, vb=0;
    reg [2:0] mode=0, header=0;
    reg [31:0] report1=0,report2=0;
    reg [8:0] pad1=0,pad2=0;
    reg [15:0] native3=0,native4=0,usb1=0,usb2=0;
    reg [3:0] native_start=0,native_coin=0;
    reg service=0, valid1=1,valid2=1;
    reg [15:0] addr=0;
    wire [15:0] j1,j2;
    wire [3:0] serial_start,serial_coin,starts,coins;
    wire [9:0] raw1,raw2,raw3,raw4,game1,game2,game3,game4;
    wire game_service,menu;
    always #5 clk=~clk;

    jtframe_serial_arcade #(.BUTTONS(`JTFRAME_BUTTONS)) serial(
        .clk_50(clk),.clk_sys(clk),.rst(rst),.vblank(vb),.osd_active(1'b0),
        .repoll_off(1'b0),.mode(mode),.usb1(usb1),.usb2(usb2),.user_in(7'h7f),
        .info_clk(clk),.autofire_enable(1'b0),.autofire_enable2(1'b0),
        .autofire_toggle(1'b0),.autofire_toggle2(1'b0),.autofire_rate1(2'd0),
        .autofire_rate2(2'd0),.loss_resume(1'b0),
        .joy1(j1),.joy2(j2),.start(serial_start),.coin(serial_coin),.osd_request(menu));
    jtframe_merge_keyjoy merge(.clk(clk),.rst(rst),.board_start(serial_start),.board_coin(serial_coin),
        .joy_start(native_start),.joy_coin(native_coin),.key_start(4'd0),.key_coin(4'd0),
        .joy1(j1),.joy2(j2),.joy3(native3),.joy4(native4),
        .key_joy1(10'd0),.key_joy2(10'd0),.key_joy3(10'd0),.key_joy4(10'd0),
        .mouse_but_1p(3'd0),.mouse_but_2p(3'd0),.key_service(service),.joy_service(1'b0),
        .game_service(game_service),.game_joy1(raw1),.game_joy2(raw2),.game_joy3(raw3),
        .game_joy4(raw4),.game_coin(coins),.game_start(starts));
    jtframe_joy_reorder reorder(.raw1(raw1),.raw2(raw2),.raw3(raw3),.raw4(raw4),
        .joy1(game1),.joy2(game2),.joy3(game3),.joy4(game4));
    reg header_write=0;
    jtaliens_game game(.clk(clk),.rst(rst),.prog_addr(22'd1),.prog_data({5'd0,header}),
        .prog_we(header_write),.header(header_write),.dip_pause(1'b1),
        .joystick1(game1[6:0]),.joystick2(game2[6:0]),.joystick3(game3[6:0]),.joystick4(game4[6:0]),
        .cab_1p(starts),.coin(coins),.service(game_service),.dipsw(32'h000ab53c),.debug_bus(8'd0));

    task settle; repeat(7) @(negedge clk);endtask
    task frame; begin vb=1;settle;vb=0;settle;end endtask
    task read_port(input [15:0] address,input [7:0] expected);
        begin addr=address;settle;
            if(game.u_main.io_cs!==1 || game.u_main.cpu_din!==expected)
                $fatal(1,"cfg %h mode %d addr %h not selected or got %h expected %h",
                       header,mode,addr,game.u_main.cpu_din,expected);
        end
    endtask
    function automatic [6:0] cabinet(input [6:0] j);
        cabinet=~{j[6:4],j[2],j[3],j[0],j[1]};
    endfunction
    function automatic [31:0] report(input [6:0] j);
        reg [31:0] value;
        begin value=0;value[27:24]=j[3:0];value[2:0]=j[6:4];report=value;end
    endfunction
    task check_pads(input [6:0] one,two,three,four,input [3:0] start_pressed,coin_pressed);
        reg [6:0] a,b,c,d;
        begin
            a=cabinet(one);b=cabinet(two);c=cabinet(three);d=cabinet(four);
            case(header)
                0: begin // Aliens, with Start and Coin in the same port as the player
                    read_port(16'h5f81,{~start_pressed[0],~coin_pressed[0],a[5:0]});
                    read_port(16'h5f82,{~start_pressed[1],~coin_pressed[1],b[5:0]});
                    read_port(16'h5f80,{3'b111,~service,4'ha});
                end
                6: begin // Crime Fighters, independent cabinet registers for P1-P4
                    read_port(16'h3f81,{~start_pressed[0],a});read_port(16'h3f82,{~start_pressed[1],b});
                    read_port(16'h3f85,{~start_pressed[2],c});read_port(16'h3f86,{~start_pressed[3],d});
                    read_port(16'h3f80,{3'b111,~service,~coin_pressed});
                end
                default: begin // Super Contra, Thunder Cross and Gang Busters
                    read_port(16'h1f91,{2'b11,a[5:0]});read_port(16'h1f92,{2'b11,b[5:0]});
                    read_port(16'h1f93,{2'b11,a[6],b[6],4'ha});
                    read_port(16'h1f90,{3'b111,~start_pressed[1:0],~service,~coin_pressed[1:0]});
                end
            endcase
        end
    endtask
    task tap(input integer player);
        begin
            if(player==1) pad1[7]=1; else pad2[7]=1;
            repeat(3) frame;
            if(serial_start!=0 || menu) $fatal(1,"gesture reached cabinet Start or menu");
            if(player==1) pad1[7]=0; else pad2[7]=0;repeat(3) frame;
        end
    endtask
    task pulse(input integer player,bit_index,expected);
        integer n, hits;
        reg [6:0] local1,local2;
        begin hits=0;
            for(n=0;n<12;n=n+1) begin
                frame;local1=j1[6:0];local2=j2[6:0];
                hits=hits+(player==1 ? local1[bit_index] : local2[bit_index]);
                check_pads(local1,local2,0,0,0,0);
            end
            if(hits!==expected) $fatal(1,"SNAC mode %d player %d bit %d saw %d/12 expected %d",
                                       mode,player,bit_index,hits,expected);
        end
    endtask
    integer i,layout,action,p,m,maxplayers;
    reg [6:0] one,two;
    reg [3:0] startmask,coinmask;
    reg shortcut;
    initial begin
        force serial.port1=pad1;force serial.port2=pad2;
        force serial.u_llapi.valid1_sync=valid1;force serial.u_llapi.valid2_sync=valid2;
        force serial.u_llapi.buttons1_sync=report1;force serial.u_llapi.buttons2_sync=report2;
        force serial.u_llapi.saturn1_sync=0;force serial.u_llapi.saturn2_sync=0;
        force game.u_main.A=addr;force game.u_main.Aupper=8'h80;force game.u_main.cpu_we=0;
        force game.rst8=0;
        settle;rst=0;repeat(7600) @(negedge clk);
        for(layout=0;layout<5;layout=layout+1) begin
            case(layout) 0:header=0;1:header=2;2:header=4;3:header=5;4:header=6;endcase
            header_write=1;settle;header_write=0;
            if({game.game_id,game.gx878}!==header) $fatal(1,"Cartridge header decode");
            for(i=0;i<128;i=i+1) begin
                one=i;two=(i*29+19)&127; native3=(i*5+3)&127;native4=(i*9+33)&127;
                startmask=(i*3)&15;coinmask=(i*7+1)&15;service=i[6];
                report1=report(one);report2=report(two);
                report1[5]=startmask[0];report2[6]=startmask[1];
                report1[4]=coinmask[0];report2[4]=coinmask[1];
                native_start={startmask[3:2],2'b00};native_coin={coinmask[3:2],2'b00};
                shortcut=one[2] && startmask[0] && one[4];
                settle;
                if(menu!==shortcut) $fatal(1,"LLAPI OSD shortcut");
                if(shortcut)
                    check_pads(0,0,native3[6:0],native4[6:0],native_start,native_coin);
                else
                    check_pads(one,two,native3[6:0],native4[6:0],startmask,coinmask);
            end
        end
        header=6;native_start=0;native_coin=0;native3=0;native4=0;service=0;
        report1=0;report2=0;valid1=0;valid2=0;usb1=16'h13;usb2=16'h61;
        check_pads(7'h13,7'h61,0,0,0,0);usb1=0;usb2=0;
        for(m=1;m<=6;m=m+1) begin
            mode=m;repeat(7600) @(negedge clk);
            maxplayers=(m==3 || m==4 || m==6)?2:1;
            for(p=1;p<=maxplayers;p=p+1) begin
                if(p==1) pad1=9'h80;else pad2=9'h80;
                check_pads(0,0,0,0,1<<(p-1),0);
                if(p==1) pad1=9'h100;else pad2=9'h100;
                check_pads(0,0,0,0,0,1<<(p-1));pad1=0;pad2=0;settle;
                for(action=4;action<=(m>=5 ? 5 : 6);action=action+1) begin
                    if(p==1) pad1=1<<action;else pad2=1<<action;
                    settle;pulse(p,action,12);tap(p);tap(p);pulse(p,action,12);
                    tap(p);pulse(p,action,6);
                    pad1=0;pad2=0;settle;pulse(p,action,0);
                    if(p==1) pad1=1<<action;else pad2=1<<action;
                    settle;tap(p);tap(p);tap(p);pulse(p,action,12);
                    pad1=0;pad2=0;settle;
                end
            end
        end
        $display("PASS Konami Aliens: five cartridge configurations, 640 simultaneous direction/action/Start/Coin cases, P3/P4 registers and independent coins, USB fallback, six SNAC modes, each available action and player, triple Start on/off.");
        $finish;
    end
endmodule
