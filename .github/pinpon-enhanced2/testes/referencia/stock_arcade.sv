// SPDX-License-Identifier: GPL-3.0-or-later
// Experimental JTFRAME bridge for the MiSTer-LLAPI arcade protocol.
// Protocol implementation and arcade button IDs originate in
// MiSTer-LLAPI/Arcade-IremM62_MiSTer, commit 4d637039.
module jtframe_llapi_arcade_stock #(
    parameter BUTTONS=3, LOSS_MS=1000
)(
    input clk_50, clk_sys, rst, vblank, osd_active, enable, repoll_off,
    input [6:0] user_in,
    output logic [6:0] user_out,
    input [15:0] usb1, usb2,
    output [15:0] joy1, joy2,
    output [3:0] start, coin,
    output osd_request,
    output [1:0] autofire_hold,
    output [1:0] connected
`ifdef JTFRAME_ENHANCED_CONTROLS
    ,input loss_resume
    ,output loss_paused
    ,output [1:0] loss_players
    ,output [1:0] loss_countdown
    ,input info_clk
    ,output [19:0] controller_info
    ,output [7:0] link_diagnostics
`ifdef JTFRAME_LLAPI_POLL_DIAG
    ,output [63:0] poll_timing_us
`endif
    ,output [3:0] last_fault_reason
    ,output [1:0] type_changed
`endif
);
    wire [31:0] buttons1, buttons2;
    wire [7:0] type1,type2;
    wire en1,en2,latch1,data1,latch2,data2;
    wire update1,update2,fault1,fault2;
`ifdef JTFRAME_ENHANCED_CONTROLS
    wire [1:0] changed50;
    wire [1:0] last_fault1,last_fault2;
`ifdef JTFRAME_LLAPI_POLL_DIAG
    wire [63:0] timing50;
