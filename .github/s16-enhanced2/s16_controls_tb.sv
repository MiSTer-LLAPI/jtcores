// Check the arcade cabinet registers after LLAPI maps game actions.
module s16_controls_tb;
    reg clk=0, rst=1, io_selected=0, hblank=1;
    always #5 clk=~clk;
    reg [7:0] game_id=0;
    reg [2:1] offset=0;
    wire [23:1] address={10'd0,2'd1,9'd0,offset};
    reg [31:0] buttons1=0,buttons2=0;
    wire [15:0] mapped1,mapped2;
    wire [3:0] start,coin;
    reg [8:0] usb3=9'h1ff,usb4=9'h1ff;
    reg [15:0] left1=0,right1=0;
    jtframe_llapi_arcade_map #(.BUTTONS(5)) pad(
        .buttons1(buttons1),.buttons2(buttons2),.valid1(1'b1),.valid2(1'b1),
        .saturn1(1'b0),.saturn2(1'b0),.osd_active(1'b0),
        .usb1(16'd0),.usb2(16'd0),.joy1(mapped1),.joy2(mapped2),.start(start),.coin(coin));
    jts16_main cabinet(
        .rst(rst),.clk(clk),.game_id(game_id),.LHBL(hblank),
        .joystick1(~mapped1[8:0]),.joystick2(~mapped2[8:0]),.joystick3(usb3),.joystick4(usb4),
        .joyana1(left1),.joyana1b(right1),.joyana2(16'd0),.joyana2b(16'd0),
        .joyana3(16'd0),.joyana4(16'd0),.cab_1p({2'b11,~start[1:0]}),
        .coin({2'b11,~coin[1:0]}),.service(1'b1),.dip_test(1'b1),.dipsw_c(8'h6a));
    task read_port(input [1:0] portnum,input [7:0] expected,input [7:0] mask);
        begin
            io_selected=0;@(negedge clk);
            offset=portnum;io_selected=1;repeat(2) @(negedge clk);
            if((cabinet.cab_dout & mask)!==(expected & mask))
                $fatal(1,"game %h port %d received %h expected %h mask %h",game_id,portnum,cabinet.cab_dout,expected,mask);
        end
    endtask
    integer i;
    reg [7:0] button_mask;
    initial begin
        force cabinet.A=address;
        force cabinet.io_cs=io_selected;
        repeat(3) @(negedge clk);rst=0;
        // Shared digital scheme for Shinobi, Fantasy Zone and other standard cabinets.
        for(i=0;i<4;i=i+1) begin
            case(i)
                0: button_mask=8'h02;
                1: button_mask=8'h04;
                2: button_mask=8'h01;
                3: button_mask=8'h08;
            endcase
            buttons1=1<<i;buttons2=0;read_port(1,~button_mask,8'hff);read_port(3,8'hff,8'hff);
            buttons1=0;buttons2=1<<i;read_port(1,8'hff,8'hff);read_port(3,~button_mask,8'hff);
        end
        buttons1=1<<5;buttons2=1<<4;read_port(0,8'hed,8'hff);
        buttons1=0;buttons2=0;read_port(0,8'hff,8'hff);
        // Quartet's third and fourth cabinet players still come from their own inputs.
        game_id=8'h04;usb3=9'h1ef;usb4=9'h1df;
        read_port(2,8'hdf,8'hff);read_port(3,8'hef,8'hff);
        // Passing Shot's official System 16A MRA supplies board ID 02.
        game_id=8'h02;buttons1=1;buttons2=2;usb3=9'h1bf;usb4=9'h17f;
        read_port(0,8'hff,8'hff);
        read_port(1,8'hef,8'hff);read_port(1,8'hdf,8'hff);
        read_port(1,8'hbf,8'hff);read_port(1,8'h7f,8'hff);
        // The Action Fighter analog variants use the top four action bits and analog pedal.
        game_id=8'h1d;buttons1=8;left1=16'h8080;read_port(1,8'h7b,8'hff);
        buttons1=0;left1=16'hc000;read_port(1,8'hfd,8'hff);
        // SDI uses its right analog stick and independent fire input for each player.
        game_id=8'h19;buttons1=1;buttons2=0;
        read_port(0,8'hbf,8'hc0);
        right1=16'h0010;hblank=1;repeat(3) @(negedge clk);
        hblank=0;repeat(3) @(negedge clk);
        if(cabinet.trackball0!==12'h108) $fatal(1,"SDI trackball did not follow right stick");
        game_id=8'h1c;read_port(2,8'h6a,8'hff);
        $display("PASS System 16A cabinet on both LLAPI players, Quartet, Passing Shot four-player scan, Action Fighter analog, SDI trackball and Time Scanner DIP.");
        $finish;
    end
endmodule
