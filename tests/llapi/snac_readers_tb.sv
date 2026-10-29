`timescale 1ns/1ps
module snac_readers_tb;
    reg clk=0; always #10 clk=~clk;
    reg enable=0;
    reg [1:0] mode=0;
    wire [6:0] pins;
    wire [8:0] pad;
    reg unplug=0,six=1;
    reg [15:0] snes_pressed=0;
    integer snes_bit=0;
    reg [5:0] md_pressed=0; // C B R L D U
    reg [1:0] md_as_pressed=0; // Start A
    reg [3:0] md_extra_pressed=0; // Mode X Y Z
    integer md_count=0,idle=0;
    reg [3:0] sat_main_pressed=0,sat_dir_pressed=0;
    reg sat_l=0;
    reg [6:0] input_pins;
    jtframe_snac_arcade #(.TICK_CYCLES(8),.SCAN_TICKS(80)) dut(
        .clk_50(clk),.enable(enable),.mode(mode),.user_in(input_pins),
        .user_out(pins),.pad(pad));
    // Independent pin-level controller models, active-low electrical inputs.
    always @(negedge pins[0]) snes_bit=0;
    always @(negedge pins[1]) if(mode==1 && !pins[0] && snes_bit<15) snes_bit=snes_bit+1;
    always @(negedge pins[4]) if(mode==2) md_count=md_count+1;
    always @(posedge clk) begin
        if(mode!=2 || !enable) begin idle=0;md_count=0;end
        else if(pins[4]) begin
            idle=idle+1;
            if(idle>100) md_count=0;
        end else idle=0;
    end
    reg [5:0] md_data;
    reg [3:0] sat_data;
    always @* begin
        input_pins=7'h7f;
        md_data=~md_pressed;
        if(!pins[4]) begin
            md_data={~md_as_pressed,2'b00,~md_pressed[1:0]};
            if(six && md_count==3) md_data[3:0]=0;
        end else if(six && md_count==3) md_data={2'b11,~md_extra_pressed};
        case({pins[6],pins[4]})
            0: sat_data=4'hf;
            1: sat_data=~sat_main_pressed;
            2: sat_data=~sat_dir_pressed;
            3: sat_data={~sat_l,3'b100};
        endcase
        if(mode==1) input_pins[5]=pins[0] ? ~snes_pressed[0] : ~snes_pressed[snes_bit];
        if(mode==2) begin
            input_pins[6]=md_data[5];input_pins[2]=md_data[4];
            input_pins[3]=md_data[3];input_pins[5]=md_data[2];
            input_pins[0]=md_data[1];input_pins[1]=md_data[0];
        end
        if(mode==3) begin
            begin
                input_pins[3]=sat_data[3];input_pins[5]=sat_data[2];
                input_pins[0]=sat_data[1];input_pins[1]=sat_data[0];
            end
        end
        if(unplug) input_pins=7'h7f;
    end
    task scan; begin repeat(1500) @(negedge clk); end endtask
    task expect_pad(input [8:0] value);begin
        if(pad!==value) $fatal(1,"mode %d expected %h got %h",mode,value,pad);
    end endtask
    task select_mode(input [1:0] value);begin
        enable=0;repeat(5) @(negedge clk);
        if(pins!==7'h7f || pad!==0) $fatal(1,"inactive reader drives pins or buttons");
        mode=value;enable=1;scan();
    end endtask
    integer button;
    initial begin
        snes_pressed=(1<<0)|(1<<2)|(1<<4); // B, Select, Up
        select_mode(1);expect_pad(9'h118);
        snes_pressed=0;scan();expect_pad(0);
        snes_pressed=(1<<8)|(1<<3)|(1<<5);scan();expect_pad(9'h0a4); // A,Start,Down
        md_pressed=(1<<4)|(1<<2);md_as_pressed=2'b10;md_extra_pressed=4'b1000;
        select_mode(2);expect_pad(9'h192); // B,Left,Start,Mode
        six=0;md_pressed=(1<<1);md_as_pressed=2'b10;scan();expect_pad(9'h184); // Down+Start coin
        // A real three-button pad must retain each standard control, even
        // though it never returns the six-button extension signature.
        md_pressed=0;md_as_pressed=0;six=0;
        for(button=0;button<6;button=button+1) begin
            md_pressed=6'b1<<button;scan();
            case(button)
                0: expect_pad(9'h008); // Up
                1: expect_pad(9'h004); // Down
                2: expect_pad(9'h002); // Left
                3: expect_pad(9'h001); // Right
                4: expect_pad(9'h010); // B: shoot
                5: expect_pad(9'h040); // C: third button
            endcase
        end
        md_pressed=0;md_as_pressed=1;scan();expect_pad(9'h020); // A: bomb
        md_as_pressed=2;scan();expect_pad(9'h080); // Start
        unplug=1;scan();expect_pad(0);unplug=0;
        sat_main_pressed=1;sat_dir_pressed=1;sat_l=1;
        select_mode(3);expect_pad(9'h118); // B,Up,L
        sat_main_pressed=0;sat_dir_pressed=0;sat_l=0;scan();expect_pad(0);
        unplug=1;scan();expect_pad(0);unplug=0;
        enable=0;repeat(5) @(negedge clk);
        if(pins!==7'h7f) $fatal(1,"pins not released");
        $display("PASS: SNES serial edges, MD 3/6-button handshake, Saturn digital pinout, release and disconnect");
        $finish;
    end
endmodule
