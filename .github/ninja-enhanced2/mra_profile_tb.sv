module mra_profile_tb;
    reg rom_clk=0, game_clk=0, serial_clk=0;
    reg wr=0;
    reg [26:0] addr=0;
    reg [7:0] data=0, mod_byte, volume;
    integer rotary;
    always #5 rom_clk=~rom_clk;
    always #7 game_clk=~game_clk;
    always #11 serial_clk=~serial_clk;

    jtframe_mister #(.BUTTONS(`JTFRAME_BUTTONS)) dut(
        .clk_rom(rom_clk),.clk_sys(game_clk),.clk_llapi(serial_clk),
        .OSD_STATUS(1'b0),.USER_IN(7'h7f));

    initial begin
        if (!$value$plusargs("mod=%h",mod_byte) || !$value$plusargs("vol=%h",volume)
            || !$value$plusargs("rotary=%d",rotary)) $fatal(1,"missing MRA fields");
        force dut.rst=1;
        force dut.hps_wr=wr;
        force dut.hps_index=8'd1;
        force dut.hps_addr=addr;
        force dut.hps_dout=data;
        force dut.hps_status_full={64'd0,3'd2,61'd0}; // MD SNAC selected
        force dut.u_serial.md_three=1; // three-button pad
        repeat(3) @(negedge rom_clk);
        force dut.rst=0;
        wr=1;addr=0;data=mod_byte;
        @(negedge rom_clk);addr=1;data=volume;
        @(negedge rom_clk);wr=0;
        repeat(5) @(negedge serial_clk);
        if (dut.core_mod[6:0]!==mod_byte[6:0] || dut.game_vol!==volume)
            $fatal(1,"wrong core profile or volume after real index-1 download");
        if (dut.u_serial.rotary_sys!==rotary[0] || dut.u_serial.rotary50!==rotary[0])
            $fatal(1,"variant failed to reach LLAPI and SNAC");
        if (dut.status_menumask[7]!==rotary[0])
            $fatal(1,"wrong three-button Hold availability after MRA load");
        $display("PASS MRA index 1 bytes %02h %02h, LLAPI, SNAC and MD3 menu",mod_byte,volume);
        $finish;
    end
endmodule
