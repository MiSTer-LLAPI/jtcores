`timescale 1ns/1ps
module timeout_adapter #(
    parameter integer REPLY_DELAY = 0,
    parameter integer POLL_WIDTH = 200,
    parameter integer REPORT_TYPE = 27,
    parameter bit MISSING_EDGE = 0,
    parameter integer FINAL_TAIL = 115
)(
    input clk, host_latch, host_data,
    output reg device_latch=1, device_data=1,
    output integer polls=0, reports=0, modes=0
);
    reg [7:0] packet[0:12];
    reg [7:0] opcode;
    initial begin
        for (integer i=0;i<13;i=i+1) packet[i]=0;
        packet[0] = 8'(REPORT_TYPE);
        packet[1] = 1;
        packet[12] = 8;
    end
    task ticks(input integer n);
        repeat(n) @(negedge clk);
    endtask
    task status_reply;
        device_latch=0; device_data=1; ticks(100);
        for (integer byte_index=0;byte_index<13;byte_index=byte_index+1) begin
            for (integer bit_index=0;bit_index<8;bit_index=bit_index+1) begin
                device_data=1; ticks(109);
                device_data=~packet[byte_index][bit_index];
                if (byte_index == 12 && bit_index == 7)
                    ticks(FINAL_TAIL);
                else
                    ticks(115);
            end
            if (byte_index != 12) begin
                device_data=1; ticks(49); device_data=0; ticks(50);
            end
        end
        device_latch=1; device_data=1;
    endtask
    initial forever begin
        @(negedge host_latch); ticks(251);
        for (integer bit_index=0;bit_index<8;bit_index=bit_index+1) begin
            opcode[bit_index]=~host_data;
            if (bit_index<7) ticks(224);
        end
        @(posedge host_latch); ticks(opcode==0 ? 100 : 600);
        case (opcode)
            8'h00: begin
                polls=polls+1;
                device_latch=0; device_data=0; ticks(POLL_WIDTH);
                device_latch=1; device_data=1;
            end
            8'h01: begin
                reports=reports+1;
                ticks(REPLY_DELAY); status_reply();
            end
            8'h21: modes=modes+1; // Preserve the last valid sample, but time out as before.
            default: $fatal(1,"Unexpected opcode %x",opcode);
        endcase
    end
endmodule

module verify_combo;
    parameter bit REPOLL_OFF=1;
    parameter integer FINAL_TAIL=123;
    parameter bit MISSING_EDGE=0;
    parameter bit EXPECT_P1_FIRE=1;
    parameter integer REPLY_DELAY=0;
    parameter integer REPORT_TYPE=27;
    parameter bit EXPECT_P1=1;
    parameter bit EXPECT_P2=1;
    reg clk=0, rst=1, enabled=0;
    always #10 clk=~clk;

    wire [6:0] user_out;
    wire a_latch,a_data,b_latch,b_data;
    wire [6:0] user_in = user_out & {1'b1,b_data,b_latch,2'b11,a_data,a_latch};
    wire [15:0] joy1, joy2;
    wire [1:0] connected;
    wire [19:0] guide;
    wire integer polls1,reports1,modes1,polls2,reports2,modes2;
    timeout_adapter #(.POLL_WIDTH(1310600),.REPLY_DELAY(REPLY_DELAY),.REPORT_TYPE(REPORT_TYPE),.MISSING_EDGE(MISSING_EDGE),.FINAL_TAIL(FINAL_TAIL)) a(
        .clk(clk),.host_latch(user_out[0]),.host_data(user_out[1]),
        .device_latch(a_latch),.device_data(a_data),.polls(polls1),.reports(reports1),.modes(modes1));
    timeout_adapter #(.FINAL_TAIL(160)) b(
        .clk(clk),.host_latch(user_out[4]),.host_data(user_out[5]),
        .device_latch(b_latch),.device_data(b_data),.polls(polls2),.reports(reports2),.modes(modes2));
    jtframe_llapi_arcade #(.BUTTONS(2)) dut(
        .clk_50(clk),.clk_sys(clk),.rst(rst),.vblank(1'b0),.osd_active(1'b0),.enable(enabled),.repoll_off(REPOLL_OFF),
        .user_in(user_in),.user_out(user_out),.usb1(16'd0),.usb2(16'd0),.joy1(joy1),.joy2(joy2),.connected(connected),
        .loss_resume(1'b0),.info_clk(clk),.controller_info(guide)
    );
    wire [1:0] baseline_out;
    wire [31:0] baseline_buttons;
    wire [71:0] baseline_analog;
    wire [7:0] baseline_type, baseline_modes;
    wire baseline_en, baseline_valid, baseline_update, baseline_fault;
    wire [1:0] baseline_reason;
    LLAPI_reference baseline (
        .CLK_50M(clk), .LLAPI_SYNC(1'b0), .REPOLL_OFF(dut.repoll_off_sync), .ENABLE(dut.u_port2.ENABLE),
        .IO_LATCH_IN(baseline_out[0] & b_latch), .IO_DATA_IN(baseline_out[1] & b_data),
        .IO_LATCH_OUT(baseline_out[0]), .IO_DATA_OUT(baseline_out[1]),
        .LLAPI_BUTTONS(baseline_buttons), .LLAPI_ANALOG(baseline_analog),
        .LLAPI_TYPE(baseline_type), .LLAPI_MODES(baseline_modes), .LLAPI_EN(baseline_en),
        .STATUS_VALID(baseline_valid), .STATUS_UPDATE(baseline_update), .LINK_FAULT(baseline_fault),
        .LAST_FAULT_REASON(baseline_reason)
    );
    always @(negedge clk) if (enabled) begin
        if ({baseline_out, baseline_buttons, baseline_analog, baseline_type, baseline_modes,
             baseline_en, baseline_valid, baseline_update, baseline_fault, baseline_reason} !==
            {user_out[5:4],dut.buttons2,dut.u_port2.LLAPI_ANALOG,dut.type2,dut.u_port2.LLAPI_MODES,
             dut.u_port2.LLAPI_EN,dut.valid2,dut.update2,dut.fault2,dut.last_fault2})
            $fatal(1,"P2 differed from the stock transport");
    end
    // READ_MODES occupies enum slot 6 in the transport. Compare the preceding
    // sample because the fault transition clears the stage and timer.
    reg [3:0] stage1=0,stage2=0;
    integer timer1=0,timer2=0;
    integer mode_faults1=0,mode_faults2=0;
    always @(negedge clk) begin
        if (dut.fault1 && stage1==6) begin
            mode_faults1=mode_faults1+1;
            if (timer1!=50000) $fatal(1,"P1 modes deadline moved to %d",timer1);
        end
        if (dut.fault2 && stage2==6) begin
            mode_faults2=mode_faults2+1;
            if (timer2!=50000) $fatal(1,"P2 modes deadline moved to %d",timer2);
        end
        stage1=dut.u_port1.enhanced.stage;
        stage2=dut.u_port2.enhanced.stage;
        timer1=dut.u_port1.enhanced.transaction_timer;
        timer2=dut.u_port2.enhanced.transaction_timer;
    end
    initial begin
        repeat(5) @(negedge clk);
        rst=0; enabled=1;
        repeat(2200000) @(negedge clk);
        #1;
        $display("delay=%d id=%02x attached=%b guide=%05x joy=%04x/%04x polls=%d/%d reports=%d/%d mode-timeouts=%d/%d",
            REPLY_DELAY,REPORT_TYPE,connected,guide,joy1,joy2,polls1,polls2,reports1,reports2,mode_faults1,mode_faults2);
        if (connected !== {EXPECT_P2,EXPECT_P1}) $fatal(1,"Unexpected connectivity");
        if (joy1[4] !== EXPECT_P1_FIRE || joy2 !== (EXPECT_P2?16'h10:16'h0))
            $fatal(1,"Unexpected button delivery");
        if (polls1<1 || polls2<1 || reports1<1 || reports2<1)
            $fatal(1,"Fixture missed a port's exchanges");
        if (mode_faults1 != ((EXPECT_P1 && REPORT_TYPE!=0)?1:0) || EXPECT_P2 && mode_faults2!=1)
            $fatal(1,"Expected exactly one ordinary modes timeout on valid ports");
        if (EXPECT_P1 && (dut.type1 != REPORT_TYPE || !dut.valid1))
            $fatal(1,"Unexpected P1 report type");
        if (EXPECT_P1 && REPORT_TYPE==0 && modes1!=0)
            $fatal(1,"Probe 0x21 should not be sent to the unknown ID");
        $finish;
    end
endmodule
