// Independent controller models drive USER pins. No internal state is forced.
module snac_wires_tb;
    reg clk=0, rst=1, vb=0;
    reg [2:0] mode=0;
    reg action1=0, start1=0, action2=0, start2=0;
    reg [6:0] pins=7'h7f;
    wire [6:0] outpins;
    wire [15:0] joy1,joy2;
    wire [3:0] start;
    wire menu;
    always #5 clk=~clk;
    jtframe_serial_arcade #(.BUTTONS(2)) dut(
        .clk_50(clk),.clk_sys(clk),.rst(rst),.vblank(vb),.osd_active(1'b0),
        .repoll_off(1'b0),.mode(mode),.usb1(16'd0),.usb2(16'd0),.user_in(pins),
        .user_out(outpins),.info_clk(clk),.autofire_enable(1'b0),.autofire_enable2(1'b0),
        .autofire_toggle(1'b0),.autofire_toggle2(1'b0),.autofire_rate1(2'd0),
        .autofire_rate2(2'd0),.loss_resume(1'b0),
        .joy1(joy1),.joy2(joy2),.start(start),.osd_request(menu));
    defparam dut.u_snac.TICK_CYCLES=5, dut.u_snac.SCAN_TICKS=42;

    // SNES clocks its serial bits on falling edges, NES on rising edges.
    reg [15:0] bits1=16'hffff,bits2=16'hffff;
    reg [6:0] prev=7'h7f;
    always @(negedge clk) begin
        prev<=outpins;
        if(outpins[0]) begin
            bits1<={12'hfff,!start1,2'b11,!action1};
            bits2<={12'hfff,!start2,2'b11,!action2};
        end else begin
            if((mode==4 && prev[1] && !outpins[1]) || (mode==6 && !prev[1] && outpins[1]))
               bits1<={1'b1,bits1[15:1]};
            if((mode==4 && prev[3] && !outpins[3]) || (mode==6 && !prev[3] && outpins[3]))
               bits2<={1'b1,bits2[15:1]};
        end
    end
    // Villena splitter data referenced to its external LOAD and CLK.
    reg [4:0] db_index=0;
    always @(posedge outpins[1]) begin
        if(!outpins[0]) db_index<=2;
        else db_index<=db_index+1'b1;
    end
    reg [3:0] nibble;
    reg [5:0] db9;
    always @* begin
        pins=7'h7f; nibble=4'hf; db9=6'h3f;
        case(mode)
            1: begin
                case({outpins[4],outpins[6]})
                    2'b10: nibble={!start1,2'b11,!action1};
                    2'b11: nibble=4'b1100;
                    default: nibble=4'hf;
                endcase
                {pins[3],pins[5],pins[0],pins[1]}=nibble;
            end
            2: begin
                db9=outpins[4] ? {1'b1,!action1,4'hf} : {!start1,1'b1,4'b0011};
                {pins[6],pins[2],pins[3],pins[5],pins[0],pins[1]}=db9;
            end
            3: case(db_index)
                5: pins[5]=!action1;
                17: pins[5]=!start1;
                21: pins[5]=!start2;
                25: pins[5]=!action2;
                default: pins[5]=1;
            endcase
            4,6: begin pins[5]=bits1[0]; pins[6]=bits2[0]; end
            5: begin
                nibble=outpins[2] ? 4'hf : {!start1,2'b11,!action1};
                {pins[3],pins[5],pins[0],pins[1]}=nibble;
            end
        endcase
    end
    task one_frame;
        begin
            repeat(mode==5 ? 9000 : 650) @(negedge clk);
            vb=1; repeat(5) @(negedge clk); vb=0;
            repeat(5) @(negedge clk);
        end
    endtask
    integer m,n,player,count1,count2;
    task gesture;
        integer j;
        begin
            for(j=0;j<3;j=j+1) begin
                if(player==1) start1=1; else start2=1;
                repeat(3) one_frame;
                if(start!==0 || menu!==0) $fatal(1,"start/OSD leak: %d, P%d",mode,player);
                start1=0; start2=0; repeat(3) one_frame;
            end
        end
    endtask
    task sample(input integer expected1,expected2);
        integer j;
        begin
            count1=0;count2=0;
            for(j=0;j<8;j=j+1) begin one_frame; count1=count1+joy1[4];count2=count2+joy2[4];end
            if(count1!==expected1 || count2!==expected2) $fatal(1,"mode %d, P%d: expected %d/%d got %d/%d",mode,player,expected1,expected2,count1,count2);
        end
    endtask
    initial begin
        repeat(10) @(negedge clk);rst=0;
        for(m=1;m<=6;m=m+1) begin
            mode=m; repeat(16000) @(negedge clk);
            player=1; action1=1; repeat(2) one_frame; sample(8,0);
            gesture; sample(4,0);
            if(m==3 || m==4 || m==6) begin
                player=2; action2=1; repeat(2) one_frame;sample(4,8);
                gesture; sample(4,4);
                action2=0; one_frame; sample(4,0);
                player=1;
            end
            gesture; sample(8,0); action1=0; one_frame; sample(0,0);
            $display("USER pins verified mode %d",m);
        end
        $display("PASS end-to-end physical pin simulations for all six SNAC modes");
        $finish;
    end
endmodule
