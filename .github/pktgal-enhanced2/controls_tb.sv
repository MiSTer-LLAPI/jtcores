module pocketgal_controls_tb;
reg [31:0] b1, b2;
wire [15:0] joy1, joy2;
wire [3:0] start, coin;
wire osd;
jtframe_llapi_arcade_map #(.BUTTONS(2)) map(
    .buttons1(b1), .buttons2(b2), .valid1(1'b1), .valid2(1'b1), .osd_active(1'b0),
    .usb1(16'd0), .usb2(16'd0), .joy1(joy1), .joy2(joy2),
    .start(start), .coin(coin), .osd_request(osd)
);
integer a,b;
initial begin
    // Enumerate both sockets' two game buttons and two spare LLAPI button bits.
    for (a=0;a<16;a=a+1) for (b=0;b<16;b=b+1) begin
        b1=a; b2=b; #1;
        if(joy1 !== {10'd0,a[1:0],4'd0} || joy2 !== {10'd0,b[1:0],4'd0} || start!==0 || coin!==0 || osd!==0)
            $fatal(1,"Pocket Gal manual actions or reserved bit leaked (%d %d)",a,b);
    end
    b1=32'h01000010; b2=32'h04000040; #1;
    if(joy1!==16'h1 || joy2!==16'h4 || start!==4'b0010 || coin!==4'b0001) $fatal(1,"directions/start/coin");
    b1=0; b2=0; #1;
    if({joy1,joy2,start,coin,osd} !== 0) $fatal(1,"release remained stuck");
    $display("PASS Pocket Gal Shot/Trick P1/P2, spare trigger isolation, start/coin, directions and release");
    $finish;
end
endmodule
