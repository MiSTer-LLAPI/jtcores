`timescale 1ns/1ps
module snac_readers_tb;
    reg clk=0; always #10 clk=~clk;
    reg enable=0;
    reg [2:0] mode=0;
    wire [6:0] pins;
    wire [8:0] pad;
    wire [1:0] held; wire [2:0] e1,e2; wire [8:0] pad2;
    reg unplug=0,six=1;
    reg [15:0] snes_pressed=0,snes_p2=0;
    integer snes_bit=0;
    reg [5:0] md_pressed=0; // C B R L D U
    reg [1:0] md_as_pressed=0; // Start A
    reg [3:0] md_extra_pressed=0; // Mode X Y Z
    integer md_count=0,idle=0;
    reg [3:0] sat_main_pressed=0,sat_dir_pressed=0,sat_extra=0;
    reg sat_l=0;
    reg [6:0] input_pins;
    jtframe_snac_arcade #(.TICK_CYCLES(8),.SCAN_TICKS(80)) dut(
        .clk_50(clk),.enable(enable),.mode(mode),.user_in(input_pins),
        .user_out(pins),.extra1(e1),.extra2(e2),.pad2(pad2),.pad(pad),.autofire_hold(held));
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

    initial begin
        select_mode(1);
        snes_pressed=16'h0200; snes_p2=16'h0c00;
        scan();
        if(e1!==3'b001 || e2!==3'b110 || pad!==0 || pad2!==0) $fatal(1,"SNES X/L/R");
        snes_pressed=16'h0c00; snes_p2=16'h0200;
        scan();
        if(e1!==3'b110 || e2!==3'b001 || pad!==0 || pad2!==0) $fatal(1,"SNES P1/P2 independent");
        snes_pressed=0; snes_p2=0;
        scan();
        if(e1!==0 || e2!==0) $fatal(1,"SNES release");
        select_mode(2);
        md_extra_pressed=4'b0111;
        scan();
        if(e1!==7 || e2!==0) $fatal(1,"Mega Drive six-button extras: %b",e1);
        md_extra_pressed=0;
        scan();
        if(e1!==0) $fatal(1,"Mega Drive release");
        select_mode(3);
        sat_extra=4'b0111;
        scan();
        if(e1!==7 || e2!==0) $fatal(1,"Saturn extras: %b",e1);
        sat_extra=0;
        scan();
        if(e1!==0) $fatal(1,"Saturn release");
        $display("PASS extra SNAC actions on SNES P1/P2, Mega Drive and Saturn");
        $finish;
    end
endmodule
