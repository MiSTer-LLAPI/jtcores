module credit_select_tb;
    reg clk=0, enabled=0, strobe=0;
    reg [15:0] data=0;
    wire [48:0] bus;
    wire [35:0] ext_bus;
    wire [127:0] status;
    reg pause_n=1, osd=0;
    wire credits_visible;
    reg [15:0] frames [0:31];
    always #5 clk=~clk;
    assign bus[35:33]={1'b0, enabled, strobe};
    assign bus[31:16]=data;
    assign ext_bus[32]=1'b0;

    hps_io #(.STRLEN(16), .CONF_STR_BRAM(0), .CONF_STR(128'h4142434445464748494a4b4c4d4e4f50)) hps (.clk_sys(clk), .HPS_BUS(bus),
        .EXT_BUS(ext_bus), .status(status), .enhanced_controller_info(20'd0),
        .enhanced_link_diagnostics(8'd0), .enhanced_last_fault(4'd0), .status_menumask(16'd0));
    credits_from_board credits (.clk_sys(clk), .status(status), .dip_pause(pause_n),
        .osd_shown(osd), .visible(credits_visible));
    jtframe_llapi_arcade pads (.clk_sys(clk), .clk_50(clk), .rst(1'b0),
        .enable(1'b0), .osd_active(osd), .repoll_off(status[24]),
        .user_in(7'h7f), .info_clk(clk), .loss_resume(1'b0),
        .vblank(1'b0), .usb1(16'd0), .usb2(16'd0));

    task send(input [15:0] word);
        @(negedge clk); strobe=1; data=word;
        @(negedge clk); strobe=0;
    endtask
    integer i, j, p, o;
    reg expected;
    initial begin
        // Each 8-word SPI frame came from MiSTer Main's Select and status routines.
        // A fresh profile starts with credits Off; following presses produce On, Off, On.
        $readmemh("referencia/status-select.hex", frames);
        for (i=0;i<4;i=i+1) begin
            @(negedge clk); enabled=0;
            @(negedge clk); enabled=1;
            send(16'h1e);
            for (j=0;j<8;j=j+1) send(frames[8*i+j]);
            repeat(4) @(negedge clk);
            for(j=0;j<8;j=j+1)
                if(status[16*j +:16] !== frames[8*i+j]) $fatal(1,"Stored word %d mismatch",j);
            if(status[12]!==i[0] || !status[24] ||
               pads.u_port1.enhanced.REPOLL_OFF!==1'b0 || pads.u_port2.enhanced.REPOLL_OFF!==1'b0)
                $fatal(1,"Incorrect restored settings, frame %d",i);
            for (p=0;p<2;p=p+1) for(o=0;o<2;o=o+1) begin
                pause_n=!p; osd=o;
                repeat(3) @(negedge clk);
                expected=i[0] && p && !o;
                if(credits_visible!==expected) $fatal(1,"Credits visibility mismatch, frame=%d pause=%d osd=%d",i,p,o);
            end
        end
        $display("PASS Select Off -> On -> Off -> On, 128-bit HPS transfers, pause/OSD visibility and forced repoll on both ports.");
        $finish;
    end
endmodule
