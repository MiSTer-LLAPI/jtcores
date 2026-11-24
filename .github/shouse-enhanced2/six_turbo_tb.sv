// Test all physical input modes at the synchronized reader output.
// Dedicated LLAPI Hold and speed tests run separately in autofire_tb.
module six_turbo_tb;
    reg clk=0, rst=1, vb=0, osd=0;
    reg [2:0] mode=0;
    reg [8:0] p1=0, p2=0;
    reg [2:0] extra1=0, extra2=0;
    wire [15:0] joy1,joy2;
    wire [3:0] start,coin;
    wire menu;
    always #5 clk=~clk;
    jtframe_serial_arcade #(.BUTTONS(6)) dut(
        .clk_50(clk),.clk_sys(clk),.rst(rst),.vblank(vb),.osd_active(osd),
        .repoll_off(1'b0),.mode(mode),.usb1(16'h08),.usb2(16'h04),.user_in(7'h7f),
        .info_clk(clk),.autofire_enable(1'b0),.autofire_enable2(1'b0),
        .autofire_toggle(1'b0),.autofire_toggle2(1'b0),.autofire_rate1(2'd0),
        .autofire_rate2(2'd0),.loss_resume(1'b0),
        .joy1(joy1),.joy2(joy2),.start(start),.coin(coin),.osd_request(menu));
    task settle; repeat(8) @(negedge clk); endtask
    task frame; begin vb=1; settle; vb=0; settle; end endtask
    task change_mode(input [2:0] value);
        begin mode=value; repeat(7600) @(negedge clk); end
    endtask
    task tap(input integer player);
        begin
            if(player==1) p1[7]=1; else p2[7]=1;
            repeat(3) frame;
            if (start[player-1] || menu) $fatal(1,"Shortcut leaked to game/OSD: mode %d player %d",mode,player);
            if(player==1) p1[7]=0; else p2[7]=0;
            repeat(3) frame;
        end
    endtask
    task check_button(input integer player, bit_num, expected_on);
        integer n,count;
        begin
            count=0;
            for(n=0;n<12;n=n+1) begin
                frame;
                if (player==1) count=count+joy1[bit_num];
                else count=count+joy2[bit_num];
            end
            if (count!==expected_on) $fatal(1,"mode %d player %d bit %d expected %d on, got %d",mode,player,bit_num,expected_on,count);
        end
    endtask
    integer i,b;
    initial begin
        force dut.port1=p1;
        force dut.port2=p2;
        force dut.extra1_sys=extra1;
        force dut.extra2_sys=extra2;
        settle; rst=0;
        for(i=1;i<=6;i=i+1) begin
            change_mode(i);
            p1[7]=1; settle;
            if(start!==1) $fatal(1,"ordinary Start: mode %d",i);
            p1=0; extra1=0; settle;
            for(b=4;b<=(i>=5 ? 5 : 9);b=b+1) begin
                if(b<=6) p1[b]=1; else extra1[b-7]=1; settle;
                repeat(2) tap(1);
                check_button(1,b,12);
                tap(1);
                check_button(1,b,6);
                if(i==3 || i==4 || i==6) begin
                    if(b<=6) p2[b]=1; else extra2[b-7]=1; settle;
                    check_button(2,b,12);
                    repeat(3) tap(2);
                    check_button(2,b,6);
                    p2=0; extra2=0; settle;
                    check_button(2,b,0);
                end else if(joy2!==8) $fatal(1,"P2 USB altered in 1P mode");
                osd=1; settle;
                if(joy1!==0) $fatal(1,"OSD input leak");
                osd=0; settle;
                check_button(1,b,6);
                p1=0; extra1=0; settle;
                check_button(1,b,0);
                if(b<=6) p1[b]=1; else extra1[b-7]=1; settle;
                repeat(3) tap(1);
                check_button(1,b,12);
                p1=0; extra1=0; settle;
            end
            if(i==3) begin
                p1='hc0; settle; if(!menu) $fatal(1,"DB15 original chord");
                p1=0; extra1=0; settle; p1='h40; settle; p1='hc0; repeat(36) frame;
                if(!menu) $fatal(1,"DB15 long chord with button first");
            end else begin
                p1='h94; settle; if(!menu) $fatal(1,"directional OSD chord");
            end
            p1=0; extra1=0; settle;
            p1='h100; settle; if(!coin[0]) $fatal(1,"coin");
            p1='h10; settle; repeat(3) tap(1); check_button(1,4,6);
            p1=0; extra1=0; settle;
            change_mode(0);
            p1='h90; settle; if(joy1!==8 || start!==0 || menu) $fatal(1,"SNAC altered LLAPI or USB");
            p1=0; extra1=0; settle;
        end
        change_mode(4); p1='h10; settle; check_button(1,4,12);
        // Bounced or interrupted presses cannot finish a triple tap.
        repeat(2) tap(1); p1='h20; settle; p1='h10; settle;
        p1[7]=1; frame; p1[7]=0; repeat(3) frame;
        repeat(2) tap(1); check_button(1,4,12);
        tap(1); check_button(1,4,6);
        rst=1; settle; rst=0; settle; check_button(1,4,12);
        $display("PASS: Six manual punches/kicks and individual SNAC per-button toggle on/off, 6 interfaces, independent P1/P2, USB/LLAPI passthrough, OSD/coin/Start, release, bounce, reset and mode changes");
        $finish;
    end
endmodule
