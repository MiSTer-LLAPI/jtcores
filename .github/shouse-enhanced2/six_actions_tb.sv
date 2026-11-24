module six_actions_tb;
    reg [31:0] p1=0,p2=0;
    reg osd=0;
    wire [15:0] j1,j2;
    wire [3:0] start,coin;
    jtframe_llapi_arcade_map #(.BUTTONS(6)) dut(
        .buttons1(p1),.buttons2(p2),.valid1(1'b1),.valid2(1'b1),
        .saturn1(1'b0),.saturn2(1'b0),.osd_active(osd),
        .usb1(16'b0),.usb2(16'b0),.joy1(j1),.joy2(j2),
        .start(start),.coin(coin),.osd_request());
    initial begin
        for(integer i=0;i<6;i=i+1) begin
            p1=1<<(i<4 ? i : i+2);
            p2=1<<((5-i)<4 ? (5-i) : (7-i));
            #1;
            if(start!==0 || coin!==0) $fatal(1,"Action triggered Start or Coin");
            if(j1!==(16'h10<<i) || j2!==(16'h10<<(5-i))) $fatal(1,"Action collision");
        end
        osd=1;
        #1;
        if(j1!==0 || j2!==0) $fatal(1,"OSD did not mute inputs");
        $display("PASS six independent Namco System 1 LLAPI actions for P1 and P2");
        $finish;
    end
endmodule
