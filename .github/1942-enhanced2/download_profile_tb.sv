// Exercise the actual MiSTer HPS downloader in the same clock domain as the profile latch.
module download_profile_tb;
    reg rom_clk=0,sys_clk=0,rst=1,download=0,wr=0;
    reg [7:0] index=0,data=0;
    reg [26:0] address=0;
    wire ioctl_rom,ioctl_wr,one_action;
    wire [7:0] ioctl_data;
    wire [26:0] ioctl_addr;
    always #7 rom_clk=~rom_clk;
    always #5 sys_clk=~sys_clk;

    jtframe_mister_dwnld loader(.rst(rst),.clk(rom_clk),.dwnld_busy(1'b0),
        .prog_we(1'b0),.prog_rdy(1'b1),.hps_download(download),.hps_upload(1'b0),
        .hps_index(index),.hps_wr(wr),.hps_addr(address),.hps_dout(data),
        .ioctl_rom(ioctl_rom),.ioctl_wr(ioctl_wr),.ioctl_addr(ioctl_addr),
        .ioctl_dout(ioctl_data),.status(32'd0),.ddram_busy(1'b0),.ddram_dout(64'd0),
        .ddram_dout_ready(1'b0));
    jt1942_snac_profile profile(.clk_rom(rom_clk),.clk_sys(sys_clk),
        .rom_write(ioctl_rom && ioctl_wr),.first_byte(ioctl_addr==0),
        .header_data(ioctl_data),.one_action(one_action));

    task write_byte(input [26:0] addr,input [7:0] value);
        begin
            @(negedge rom_clk); address=addr;data=value;wr=1;
            @(negedge rom_clk);wr=0;
        end
    endtask
    task download_file(input [7:0] file_index,input [7:0] first,input expected);
        begin
            @(negedge rom_clk);index=file_index;
            repeat(3) @(negedge rom_clk);
            download=1;
            repeat(2) @(negedge rom_clk);
            write_byte(0,first);
            write_byte(1,~first);
            write_byte(17,~first);
            repeat(2) @(negedge rom_clk);
            download=0;
            repeat(8) @(negedge rom_clk);
            if(one_action!==expected) $fatal(1,"file index=%x first=%x expected profile=%b got=%b",
                                            file_index,first,expected,one_action);
        end
    endtask
    initial begin
        repeat(4) @(negedge rom_clk);rst=0;
        download_file(0,2,1);    // Higemaru
        download_file(1,0,1);    // video/orientation
        download_file(2,0,1);    // NVRAM
        download_file(254,0,1);  // DIP switches
        rst=1;repeat(5) @(negedge rom_clk);rst=0;
        if(one_action!==1) $fatal(1,"soft reset lost profile");
        download_file(0,1,0);    // Vulgus
        download_file(2,2,0);
        download_file(0,2,1);
        download_file(0,0,0);    // 1942
        $display("PASS MiSTer ROM downloads load 1942/Vulgus/Higemaru profiles; MOD, NVRAM, DIP downloads and soft reset preserve them.");
        $finish;
    end
endmodule
