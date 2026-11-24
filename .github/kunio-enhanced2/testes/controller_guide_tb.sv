module hps_menu_tb;
    reg clk=0;
    always #5 clk=~clk;
    reg io_enabled=0;
    reg io_strobe=0;
    reg [15:0] io_input=0;
    reg [2:0] mode=0;
    wire [2:0] selected=dut.status[63:61];
    reg [1:0] presence=0;
    wire [19:0] info={presence,8'd3,2'b01,8'd27};
    reg p1_autofire=0;
    wire [48:0] hps_bus;
    wire [35:0] ext_bus;
    wire [15:0] menu_mask = {
        2'b00, (selected>=5 || !p1_autofire), (selected!=0),
        2'b00, 1'b1, (selected>=5 || !p1_autofire), (selected>=5), 7'd0
    };
    assign hps_bus[35:33] = {1'b0, io_enabled, io_strobe};
    assign hps_bus[31:16] = io_input;
    assign ext_bus[32]=1'b0;

    hps_io #(.CONF_STR(128'h01020304050607081112131415161718), .STRLEN(16)) dut(
        .clk_sys(clk), .HPS_BUS(hps_bus), .EXT_BUS(ext_bus), .status_menumask(menu_mask),
        .enhanced_controller_info(info),
        .enhanced_link_diagnostics(8'd0), .enhanced_last_fault(4'd0)
    );


    jtframe_llapi_arcade #(.BUTTONS(2)) llapi(
        .clk_50(clk),.clk_sys(clk),.rst(1'b0),.vblank(1'b0),.osd_active(1'b0),
        .enable(1'b0),.repoll_off(dut.status[24]),.user_in(7'h7f),
        .info_clk(clk),.loss_resume(1'b0),.usb1(16'd0),.usb2(16'd0));
    task send_word(input [15:0] value);
    begin
        @(negedge clk);
        io_input = value;
        io_strobe = 1'b1;
        @(negedge clk);
        io_strobe = 1'b0;
    end
    endtask

    task begin_cmd(input [15:0] command);
    begin
        @(negedge clk);
        io_enabled=1'b0;
        @(negedge clk);
        io_enabled=1'b1;
        send_word(command);
    end
    endtask

    integer i, j, k;
    reg [63:0] p2_name;
    reg [15:0] returned_mask;
    reg [63:0] returned_name;
    initial begin
        for (i=0;i<8;i=i+1) begin
            mode=i;
            for (k=0;k<3;k=k+1) begin
                presence=k;
                for (j=0;j<2;j=j+1) begin
                    p1_autofire=j;
                    begin_cmd(16'h1e);
                    send_word(p1_autofire ? 16'h1100 : 16'h0000);
                    send_word((i&1) ? 16'h9945 : 16'h9845);
                    send_word(16'habcd);
                    send_word({mode,13'h1555});
                    send_word(16'h7890); send_word(16'h7555);
                    send_word(16'h2333); send_word(16'hFFFF);
                    if(selected !== ((mode==7) ? 3'd0 : mode) ||
                       dut.status[60:48] !== 13'h1555 || dut.status[8] !== p1_autofire ||
                       dut.status[127:64] !== 64'hFFFF233375557890 || dut.status[47:16] !== ((i&1)?32'habcd9945:32'habcd9845) || dut.status[12] !== p1_autofire)
                        $fatal(1,"Restored bits, mode %d",i);
`ifdef JTFRAME_ENHANCED_FIXED_OPTIONS
                    if(llapi.u_port1.enhanced.REPOLL_OFF!==1'b0 || llapi.u_port2.enhanced.REPOLL_OFF!==1'b0)
                       $fatal(1,"Old setting disabled repoll");
`else
                    if(llapi.u_port1.enhanced.REPOLL_OFF!==dut.status[24] || llapi.u_port2.enhanced.REPOLL_OFF!==dut.status[24])
                       $fatal(1,"Opt-out version lost adjustable repoll");
`endif
                    begin_cmd(16'h2e);
                    send_word(16'h0);
                    returned_mask=hps_bus[15:0];
                    if(returned_mask !== {menu_mask[15],(presence!=1),menu_mask[13:0]})
                        $fatal(1,"Incorrect full mask, mode %d",i);
                end
                begin_cmd(16'h14);
                for (j=0;j<8;j=j+1) begin
                    send_word(16'h0);
                    returned_name[63-j*8 -: 8]=hps_bus[7:0];
                end
                for (j=0;j<8;j=j+1) begin
                    send_word(16'h0);
                    p2_name[63-j*8 -: 8]=hps_bus[7:0];
                end
                if(returned_name!=="SNES    " || p2_name!==((presence==0)?"NOT DETE":"SATURN  "))
                    $fatal(1,"Invalid guide IDs, mode %d presence %d: '%s'/'%s'",i,k,returned_name,p2_name);
            end
        end
        $display("PASS HPS status restore all eight slots, all 128 bits, guide masks, and dynamic P1/P2 names with 3 P2 presence states.");
        $finish;
    end
endmodule
