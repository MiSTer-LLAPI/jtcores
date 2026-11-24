`timescale 1ns/1ps
module snac_readers_tb;
    reg clk=0; always #10 clk=~clk;
    reg enable=0;
    reg [2:0] mode=0;
    wire [6:0] pins;
    wire [8:0] pad;
    wire [1:0] held,right; wire [8:0] pad2;
    reg unplug=0,six=1,rotary=1;
    reg [15:0] snes_pressed=0,snes_p2=0;
    integer snes_bit=0;
    reg [5:0] md_pressed=0; // C B R L D U
    reg [1:0] md_as_pressed=0; // Start A
    reg [3:0] md_extra_pressed=0; // Mode X Y Z
    integer md_count=0,idle=0;
    reg [3:0] sat_main_pressed=0,sat_dir_pressed=0,sat_extra=0;
    reg sat_l=0;
    reg [6:0] input_pins;
    jtframe_snac_arcade #(.BUTTONS(`JTFRAME_BUTTONS),.TICK_CYCLES(8),.SCAN_TICKS(80)) dut(
        .clk_50(clk),.enable(enable),.mode(mode),.user_in(input_pins),
        .user_out(pins),.rotary_profile(rotary),.turn_right(right),.pad2(pad2),.pad(pad),.autofire_hold(held));
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
            0: sat_data=~sat_extra;
            1: sat_data=~sat_main_pressed;
            2: sat_data=~sat_dir_pressed;
            3: sat_data={~sat_l,3'b100};
        endcase
        if(mode==1) input_pins[5]=pins[0] ? ~snes_pressed[0] : ~snes_pressed[snes_bit];
        if(mode==1) input_pins[6]=pins[0] ? ~snes_p2[0] : ~snes_p2[snes_bit];
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

    task check(input [8:0] p1,p2,input [1:0] r,af);
        begin
            scan();
            if (pad!==p1 || pad2!==p2 || right!==r || held!==af)
                $fatal(1,"mode=%d expected %x %x %b %b got %x %x %b %b",mode,p1,p2,r,af,pad,pad2,right,held);
        end
    endtask
    initial begin
        select_mode(1);
        snes_pressed=16'h0002;snes_p2=16'h0001;check('h10,'h20,0,0);
        snes_pressed=16'h0400;snes_p2=16'h0800;check('h40,0,2,0);
        snes_pressed=16'h0800;snes_p2=16'h0400;check(0,'h40,1,0);
        snes_pressed=16'h0200;snes_p2=16'h0200;check(0,0,0,3);
        snes_pressed=16'h0004;snes_p2=16'h0008;check('h100,'h80,0,0);
        snes_pressed=16'h1800;snes_p2=16'h1f0f;check(0,0,0,0);
        rotary=0;
        snes_pressed=16'h0100;snes_p2=16'h0001;check('h10,'h20,0,0);
        snes_pressed=16'h0002;snes_p2=0;check(0,0,0,0);
        rotary=1;
        select_mode(2);
        md_pressed=6'b100000;md_extra_pressed=4'b0001;check('h40,0,1,0);
        md_pressed=0;md_extra_pressed=4'b0100;check(0,0,0,1);
        md_pressed=6'b010000;md_as_pressed=1;md_extra_pressed=0;check('h30,0,0,0);
        six=0;md_extra_pressed=4'b1111;md_pressed=0;md_as_pressed=0;check(0,0,0,0);
        md_pressed=6'b100000;check('h40,0,0,0);
        rotary=0;check('h40,0,0,1);rotary=1;
        select_mode(3);
        sat_extra=4'b1000;sat_l=1;check('h40,0,1,0);
        sat_extra=4'b0100;sat_l=0;check(0,0,0,1);
        sat_extra=4'b0001;check('h100,0,0,0);
        sat_extra=0;sat_main_pressed=4'b0011;check('h30,0,0,0);
        unplug=1;check(0,0,0,0);
        $display("PASS pin-driven SNES P1/P2, MD3/6, Saturn, autofire isolation, release, presence");
        $finish;
    end
endmodule
