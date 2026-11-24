// Exercise the configuration used by this core, including the loaded MRA header.
module autofire_tb;
    reg clk=0, clk_rom=0;
    always #5 clk=~clk;
    always #7 clk_rom=~clk_rom;
    reg rst=1, vblank=0, osd=0, rom=0, wr=0;
    reg [26:0] addr=0;
    reg [7:0] data=0;
    reg [63:0] status=0;
    wire six, six_sys, border;
    wire [15:0] joy1,joy2;
    reg [31:0] b1=0,b2=0;
    jtflstory_autofire_profile profile(clk_rom,clk,rom,wr,addr,data,six,six_sys);
    jtframe_mister_status decode(.status(status),.gun_border_en(border));
    jtframe_serial_arcade #(.BUTTONS(`JTFRAME_BUTTONS)) dut(
        .clk_50(clk),.clk_sys(clk),.rst(rst),.vblank(vblank),.osd_active(osd),.repoll_off(1'b0),
        .mode(3'd0),.user_in(7'h7f),.usb1(16'd0),.usb2(16'd0),
        .autofire_enable(status[8] && !six_sys),.autofire_toggle(1'b0),
        .autofire_enable2(status[23] && !six_sys),.autofire_toggle2(1'b0),
        .autofire_rate1(status[26:25]),.autofire_rate2(status[28:27]),
        .loss_resume(1'b0),.info_clk(clk),.joy1(joy1),.joy2(joy2)
    );
    task ticks(input integer n); repeat(n) @(negedge clk); endtask
    task frame_tick; begin vblank=1;ticks(5);vblank=0;ticks(5);end endtask
    task header_write(input integer offset,input [7:0] value,input bit is_rom);
        begin
            @(negedge clk_rom); wr=1;rom=is_rom;addr=offset;data=value;
            @(negedge clk_rom); wr=0;rom=0;ticks(5);
        end
    endtask
    initial begin
        force dut.u_llapi.valid1_sync=1;
        force dut.u_llapi.valid2_sync=1;
        force dut.u_llapi.buttons1_sync=b1;
        force dut.u_llapi.buttons2_sync=b2;
        force dut.llapi_type_changed=0;
        ticks(10);rst=0;ticks(7520);
        status[8]=1;status[23]=1;ticks(5);
        if (border!==0) $fatal(1,"autofire enabled a border");
        status[31]=1;#1;if(border!==1) $fatal(1,"Sinden option lost");
        status[31]=0;
        header_write(6,0,0);header_write(14,0,1);
        if(!six_sys) $fatal(1,"nonheader write switched profile");
        header_write(6,0,1);
        if(six_sys) $fatal(1,"two-button profile not selected");
        ticks(8);b1[3]=1;ticks(2);
        if(joy1[4]!==1 || joy2[4]!==0) $fatal(1,"P1 LLAPI Hold");
        repeat(3) frame_tick;
        if(joy1[4]!==0) $fatal(1,"no release edge while held");
        repeat(3) frame_tick;
        if(joy1[4]!==1) $fatal(1,"no repeat while held");
        b1=0;b2[3]=1;ticks(2);
        if(joy1[4]!==0 || joy2[4]!==1) $fatal(1,"independent P2");
        b2=0;osd=1;ticks(2);b1[3]=1;ticks(2);
        if(joy1[4]!==0) $fatal(1,"menu inhibition lost");
        b1=0;osd=0;ticks(5);
        header_write(6,7,1);
        b1[3]=1;b2[3]=1;ticks(3);
        if(!six_sys || joy1[7]!==1 || joy2[7]!==1 || joy1[4]!==0 || joy2[4]!==0)
            $fatal(1,"Victorious Nine action 4 conflicts with autofire");
        b1[0]=1;ticks(2);if(joy1[4]!==1) $fatal(1,"manual fire lost");
        $display("PASS actual FairyLand configuration: Sinden/Hold, two ports, frame pulses, six-button game");
        $finish;
    end
endmodule
