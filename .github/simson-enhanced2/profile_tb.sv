`timescale 1ns/1ps
module profile_tb;
    reg clk_rom = 0, clk_sys = 0;
    reg rom = 0, wr = 0;
    reg [26:0] addr = 0;
    reg [7:0] data = 0;
    always #3 clk_rom = ~clk_rom;
    always #7 clk_sys = ~clk_sys;

    jtframe_mister top(.clk_sys(clk_sys), .clk_rom(clk_rom));

    task write_check(input rom_cycle, input write_cycle, input [26:0] address,
                     input [7:0] value, input expect_dash);
        @(negedge clk_rom);
        rom = rom_cycle;
        wr = write_cycle;
        addr = address;
        data = value;
        @(negedge clk_rom);
        wr = 0;
        repeat (4) @(negedge clk_sys);
        if (top.u_serial.dash_autofire !== expect_dash)
            $fatal(1, "Unexpected cabinet target after ROM %b write %b address %h data %h",
                   rom_cycle, write_cycle, address, value);
    endtask

    initial begin
        force top.ioctl_rom = rom;
        force top.ioctl_wr = wr;
        force top.ioctl_addr = addr;
        force top.ioctl_dout = data;
        write_check(1, 1, 0, 0, 0);  // The Simpsons
        write_check(1, 1, 0, 3, 1);  // Escape Kids
        write_check(1, 1, 1, 2, 1);  // Other header bytes
        write_check(0, 1, 0, 2, 1);  // Non-ROM transfer
        write_check(1, 0, 0, 2, 1);  // No write strobe
        write_check(1, 1, 0, 2, 0);  // Vendetta
        write_check(1, 1, 0, 3, 1);
        write_check(1, 1, 0, 0, 0);
        $display("PASS real serial profile: Simpsons, Vendetta, Escape Kids and foreign writes");
        $finish;
    end
endmodule
