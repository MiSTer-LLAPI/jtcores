// SPDX-License-Identifier: GPL-3.0-or-later
// Capture official header bytes in clk_rom. The game remains in reset
// throughout the download, and both bytes settle before gameplay begins.
module jtthundr_autofire_profile (
    input clk_rom, clk_sys, ioctl_rom, ioctl_wr,
    input [26:0] ioctl_addr,
    input [7:0] ioctl_dout,
    output [5:0] action_mask
);
    reg hopping_mappy = 0;
    reg single_action = 0;
    always @(posedge clk_rom) begin
        if (ioctl_rom && ioctl_wr) begin
            if (ioctl_addr == 27'd1)
                hopping_mappy <= ioctl_dout == 8'h0d;
            if (ioctl_addr == 27'd2)
                single_action <= ioctl_dout[3] || ioctl_dout[0];
        end
    end

    wire [5:0] mask_rom = hopping_mappy || single_action ? 6'b000001 : 6'b000011;
    (* async_reg = "true" *) reg mask_meta = 1, mask_sys = 1;
    always @(posedge clk_sys) begin
        mask_meta <= mask_rom[1];
        mask_sys <= mask_meta;
    end
    assign action_mask = {4'b0, mask_sys, 1'b1};
endmodule
