// Test the production input mapping and the actual cabinet/ADC decode.
// CPU transactions are driven directly, so this test requires no program ROM.
module outrun_controls_tb;
    reg clk=0, rst=1, toggle_gear=0;
    always #5 clk=~clk;
    reg [31:0] buttons=0;
    wire [15:0] player;
    wire [3:0] start,coin;
    reg [2:0] control=0, channel=0, region=3;
    wire [23:1] address = {17'd0,region,3'd0};
    reg [15:0] analog_left=16'h4070, analog_right=16'hc081;
    jtframe_llapi_arcade_map #(.BUTTONS(4)) map(
        .buttons1(buttons), .buttons2(32'b0), .valid1(1'b1), .valid2(1'b0),
        .saturn1(1'b0), .saturn2(1'b0), .osd_active(1'b0),
        .usb1(16'b0), .usb2(16'b0), .joy1(player), .start(start), .coin(coin)
    );
    jtoutrun_main game(
        .clk(clk), .rst(rst), .joystick1(~player[7:0]), .joystick2(8'hff),
        .ctrl_type(control), .joyana1(analog_left), .joyana1b(analog_right),
        .coin(~coin[1:0]), .cab_1p(~start[1:0]), .gear_toggle(toggle_gear),
        .service(1'b1), .dip_test(1'b1), .gear_show(1'b1)
    );
    task check_adc(input [2:0] axis,input [7:0] wanted);
        begin region=3;channel=axis;#2;
            if(game.cab_dout!==wanted) $fatal(1,"control %d axis %d result %h expected %h",control,axis,game.cab_dout,wanted);
        end
    endtask
    task check_cab(input [7:0] mask,input [7:0] wanted);
        begin region=1;#2;
            if((game.cab_dout & mask)!==wanted) $fatal(1,"cabinet %h under %h expected %h",game.cab_dout,mask,wanted);
        end
    endtask
    initial begin
        force game.io_cs=1; force game.A=address;
        force game.adc_ch=channel;
        // These are clocked ADC samples. Keep the paired sticks live while checking the digital overrides.
        force game.dacana1=analog_left; force game.dacana1b=analog_right;
        repeat(3) @(negedge clk);rst=0;
        check_adc(0,8'hf0);
        buttons=1<<24;check_adc(0,8'he0); // Right
        buttons=1<<25;check_adc(0,8'h20); // Left
        buttons=0;check_adc(0,8'hf0);
        for(integer i=0;i<3;i=i+1) begin
            control=i;
            check_adc(1,i==0 ? 8'h7e : 8'h00);
            check_adc(2,i==0 ? 0 : i==1 ? 8'h81 : 8'h7e);
            buttons=1;check_adc(1,8'hff);  // Accelerate
            buttons=2;check_adc(2,8'hff);  // Brake
            buttons=3;check_adc(1,8'hff);check_adc(2,8'hff);
            buttons=0;check_adc(0,8'hf0);
        end
        buttons=4;check_cab(8'h10,0);       // Gear, hold-for-low setting
        buttons=0;check_cab(8'h10,8'h10);
        toggle_gear=1;repeat(2) @(negedge clk);check_cab(8'h10,0);
        buttons=4;repeat(3) @(negedge clk);check_cab(8'h10,8'h10);
        repeat(2) @(negedge clk);check_cab(8'h10,8'h10);
        buttons=0;repeat(2) @(negedge clk);buttons=4;repeat(2) @(negedge clk);check_cab(8'h10,0);
        buttons=8;check_cab(8'h28,8'h28);   // Turbo Out Run Nitro; Start remains released
        buttons=0;check_cab(8'h28,8'h08);
        buttons=1<<5;check_cab(8'h28,0);    // Start cannot request Nitro
        buttons=1<<4;check_cab(8'h40,0);    // Coin is a separate input
        $display("PASS Out Run / Turbo Out Run: wheel, both pedals, three analog configurations, hold/toggle gearbox, Nitro, separate Start and Coin.");
        $finish;
    end
endmodule
