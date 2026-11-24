module four_actions_tb;
    reg [31:0] p1=0,p2=0;
    reg osd=0;
    wire [15:0] j1,j2;
    jtframe_llapi_arcade_map #(.BUTTONS(4)) dut(
        .buttons1(p1),.buttons2(p2),.valid1(1'b1),.valid2(1'b1),
        .saturn1(1'b0),.saturn2(1'b0),.osd_active(osd),
        .usb1(16'b0),.usb2(16'b0),.joy1(j1),.joy2(j2),
        .start(),.coin(),.osd_request());
    initial begin
        for(integer i=0;i<4;i=i+1) begin
            p1=1<<i;
            p2=1<<(3-i);
            #1;
            if(j1!==(16'h10<<i) || j2!==(16'h10<<(3-i))) $fatal(1,"Action collision");
        end
        p1=32'h5;
        p2=32'ha;
        #1;
        if(j1!==16'h0050 || j2!==16'h00a0) $fatal(1,"Simultaneous diagonals lost");
        osd=1;
        #1;
        if(j1!==0 || j2!==0) $fatal(1,"OSD did not mute inputs");
        $display("PASS four independent Karate Champ LLAPI actions for P1 and P2");
        $finish;
    end
endmodule
