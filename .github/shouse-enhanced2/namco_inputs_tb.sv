// Drive cabinet reads on the production MCU bus. Each read advances its hardware strobe.
module namco_inputs_tb;
    reg clk=0, rstn=0, vma=0;
    reg [15:0] address=0;
    wire [1:0] io_mode;
    reg [7:0] header=0;
    reg write_header=0;
    reg [1:0] dial1=0, dial2=0;
    reg [31:0] p1=0,p2=0;
    reg [9:0] native3=0,native4=0;
    reg [1:0] native_coin=0;
    reg saturn=0;
    wire [15:0] j1,j2;
    wire [3:0] start,coin;
    always #5 clk=~clk;
    jtframe_llapi_arcade_map #(.BUTTONS(6)) map(
        .buttons1(p1),.buttons2(p2),.valid1(1'b1),.valid2(1'b1),
        .saturn1(saturn),.saturn2(saturn),.osd_active(1'b0),
        .usb1(16'b0),.usb2(16'b0),.joy1(j1),.joy2(j2),.start(start),.coin(coin));
    wire [9:0] cabinet1,cabinet2,cabinet3,cabinet4;
    wire [3:0] cabinet_start,cabinet_coin;
    jtframe_merge_keyjoy merge(.clk(clk),.rst(~rstn),.board_start(start),.board_coin(coin),
        .joy_start(4'd0),.joy_coin({native_coin,2'b0}),.key_start(4'd0),.key_coin(4'd0),
        .joy1(j1),.joy2(j2),.joy3({6'd0,native3}),.joy4({6'd0,native4}),
        .key_joy1(10'd0),.key_joy2(10'd0),.key_joy3(10'd0),.key_joy4(10'd0),
        .mouse_but_1p(3'd0),.mouse_but_2p(3'd0),
        .game_joy1(cabinet1),.game_joy2(cabinet2),.game_joy3(cabinet3),.game_joy4(cabinet4),
        .game_coin(cabinet_coin),.game_start(cabinet_start));
    jtshouse_key cartridge(.clk(clk),.rst(~rstn),.cs(1'b0),.rnw(1'b1),.addr(8'd0),.din(8'd0),
        .prog_en(write_header),.prog_wr(write_header),.prog_addr(3'd0),.prog_data(header),.io_mode(io_mode));
    jtshouse_mcu game(.clk(clk),.game_rst(~rstn),.rstn(rstn),.cen(1'b1),.pxl_cen(1'b1),.lvbl(1'b1),
        .io_mode(io_mode),.cab_1p(cabinet_start[1:0]),.coin(cabinet_coin),
        .joystick1(cabinet1),.joystick2(cabinet2),.joystick3(cabinet3),.joystick4(cabinet4),
        .dial1(dial1),.dial2(dial2),.service(1'b1),.dip_test(1'b1),.dipsw(8'hff));

    task tick; begin @(posedge clk);@(negedge clk);end endtask
    task reset_mode(input [1:0] m);
        begin header={2'd0,m,4'd0};write_header=1;rstn=0;vma=0;address=0;dial1=0;dial2=0;repeat(3)tick;
            write_header=0;rstn=1;repeat(2)tick;
            if(io_mode!==m) $fatal(1,"wrong cabinet selected by cartridge header");end
    endtask
    task read_cab(input odd_addr, output [7:0] data);
        begin tick;address={15'h0a00,odd_addr};vma=1;tick;data=game.mcu_din;
            vma=0;address=0;tick;end
    endtask
    task expect_read(input odd_addr,input [7:0] expected);
        reg [7:0] actual;
        begin read_cab(odd_addr,actual);
            if(actual!==expected) $fatal(1,"mode=%d odd=%d got %h expected %h",io_mode,odd_addr,actual,expected);
        end
    endtask
    function automatic [31:0] report(input [5:0] actions,input is_saturn);
        reg [31:0] result;
        begin result=0;result[3:0]=actions[3:0];
            if(is_saturn) result[9:8]=actions[5:4];else result[7:6]=actions[5:4];
            report=result;end
    endfunction
    function automatic [7:0] pressure(input [2:0] pressed);
        begin pressure=pressed[0] ? 8'h7f : pressed[1] ? 8'h48 : pressed[2] ? 8'h40 : 0;end
    endfunction
    reg [7:0] dummy;
    reg [5:0] act1,act2;
    integer group,n;
    task check_beraboh;
        begin
            reset_mode(2);
            for(group=0;group<4;group=group+1) begin
                for(n=0;n<64;n=n+1) begin
                    act1=n;act2=(n*13+17)&63;
                    p1=report(act1,saturn);p2=report(act2,saturn);
                    case(group)
                        0: expect_read(0,pressure(act1[2:0]));
                        1: expect_read(0,pressure(act1[5:3]));
                        2: expect_read(0,pressure(act2[2:0]));
                        3: expect_read(0,pressure(act2[5:3]));
                    endcase
                    if(start!=0 || coin!=0) $fatal(1,"Pressure action reached Start/Coin");
                end
                repeat(8) read_cab(1,dummy);
            end
            p1=32'h03000020;p2=32'h0c000000;expect_read(0,8'h0c);expect_read(1,8'h83);
            p1=0;p2=0;
        end
    endtask
    // Each physical dial follows its own Gray-code sequence; alternating directions check both wraparounds.
    function automatic [1:0] phase(input integer pos);
        case(pos & 3) 0:phase=0;1:phase=2;2:phase=3;3:phase=1;endcase
    endfunction
    integer count1,count2,step1,step2;
    reg [1:0] strobe;
    task check_dial(input odd_addr);
        reg [7:0] count;
        reg [7:0] expected;
        begin count=strobe[0] ? count2 : count1;
            if(odd_addr) expected={~start[1],1'b0,strobe[0],~j2[4],count[7:4]};
            else expected={~start[0],strobe[1],1'b0,~j1[4],count[3:0]};
            expect_read(odd_addr,expected);
            if(!odd_addr) strobe[1]=~strobe[1];
            else if(!strobe[1]) strobe[0]=~strobe[0];
        end
    endtask
    task check_quester;
        begin reset_mode(3);count1=0;count2=0;strobe=0;
            for(n=0;n<540;n=n+1) begin
                step1=n<270 ? 1 : -1;
                step2=n%5==0 ? 0 : n<320 ? -1 : 1;
                count1=count1+step1;count2=count2+step2;
                dial1=phase(count1);dial2=phase(count2);tick;
                p1=n[0] ? 1 : 32'h20; p2=n[1] ? 32'h20 : 1;#1;
                repeat(4) begin check_dial(0);check_dial(1);end
            end
            // A simultaneous two-contact change is not a valid step.
            dial1=~dial1;dial2=~dial2;tick;
            repeat(4) begin check_dial(0);check_dial(1);end
            p1=0;p2=0;
        end
    endtask
    task check_faceoff;
        reg [5:0] l1,l2;
        begin reset_mode(1);l1=6'h1f;l2=6'h1f;
            for(n=0;n<128;n=n+1) begin
                if(n%8==0) begin
                    p1=32'h01000001^(n<<23);p2=32'h08000000^(n<<22);
                    native3=(n*7+5)&31;native4=(n*9+3)&31;
                    native_coin=n>>3;
                end
                expect_read(0,{~native_coin[0],1'b0,l1});
                if((n&7)==7) begin
                    expect_read(1,{~native_coin[1],4'h0,n[5:3]});
                    case(n[5:3])
                        0: begin l1={1'b0,~j1[4:0]};l2={~native4[2:0],3'd0};end
                        3: l1={1'b0,~j2[4:0]};
                        4: begin l1={1'b0,~native3[4:0]};l2={1'b0,~native4[4:3],3'd0};end
                        default: begin l1=6'h1f;l2=6'h1f;end
                    endcase
                end else expect_read(1,{~native_coin[1],1'b1,l2});
            end
        end
    endtask
    initial begin
        force game.A=address;force game.vma=vma;force game.wr=0;
        reset_mode(0);p1=32'h05000001;p2=32'h0a000022;expect_read(0,8'hea);expect_read(1,8'h55);
        p1=0;p2=0;saturn=0;check_beraboh;saturn=1;check_beraboh;
        saturn=0;check_quester;check_faceoff;
        $display("PASS Namco MCU cabinet bus: Beraboh Man 512 pressure combinations, independent P1/P2, Quester dual quadrature with wrap/reversals, Face Off four-player latches and P3/P4 credits.");
        $finish;
    end
endmodule
