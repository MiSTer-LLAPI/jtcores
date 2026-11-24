module rotary_guide_tb;
    reg [2:0] mode;
    reg [7:0] original;
    wire [7:0] rendered;
    enhanced_info_byte guide(.original(original), .info(20'h0), .rendered(rendered),
        .mode(mode), .diagnostics(8'h0), .af(2'h0), .last_fault(4'h0));
    task row(input [2:0] port_mode, input integer num, input [191:0] expected);
        integer col;
        begin
            mode=port_mode;
            for(col=0;col<24;col=col+1) begin
                original=160+num*24+col;
                #1;
                if(rendered!==expected[191-col*8 -:8])
                    $fatal(1,"Mode %d row %d column %d: got %x", mode,num,col,rendered);
            end
        end
    endtask
    initial begin
        row(1,0,"B: Shoot  C: Grenade    ");
        row(2,2,"MD6: C/Z Turn  X: AF    ");
        row(3,1,"C/D: Turn left/right    ");
        row(4,1,"L/R: Turn left/right    ");
        row(5,1,"Turn: Start+Left/Right  ");
        row(6,0,"A: Shoot  B: Grenade    ");
        $display("PASS physical SNAC mode-specific guide");
        $finish;
    end
endmodule
