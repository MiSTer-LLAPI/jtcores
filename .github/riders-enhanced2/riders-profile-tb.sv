module riders_profile_tb;
    reg clk_rom=0, clk_sys=0, ioctl_rom=0, ioctl_wr=0;
    reg [26:0] ioctl_addr=0;
    reg [7:0] ioctl_dout=0;
    wire second_cab, second_sys;
    always #5 clk_rom=~clk_rom;
    always #7 clk_sys=~clk_sys;
    jtriders_autofire_profile dut(
        .clk_rom(clk_rom),.clk_sys(clk_sys),.ioctl_rom(ioctl_rom),.ioctl_wr(ioctl_wr),
        .ioctl_addr(ioctl_addr),.ioctl_dout(ioctl_dout),
        .second_action_cab(second_cab),.second_action_sys(second_sys));
    task header(input [7:0] value);
        begin
            @(negedge clk_rom);
            ioctl_rom=1; ioctl_wr=1; ioctl_addr=15; ioctl_dout=value;
            @(negedge clk_rom);
            ioctl_wr=0;
            repeat(4) @(negedge clk_sys);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk_sys);
        if(second_sys!==0) $fatal(1,"default must be action 1");
        header(8'h08);
        if(second_sys!==1) $fatal(1,"Golfing Greats must use Shot on action 2");
        header(8'h02);
        if(second_sys!==0) $fatal(1,"TMNT2 must use action 1");
        header(8'h04);
        if(second_sys!==0) $fatal(1,"Lightning Fighters must use action 1");
        $display("PASS: Riders game header selects the correct autofire action");
        $finish;
    end
endmodule
