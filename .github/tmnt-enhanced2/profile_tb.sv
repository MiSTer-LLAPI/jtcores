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
                     input [7:0] value, input [2:0] expected_id);
        @(negedge clk_rom);
        rom = rom_cycle;
        wr = write_cycle;
        addr = address;
        data = value;
        @(negedge clk_rom);
        wr = 0;
        repeat (4) @(negedge clk_sys);
        if (top.u_serial.cabinet_id !== expected_id)
            $fatal(1, "Unexpected cabinet target after ROM %b write %b address %h data %h",
                   rom_cycle, write_cycle, address, value);
    endtask

    initial begin
        force top.ioctl_rom = rom;
        force top.ioctl_wr = wr;
        force top.ioctl_addr = addr;
        force top.ioctl_dout = data;
        write_check(1, 1, 0, 0, 0);  // TMNT
        write_check(1, 1, 0, 1, 1);  // M.I.A.
        write_check(1, 1, 0, 2, 2);  // Punk Shot
        write_check(1, 1, 1, 3, 2);  // Other header bytes
        write_check(0, 1, 0, 3, 2);  // Non-ROM transfer
        write_check(1, 0, 0, 3, 2);  // No write strobe
        write_check(1, 1, 0, 3, 3);  // Thunder Cross II
        write_check(1, 1, 0, 0, 0);  // A new ROM resets the profile
        $display("PASS ROM-header transfer and serial profile for all four layouts");
        $finish;
    end
endmodule
