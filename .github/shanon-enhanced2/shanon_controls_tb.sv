// Exercise the actual Enhanced serial mux, then the cabinet registers read by the game.
// Only the synchronized pad samples and CPU bus transactions are supplied by this bench.
module shanon_controls_tb;
    reg clk=0, reset=1, vblank=0, osd=0, connected=1;
    reg [2:0] mode=0, control=0;
    reg [31:0] buttons=0;
    reg [8:0] pad=0;
    reg [2:0] reserved_actions=0;
    reg [15:0] usb=0, analog1=16'h4070, analog1b=16'hc081;
    reg [23:0] address=0;
    wire [23:1] word_address=address[23:1];
    reg [15:0] write_data=0;
    reg read_bus=1;
    wire [15:0] joy;
    wire [3:0] start, coin;
    wire menu;
    always #5 clk=~clk;
    jtframe_serial_arcade #(.BUTTONS(`JTFRAME_BUTTONS)) serial(
        .clk_50(clk),.clk_sys(clk),.rst(reset),.vblank(vblank),.osd_active(osd),
        .repoll_off(1'b0),.mode(mode),.usb1(usb),.usb2(16'd0),.user_in(7'h7f),
        .info_clk(clk),.autofire_enable(1'b0),.autofire_enable2(1'b0),
        .autofire_toggle(1'b0),.autofire_toggle2(1'b0),.autofire_rate1(2'd0),
        .autofire_rate2(2'd0),.loss_resume(1'b0),
        .joy1(joy),.start(start),.coin(coin),.osd_request(menu));
    jtoutrun_main game(
        .clk(clk),.rst(reset),.joystick1(~joy[7:0]),.joystick2(8'hff),
        .ctrl_type(control),.joyana1(analog1),.joyana1b(analog1b),
        .coin(~coin[1:0]),.cab_1p(~start[1:0]),.gear_toggle(1'b0),
        .gear_show(1'b0),.service(1'b1),.dip_test(1'b1));

    task settle; repeat(8) @(negedge clk); endtask
    task frame; begin vblank=1;settle;vblank=0;settle;end endtask
    task adc(input [1:0] channel,input [7:0] expected);
        begin
            address=0;write_data={8'd0,channel,6'd0};read_bus=0;settle;
            address=24'h3020;settle;read_bus=1;#2;
            if(game.cab_dout!==expected) $fatal(1,"mode %d ADC %d was %h expected %h",control,channel,game.cab_dout,expected);
        end
    endtask
    task cab(input [7:0] mask,input [7:0] expected);
        begin address=24'h1002;read_bus=1;#2;
            if((game.cab_dout & mask)!==expected) $fatal(1,"cabinet got %h mask %h expected %h",game.cab_dout,mask,expected);
        end
    endtask
    task tap;
        begin pad[7]=1;repeat(3) frame;
            if(start[0] || menu) $fatal(1,"shortcut leaked to Start/menu");
            pad[7]=0;repeat(3) frame;
        end
    endtask
    task pulse_count(input integer action, expected);
        integer count;
        begin count=0;
            repeat(12) begin frame;count=count+joy[action];
                // The joystick override uses the analog sample during the off part of a pulse.
                case(action)
                    4: adc(1,joy[4] ? 8'hff : 8'h7e);
                    5: adc(2,joy[5] ? 8'hff : 8'h00);
                    6: cab(8'h20,joy[6] ? 8'h00 : 8'h20);
                endcase
            end
            if(count!==expected) $fatal(1,"SNAC mode %d bit %d active %d/12, expected %d",mode,action,count,expected);
        end
    endtask

    integer m,b,i;
    initial begin
        force game.io_cs=1;force game.A=word_address;force game.RnW=read_bus;
        force game.LDSn=0;force game.cpu_dout=write_data;
        force serial.port1=pad;
        force serial.extra1_sys=reserved_actions;
        force serial.u_llapi.valid1_sync=connected;force serial.u_llapi.valid2_sync=0;
        force serial.u_llapi.buttons1_sync=buttons;force serial.u_llapi.saturn1_sync=0;
        settle;reset=0;repeat(7600) @(negedge clk);
        adc(0,8'h0f);
        buttons=1<<24;adc(0,8'h20);buttons=1<<25;adc(0,8'he0);buttons=0;
        for(i=0;i<256;i=i+1) begin
            analog1[7:0]=i;adc(0,(~i)^8'h80);
        end
        analog1=16'h4070;
        for(i=0;i<3;i=i+1) begin
            control=i;
            adc(1,i==0 ? 8'h7e : 8'h00);adc(2,i==0 ? 0 : i==1 ? 8'h81 : 8'h7e);
            buttons=1;adc(1,8'hff);adc(2,i==0 ? 0 : i==1 ? 8'h81 : 8'h7e);
            buttons=2;adc(2,8'hff);adc(1,i==0 ? 8'h7e : 8'h00);
            buttons=3;adc(1,8'hff);adc(2,8'hff);buttons=0;
        end
        control=0;buttons=4;cab(8'h33,8'h13);buttons=0;cab(8'h33,8'h33);
        buttons=1<<5;cab(8'h33,8'h23);buttons=1<<4;cab(8'h33,8'h32);
        buttons=8;cab(8'h33,8'h33);buttons=0;
        connected=0;usb=16'h10;adc(1,8'hff);usb=0;connected=1;
        for(m=1;m<=6;m=m+1) begin
            mode=m;repeat(7600) @(negedge clk);
            pad=1;adc(0,8'h20);pad=2;adc(0,8'he0);pad=0;adc(0,8'h0f);
            pad='h80;settle;cab(8'h11,1);pad='h100;settle;cab(8'h11,8'h10);
            pad=0;reserved_actions=1;settle;
            repeat(3) begin
                pad[7]=1;repeat(3) frame;cab(8'h31,8'h21);
                pad[7]=0;repeat(3) frame;cab(8'h31,8'h31);
            end
            if(serial.turbo1.programmed!==0) $fatal(1,"Reserved action programmed");
            reserved_actions=0;settle;
            for(b=4;b<=(m>=5 ? 5 : 6);b=b+1) begin
                pad=1<<b;settle;pulse_count(b,12);
                tap;tap;pulse_count(b,12);tap;pulse_count(b,6);
                pad=0;settle;pulse_count(b,0);
                pad=1<<b;settle;tap;tap;tap;pulse_count(b,12);
                pad=0;settle;
            end
        end
        mode=0;repeat(7600) @(negedge clk);pad='h40;settle;cab(8'h20,8'h20);
        $display("PASS Super Hang-On: 256 steering samples, all three analog pedal profiles, three digital actions, Start/Coin, USB fallback, six SNAC modes, per-button turbo on/off and release.");
        $finish;
    end
endmodule