`endif
`endif
    (* async_reg="true" *) reg rst50_meta=1, rst50_sync=1;
    (* async_reg="true" *) reg osd50_meta=0, osd50_sync=0;
    reg seen1=0,seen2=0;
    wire valid1;
    wire valid2;
    reg repoll_off_meta = 0, repoll_off_sync = 0;
    always @(posedge clk_50) begin
        repoll_off_meta <= repoll_off;
        repoll_off_sync <= repoll_off_meta;
    end

    always @(posedge clk_50) begin
        rst50_meta<=rst; rst50_sync<=rst50_meta;
        osd50_meta<=osd_active; osd50_sync<=osd50_meta;
        if(rst50_sync) begin seen1<=0; seen2<=0; end
        else begin
            if(en1 && type1!=8'hff && |buttons1) seen1<=1;
            if(en2 && type2!=8'hff && |buttons2) seen2<=1;
        end
    end
    // Same physical USER port wiring and enable polarity as the arcade cores.
    always_comb begin
        user_out=7'h7f;
        user_out[0]=latch1; user_out[1]=data1;
        user_out[2]=osd50_sync;
        user_out[4]=latch2; user_out[5]=data2;
    end
    LLAPI u_port1(.CLK_50M(clk_50),.LLAPI_SYNC(vblank),.REPOLL_OFF(repoll_off_sync),
        .IO_LATCH_IN(user_in[0]),.IO_LATCH_OUT(latch1),
        .IO_DATA_IN(user_in[1]),.IO_DATA_OUT(data1),.ENABLE(enable && ~osd50_sync),
        .LLAPI_BUTTONS(buttons1),.LLAPI_ANALOG(),.LLAPI_TYPE(type1),
        .LLAPI_MODES(),.LLAPI_EN(en1),.STATUS_VALID(valid1),.STATUS_UPDATE(update1),.LINK_FAULT(fault1)
`ifdef JTFRAME_ENHANCED_CONTROLS
        ,.TYPE_CHANGED(changed50[0]),.LAST_FAULT_REASON(last_fault1)
`ifdef JTFRAME_LLAPI_POLL_DIAG
        ,.poll_timing_us(timing50)
`endif
`endif
    );
    LLAPI u_port2(.CLK_50M(clk_50),.LLAPI_SYNC(vblank),.REPOLL_OFF(repoll_off_sync),
        .IO_LATCH_IN(user_in[4]),.IO_LATCH_OUT(latch2),
        .IO_DATA_IN(user_in[5]),.IO_DATA_OUT(data2),.ENABLE(enable && ~osd50_sync),
        .LLAPI_BUTTONS(buttons2),.LLAPI_ANALOG(),.LLAPI_TYPE(type2),
        .LLAPI_MODES(),.LLAPI_EN(en2),.STATUS_VALID(valid2),.STATUS_UPDATE(update2),.LINK_FAULT(fault2)
`ifdef JTFRAME_ENHANCED_CONTROLS
        ,.TYPE_CHANGED(changed50[1]),.LAST_FAULT_REASON(last_fault2)
`endif
    );
`ifdef JTFRAME_ENHANCED_CONTROLS
    (* async_reg="true" *) reg resume_meta=0,resume_sync=0;
    reg resume_old=0;
    always @(posedge clk_50) begin
        resume_meta<=loss_resume; resume_sync<=resume_meta; resume_old<=resume_sync;
    end
    // ID changes are separated by at least one full serial status transaction.
    // Toggle each bit so even a single 50 MHz strobe reaches the game clock.
    reg [1:0] change_toggle=0,change_previous=0;
    (* async_reg="true" *) reg [1:0] change_meta=0,change_sync=0;
    always @(posedge clk_50) begin
        if(rst50_sync) change_toggle<=0;
        else change_toggle<=change_toggle ^ changed50;
    end
    always @(posedge clk_sys) begin
        if(rst) begin change_meta<=0;change_sync<=0;change_previous<=0;end
        else begin
            change_meta<=change_toggle;
            change_sync<=change_meta;
            change_previous<=change_sync;
        end
    end
    assign type_changed=change_sync ^ change_previous;
    wire loss50;
    wire [1:0] countdown50;
    wire [1:0] lost_ports,rediscover_unused;
    controller_loss_clocked #(.LOSS_MS(LOSS_MS)) loss_policy(
        .clk(clk_50),.rst(rst50_sync),.enable(enable),.observe(!osd50_sync),
        .resume(resume_sync ^ resume_old),.connected({valid2,valid1}),
        .paused(loss50),.countdown(countdown50),.lost(lost_ports),.rediscover(rediscover_unused));
    // Bundled mailbox: source holds all three state bits until destination acknowledges.
    reg [4:0] loss_mailbox=0;
    reg loss_request=0,loss_ack=0;
    (* async_reg="true" *) reg ack_meta=0,ack_sync=0,req_meta=0,req_sync=0;
    reg [4:0] loss_snapshot=0;
    always @(posedge clk_50) begin
        ack_meta<=loss_ack;ack_sync<=ack_meta;
        if(rst50_sync) begin loss_mailbox<=0;loss_request<=0;ack_meta<=0;ack_sync<=0;end
        else if(loss_request==ack_sync && loss_mailbox!={lost_ports,loss50,countdown50}) begin
            loss_mailbox<={lost_ports,loss50,countdown50};loss_request<=~loss_request;
        end
    end
    always @(posedge clk_sys) begin
        req_meta<=loss_request;req_sync<=req_meta;
        if(rst) begin req_meta<=0;req_sync<=0;loss_ack<=0;loss_snapshot<=0;end
        else if(req_sync!=loss_ack) begin loss_snapshot<=loss_mailbox;loss_ack<=req_sync;end
    end
    assign loss_players=loss_snapshot[4:3];
    assign loss_paused=loss_snapshot[2];
    assign loss_countdown=loss_snapshot[1:0];
`endif
    // Button levels are slow asynchronous inputs, not a streamed data bus.
    // Constrain only the first sampling stages; retain timing between stages.
    (* async_reg="true" *) reg [31:0] buttons1_meta=0,buttons1_sync=0;
    (* async_reg="true" *) reg [31:0] buttons2_meta=0,buttons2_sync=0;
    (* async_reg="true" *) reg valid1_meta=0,valid1_sync=0;
    (* async_reg="true" *) reg valid2_meta=0,valid2_sync=0;
    (* async_reg="true" *) reg saturn1_meta=0,saturn1_sync=0,saturn2_meta=0,saturn2_sync=0;
    always @(posedge clk_sys) begin
        if(rst) begin
            saturn1_meta<=0;saturn1_sync<=0;saturn2_meta<=0;saturn2_sync<=0;
            buttons1_meta<=0; buttons1_sync<=0;
            buttons2_meta<=0; buttons2_sync<=0;
            valid1_meta<=0; valid1_sync<=0;
            valid2_meta<=0; valid2_sync<=0;
        end else begin
            saturn1_meta<=valid1 && type1==8'd3;saturn1_sync<=saturn1_meta;
            saturn2_meta<=valid2 && type2==8'd3;saturn2_sync<=saturn2_meta;
            buttons1_meta<=buttons1; buttons1_sync<=buttons1_meta;
            buttons2_meta<=buttons2; buttons2_sync<=buttons2_meta;
            valid1_meta<=valid1; valid1_sync<=valid1_meta;
            valid2_meta<=valid2; valid2_sync<=valid2_meta;
        end
    end
assign connected={valid2_sync,valid1_sync};
`ifdef JTFRAME_ENHANCED_CONTROLS
    // Freeze on the same synchronized OSD signal that disables transport.
    // Driver nonblocking reset cannot erase the preceding captured identity.
    llapi_link_diagnostics u_link_diagnostics(
        .clk(clk_50),.dst_clk(info_clk),.rst(rst50_sync),
        .observe(enable && !osd50_sync),.updates({update2,update1}),
        .faults({fault2,fault1}),.reasons({last_fault2,last_fault1}),
`ifdef JTFRAME_LLAPI_POLL_DIAG
        .timing_us(timing50),.timing_snapshot(poll_timing_us),
`endif
        .snapshot(link_diagnostics),.last_fault(last_fault_reason));
    controller_info_snapshot u_controller_info(
        .src_clk(clk_50),.dst_clk(info_clk),.rst(rst),
        .freeze(osd50_sync),.observe(enable),
        .connected({valid2,valid1}),.type_a(type1),.type_b(type2),
        .snapshot(controller_info));
`endif

`ifdef JTFRAME_LLAPI_HOLD_AUTOFIRE
    // Bit3 is unused by the existing arcade map (bits0..2 are game buttons).
    // Current SNES reference maps it to X; Genesis six-button maps it to Y.
    // Keep the already-tested bit2 autofire alias only in two-button cores.
    assign autofire_hold={valid2_sync && (buttons2_sync[3] || (BUTTONS<3 && buttons2_sync[2])),
                          valid1_sync && (buttons1_sync[3] || (BUTTONS<3 && buttons1_sync[2]))};
`else
    assign autofire_hold=0;
`endif
    jtframe_llapi_arcade_map #(.BUTTONS(BUTTONS)) u_map(
        .buttons1(buttons1_sync),.buttons2(buttons2_sync),
        .saturn1(saturn1_sync),.saturn2(saturn2_sync),
        .valid1(valid1_sync),.valid2(valid2_sync),.osd_active(osd_active),
        .usb1(usb1),.usb2(usb2),.joy1(joy1),.joy2(joy2),
        .start(start),.coin(coin),.osd_request(osd_request));
endmodule

