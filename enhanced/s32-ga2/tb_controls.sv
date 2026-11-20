// Focused integration test. Drive decoded controller reports at the inputs to
// the real mapper, and check the active-low switches as seen by Golden Axe.
module tb_controls;
    emu dut();
    reg clk = 0, frame = 0;
    always #1 clk = ~clk;
    reg [31:0] usb0 = 0, usb1 = 0, usb2 = 0, usb3 = 0;
    reg [31:0] buttons1 = 0, buttons2 = 0;
    reg [8:0] snac1 = 0, snac2 = 0;
    reg [127:0] settings = 0;
    reg descriptor_write = 0;
    reg [7:0] descriptor_byte = 0;
    reg [1:0] valid = 0;
    wire [2:0] mode = settings[89:87];
    wire valid1 = valid[0], valid2 = valid[1];
    integer i;

    task check_cabinet(input [7:0] p1, p2, service);
        #1;
        if ((dut.in_p1 !== p1) || (dut.in_p2 !== p2) || (dut.in_service12 !== service))
            $fatal(1, "P1/P2/service = %h/%h/%h, expected %h/%h/%h",
                   dut.in_p1, dut.in_p2, dut.in_service12, p1, p2, service);
    endtask

    task load_descriptor(input [7:0] value);
        @(negedge clk);
        descriptor_byte = value;
        descriptor_write = 1;
        @(negedge clk);
        descriptor_write = 0;
    endtask

    initial begin
        force dut.clk_sys = clk;
        force dut.vblank = frame;
        force dut.usb0 = usb0;
        force dut.usb1 = usb1;
        force dut.joystick_2 = usb2;
        force dut.joystick_3 = usb3;
        force dut.status = settings;
        force dut.ioctl_wr = descriptor_write;
        force dut.ioctl_download = descriptor_write;
        force dut.ioctl_index = 1;
        force dut.ioctl_addr = 0;
        force dut.ioctl_dout = descriptor_byte;
        force dut.OSD_STATUS = 0;
        force dut.controllers.ready_sys = 1;
        force dut.controllers.active_sys = mode;
        force dut.controllers.u_llapi.valid1_sync = valid1;
        force dut.controllers.u_llapi.valid2_sync = valid2;
        force dut.controllers.u_llapi.saturn1_sync = 0;
        force dut.controllers.u_llapi.saturn2_sync = 0;
        force dut.controllers.u_llapi.buttons1_sync = buttons1;
        force dut.controllers.u_llapi.buttons2_sync = buttons2;
        force dut.controllers.pad_sys = snac1;
        force dut.controllers.pad2_sys = snac2;

        // Native USB and empty LLAPI both retain independent starts/coins.
        usb0 = (1<<7) | (1<<6) | 1; // P1 Start + Magic + Right
        usb1 = (1<<8) | (1<<5) | 8; // P2 Coin + Jump + Up
        check_cabinet(8'hbb, 8'hdd, 8'he7);
        settings[89:87] = 7;
        check_cabinet(8'hbb, 8'hdd, 8'he7);

        // Both LLAPI ports occupied. Existing HPS Start/Coin and actions must
        // not leak. Service/Test must still work with either USB switch.
        settings[89:87] = 0;
        valid = 3;
        usb0 = 'h3ff;
        usb1 = 'h5ff;
        check_cabinet('hff, 'hff, 'hfc);
        if (dut.in_service34 !== 3'b100) $fatal(1, "PCB Service/Test switches");
        usb0 = 0;
        usb1 = 0;
        for (i = 0; i < 3; i = i + 1) begin
            buttons1 = 1 << i;
            buttons2 = 1 << (2-i);
            check_cabinet(~(8'd1 << i), ~(8'd1 << (2-i)), 8'hff);
        end
        buttons1 = (1<<5);
        buttons2 = (1<<4);
        check_cabinet('hff, 'hff, 'he7); // independent P1 Start and P2 Coin
        buttons1 = (1<<4);
        buttons2 = (1<<6);
        check_cabinet('hff, 'hff, 'hdb); // independent P1 Coin and P2 Start
        buttons1 = (1<<3);
        buttons2 = (1<<3);
        settings[92:91] = 3; // stale settings from a previous build
        check_cabinet('hff, 'hff, 'hff); // spare button cannot fire

        // One LLAPI controller uses P1. USB0 now supplies P2, including its
        // own Start/Coin. USB1's gameplay buttons must not reach either slot.
        valid = 1;
        buttons1 = 1;
        usb0 = (1<<8) | (1<<5);
        usb1 = (1<<7) | (1<<4);
        check_cabinet('hfe, 'hfd, 'hf7);

        // Dual SNES: three distinct actions; coin and start are independent.
        settings[89:87] = 4;
        snac1 = (1<<8) | (1<<6);
        snac2 = (1<<7) | (1<<5);
        check_cabinet('hfb, 'hfd, 'hdb);
        snac1 = (1<<4);
        snac2 = (1<<4);
        repeat (10) begin
            frame = 1; #4;
            frame = 0; #4;
            check_cabinet('hfe, 'hfe, 'hff);
        end

        // P3/P4 retain the native four-player board ports and start bits.
        usb2 = (1<<7) | (1<<6);
        usb3 = (1<<7) | (1<<5);
        #1;
        if ({dut.in_extra1, dut.in_extra2, dut.in_extra3} !== 24'hfbfdfc)
            $fatal(1, "P3/P4 native controls");

        // Each official Golden Axe MRA loads a single cabinet descriptor.
        // The US cabinet remaps Coin 1/2 to the four-player expansion.
        settings[89:87] = 7;
        valid = 0; // the inactive LLAPI reader has released both slots
        usb0 = (1<<8) | (1<<7);
        usb1 = (1<<7);
        usb2 = (1<<8);
        usb3 = (1<<7);
        load_descriptor(8'h00); // World
        check_cabinet('hff, 'hff, 'hcb);
        if (dut.in_extra3 !== 8'hfd) $fatal(1, "World cabinet coin routing");
        load_descriptor(8'h01); // US
        check_cabinet('hff, 'hff, 'hc7);
        if (dut.in_extra3 !== 8'hf5) $fatal(1, "US cabinet coin routing");
        load_descriptor(8'h00); // Japan, after a US game
        check_cabinet('hff, 'hff, 'hcb);
        if (dut.in_extra3 !== 8'hfd) $fatal(1, "Japan cabinet coin routing");
        $display("PASS: USB/LLAPI/SNES cabinet inputs, independent Start/Coin, Service/Test, manual actions and P3/P4");
        $finish;
    end
endmodule
