// Escape Kids test boundary: synchronized controller samples and CPU address.
// Use the production serial mux, active-low merge, DURL reorder, seat selector
// and Konami cabinet read mux for every assertion about buttons or credits.
`timescale 1ns/1ps
module esckids_serial_tb;
    reg clk = 0, rst = 1, vblank = 0, osd = 0;
    always #5 clk = ~clk;

    reg [2:0] mode = 0;
    reg [1:0] seat = 0;
    reg [8:0] pad1 = 0, pad2 = 0;
    reg [31:0] report1 = 0, report2 = 0;
    reg [1:0] llapi_valid = 0, spare = 0, hold_enable = 0, toggle = 0;
    wire [15:0] db_pad1 = {8'd0, spare[0], 7'd0};
    wire [15:0] db_pad2 = {8'd0, spare[1], 7'd0};
    wire valid1 = llapi_valid[0], valid2 = llapi_valid[1];
    reg dash_autofire = 1;
    reg [15:0] usb1 = 0, usb2 = 0, usb3 = 0, usb4 = 0;
    reg [3:0] native_coin = 0, native_start = 0;
    reg service = 0;
    wire [15:0] serial1, serial2;
    wire [3:0] serial_coin, serial_start;
    wire menu;

    jtframe_serial_arcade #(.BUTTONS(`JTFRAME_BUTTONS)) serial(
        .clk_50(clk), .clk_sys(clk), .rst(rst), .vblank(vblank),
        .mode(mode), .osd_active(osd), .info_clk(clk), .repoll_off(1'b0),
        .dash_autofire(dash_autofire),
        .autofire_enable(hold_enable[0]), .autofire_enable2(hold_enable[1]),
        .autofire_toggle(toggle[0]), .autofire_toggle2(toggle[1]),
        .autofire_rate1(2'd0), .autofire_rate2(2'd0), .loss_resume(1'b0),
        .user_in(7'h7f), .usb1(usb1), .usb2(usb2),
        .joy1(serial1), .joy2(serial2), .coin(serial_coin),
        .start(serial_start), .osd_request(menu)
    );

    wire [9:0] raw [0:3], sorted [0:3], game [0:3];
    wire [3:0] merged_coin, merged_start, game_coin, game_start;
    wire game_service;
    jtframe_merge_keyjoy merge(
        .clk(clk), .rst(rst), .board_coin(serial_coin), .board_start(serial_start),
        .joy_coin(native_coin), .joy_start(native_start), .key_coin(4'd0), .key_start(4'd0),
        .joy1(serial1), .joy2(serial2), .joy3(usb3), .joy4(usb4),
        .key_joy1(10'd0), .key_joy2(10'd0), .key_joy3(10'd0), .key_joy4(10'd0),
        .mouse_but_1p(3'd0), .mouse_but_2p(3'd0), .key_service(service), .joy_service(1'b0),
        .game_joy1(raw[0]), .game_joy2(raw[1]), .game_joy3(raw[2]), .game_joy4(raw[3]),
        .game_service(game_service), .game_coin(merged_coin), .game_start(merged_start)
    );
    jtframe_joy_reorder reorder(
        .raw1(raw[0]), .raw2(raw[1]), .raw3(raw[2]), .raw4(raw[3]),
        .joy1(sorted[0]), .joy2(sorted[1]), .joy3(sorted[2]), .joy4(sorted[3])
    );
    jtframe_joy1_pos player_position(
        .clk(clk), .pos(seat), .raw_coin(merged_coin), .raw_start(merged_start),
        .raw1(sorted[0]), .raw2(sorted[1]), .raw3(sorted[2]), .raw4(sorted[3]),
        .joy1(game[0]), .joy2(game[1]), .joy3(game[2]), .joy4(game[3]),
        .coin(game_coin), .start(game_start)
    );

    reg [15:0] address = 0;
    jtsimson_main cabinet(
        .clk(clk), .rst(rst), .paroda(1'b0), .suratk(1'b0), .simson(1'b0),
        .vendetta(1'b0), .esckids(1'b1), .joystick1(game[0][6:0]),
        .joystick2(game[1][6:0]), .joystick3(game[2][6:0]), .joystick4(game[3][6:0]),
        .cab_1p(game_start), .coin(game_coin), .service(game_service), .dip_test(1'b1)
    );

    task settle; repeat(9) @(negedge clk); endtask
    task frame; begin vblank = 1; settle; vblank = 0; settle; end endtask
    task set_mode(input [2:0] new_mode);
        mode = new_mode;
        repeat(7600) @(negedge clk);
    endtask
    task check_read(input [15:0] port, input [7:0] expected);
        address = port;
        settle;
        if (cabinet.cpu_din !== expected)
            $fatal(1, "Escape Kids mode %0d seat %0d port %h expected %h got %h",
                   mode, seat, port, expected, cabinet.cpu_din);
    endtask
    function automatic [7:0] port_byte(input [6:0] joy, input credit);
        port_byte = ~{credit, joy[6:4], joy[2], joy[3], joy[1:0]};
    endfunction
    task check_all(input [6:0] one, two, three, four, input [3:0] starts, coins);
        check_read('h3f80, port_byte(one, coins[0]));
        check_read('h3f81, port_byte(two, coins[1]));
        check_read('h3f82, port_byte(three, coins[2]));
        check_read('h3f83, port_byte(four, coins[3]));
        check_read('h3f91, ~{{4{service}}, starts});
    endtask

    task tap(input integer player);
        if (player == 0) pad1[7] = 1; else pad2[7] = 1;
        repeat(3) frame;
        check_read('h3f91, 8'hff);
        if (menu !== 0) $fatal(1, "Start gesture leaked into OSD");
        if (player == 0) pad1[7] = 0; else pad2[7] = 0;
        repeat(3) frame;
    endtask

    // Check the entire cabinet input byte every frame: the other action and
    // directions must remain manual, and local 3P/4P retain their own inputs.
    task check_pulses(input integer player, action, expected_frames);
        integer n, hits;
        reg [6:0] wanted1, wanted2;
        reg pressed;
        hits = 0;
        for (n = 0; n < 12; n = n + 1) begin
            frame;
            address = 'h3f80 + player;
            settle;
            pressed = ~cabinet.cpu_din[action];
            if (pressed !== 0 && pressed !== 1) $fatal(1, "Unknown action state");
            hits = hits + pressed;
            wanted1 = pad1[6:0];
            wanted2 = pad2[6:0];
            if (player == 0) wanted1[action] = pressed; else wanted2[action] = pressed;
            check_all(wanted1, wanted2, usb3[6:0], usb4[6:0], 0, 0);
        end
        if (hits != expected_frames)
            $fatal(1, "mode %0d P%0d action %0d active %0d/12, expected %0d",
                   mode, player + 1, action, hits, expected_frames);
    endtask

    // Apply the auxiliary trigger after the physical protocol decoder but
    // before player selection, CDC, and the actual Hold/Toggle pulse generator.
    task set_spare(input [1:0] buttons);
        spare = buttons;
        report1[3] = buttons[0]; report2[3] = buttons[1];
        settle;
    endtask
    task auxiliary_output(input integer player, target, expected_frames);
        integer n, hits;
        reg [6:0] first, second;
        reg pressed;
        hits = 0;
        for (n = 0; n < 12; n = n + 1) begin
            frame;
            address = 'h3f80 + player;
            settle;
            pressed = ~cabinet.cpu_din[target];
            if (pressed !== 0 && pressed !== 1) $fatal(1, "Unknown Hold/Toggle output");
            hits = hits + pressed;
            first = 0; second = 0;
            if (player == 0) first[target] = pressed; else second[target] = pressed;
            check_all(first, second, usb3[6:0], usb4[6:0], 0, 0);
        end
        if (hits != expected_frames)
            $fatal(1, "Auxiliary mode %0d player %0d target %0d saw %0d expected %0d",
                   mode, player + 1, target, hits, expected_frames);
    endtask

    integer m, player, action, players, n;
    reg [6:0] one, two;
    initial begin
        force cabinet.A = address;
        force serial.port1 = pad1;
        force serial.port2 = pad2;
        force serial.snac_af = spare;
        force serial.db1 = db_pad1;
        force serial.db2 = db_pad2;
        force serial.u_llapi.valid1_sync = valid1;
        force serial.u_llapi.valid2_sync = valid2;
        force serial.u_llapi.buttons1_sync = report1;
        force serial.u_llapi.buttons2_sync = report2;
        force serial.u_llapi.saturn1_sync = 0;
        force serial.u_llapi.saturn2_sync = 0;
        settle;
        rst = 0;
        set_mode(0);

        // All 64 simultaneous axes + two-button states, with different
        // patterns per player, pass through the actual Konami cabinet layout.
        for (n = 0; n < 64; n = n + 1) begin
            one = n; two = (n * 17 + 3) & 63;
            usb3 = (n * 5 + 7) & 63; usb4 = (n * 13 + 29) & 63;
            usb1 = one; usb2 = two;
            service = n[5]; native_start = n[3:0]; native_coin = ~n[3:0];
            llapi_valid = 0;
            check_all(one, two, usb3[6:0], usb4[6:0], native_start, native_coin);
            llapi_valid = 3; usb1 = 0; usb2 = 0;
            report1[27:24] = one[3:0]; report1[1:0] = one[5:4];
            report2[27:24] = two[3:0]; report2[1:0] = two[5:4];
            check_all(one, two, usb3[6:0], usb4[6:0], native_start, native_coin);
        end
        report1 = 0; report2 = 0; llapi_valid = 0; native_start = 0; native_coin = 0; service = 0;
        usb3 = 'h20; usb4 = 'h10;
        for (m = 1; m <= 6; m = m + 1) begin
            set_mode(m);
            players = (m == 3 || m == 4 || m == 6) ? 2 : 1;
            for (player = 0; player < players; player = player + 1) begin
                if (player == 0) pad1 = 'h80; else pad2 = 'h80;
                check_all(0, 0, usb3[6:0], usb4[6:0], 1 << player, 0);
                if (player == 0) pad1 = 'h100; else pad2 = 'h100;
                check_all(0, 0, usb3[6:0], usb4[6:0], 0, 1 << player);
                pad1 = 0; pad2 = 0;
                for (action = 4; action <= 5; action = action + 1) begin
                    if (player == 0) pad1 = 1 << action; else pad2 = 1 << action;
                    settle;
                    repeat(2) tap(player);
                    check_pulses(player, action, 12);
                    tap(player);
                    check_pulses(player, action, 6);
                    // The second action stays manually held while the first repeats.
                    if (player == 0) pad1[9-action] = 1; else pad2[9-action] = 1;
                    check_pulses(player, action, 6);
                    pad1 = 0; pad2 = 0;
                    check_pulses(player, action, 0);
                    if (player == 0) pad1 = 1 << action; else pad2 = 1 << action;
                    settle;
                    repeat(3) tap(player);
                    check_pulses(player, action, 12);
                    pad1 = 0; pad2 = 0;
                    settle;
                end
                // X is unassigned in both Escape Kids MRAs. Holding it may
                // not swallow normal Start or put X into pulse mode.
                if (player == 0) pad1 = 'h40; else pad2 = 'h40;
                settle;
                repeat (3) begin
                    if (player == 0) pad1[7] = 1; else pad2[7] = 1;
                    repeat (3) frame;
                    if (m != 3 && (serial_start[player] !== 1 || menu !== 0))
                        $fatal(1, "Unused third action swallowed Start");
                    if (player == 0) pad1[7] = 0; else pad2[7] = 0;
                    repeat (3) frame;
                end
                check_pulses(player, 6, 12);
                pad1 = 0; pad2 = 0; settle;
            end
            // The existing OSD chord must not inject Jump, Start or credits.
            pad1 = m == 3 ? 'hc0 : 'h94;
            settle;
            if (menu !== 1) $fatal(1, "OSD shortcut lost in SNAC mode %0d", m);
            check_all(0, 0, usb3[6:0], usb4[6:0], 0, 0);
            pad1 = 0;
        end

        // Off is the default. Hold and Toggle drive Dash on Escape Kids,
        // and the family's default first action on the other layouts.
        for (m = 0; m <= 6; m = m + 1) begin
            set_mode(m);
            llapi_valid = m == 0 ? 3 : 0;
            players = (m == 0 || m == 3 || m == 4 || m == 6) ? 2 : 1;
            for (player = 0; player < players; player = player + 1) begin
                set_spare(1 << player);
                auxiliary_output(player, 5, 0);
                set_spare(0);
                hold_enable = 1 << player; settle;
                set_spare(1 << player);
                auxiliary_output(player, 5, m < 5 ? 6 : 0);
                set_spare(0); auxiliary_output(player, 5, 0);
                toggle = 1 << player; settle;
                set_spare(1 << player); set_spare(0);
                auxiliary_output(player, 5, m < 5 ? 6 : 0);
                set_spare(1 << player); set_spare(0);
                auxiliary_output(player, 5, 0);
                toggle = 0; dash_autofire = 0; settle;
                set_spare(1 << player);
                auxiliary_output(player, 4, m < 5 ? 6 : 0);
                set_spare(0); hold_enable = 0; dash_autofire = 1; settle;
            end
        end
        llapi_valid = 0;

        // Move the first controller into each of the three other seats, as
        // the original four-player game allows, with its Start and credit.
        set_mode(3);
        usb3 = 0; usb4 = 0; pad1 = 'h181;
        for (n = 0; n < 4; n = n + 1) begin
            seat = n[1:0];
            check_all(n == 0, n == 1, n == 2, n == 3, 1 << n, 1 << n);
        end
        $display("PASS Escape Kids: USB and LLAPI cabinet reads, six SNAC modes, Jump/Dash Start x3 on/off, separation, release, Start/Coin/OSD and all four player seats");
        $finish;
    end
endmodule
