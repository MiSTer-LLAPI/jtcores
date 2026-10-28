// SPDX-License-Identifier: GPL-3.0-or-later
// Experimental JTFRAME bridge for the MiSTer-LLAPI arcade protocol.
// Protocol implementation and arcade button IDs originate in
// MiSTer-LLAPI/Arcade-IremM62_MiSTer, commit 4d637039.
module jtframe_llapi_arcade #(
    parameter BUTTONS=3
)(
    input clk_50, clk_sys, rst, vblank, osd_active,
    input [6:0] user_in,
    output logic [6:0] user_out,
    input [15:0] usb1, usb2,
    output [15:0] joy1, joy2,
    output [3:0] start, coin,
    output osd_request
);
    wire [31:0] buttons1, buttons2;
    wire [7:0] type1,type2;
    wire en1,en2,latch1,data1,latch2,data2;
    (* async_reg="true" *) reg rst50_meta=1, rst50_sync=1;
    (* async_reg="true" *) reg osd50_meta=0, osd50_sync=0;
    reg seen1=0,seen2=0;
    wire valid1=en1 && type1!=8'hff && (type1!=0 || seen1);
    wire valid2=en2 && type2!=8'hff && (type2!=0 || seen2);
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
    LLAPI u_port1(.CLK_50M(clk_50),.LLAPI_SYNC(vblank),
        .IO_LATCH_IN(user_in[0]),.IO_LATCH_OUT(latch1),
        .IO_DATA_IN(user_in[1]),.IO_DATA_OUT(data1),.ENABLE(~osd50_sync),
        .LLAPI_BUTTONS(buttons1),.LLAPI_ANALOG(),.LLAPI_TYPE(type1),
        .LLAPI_MODES(),.LLAPI_EN(en1));
    LLAPI u_port2(.CLK_50M(clk_50),.LLAPI_SYNC(vblank),
        .IO_LATCH_IN(user_in[4]),.IO_LATCH_OUT(latch2),
        .IO_DATA_IN(user_in[5]),.IO_DATA_OUT(data2),.ENABLE(~osd50_sync),
        .LLAPI_BUTTONS(buttons2),.LLAPI_ANALOG(),.LLAPI_TYPE(type2),
        .LLAPI_MODES(),.LLAPI_EN(en2));
    // Button levels are slow asynchronous inputs, not a streamed data bus.
    // Constrain only the first sampling stages; retain timing between stages.
    (* async_reg="true" *) reg [31:0] buttons1_meta=0,buttons1_sync=0;
    (* async_reg="true" *) reg [31:0] buttons2_meta=0,buttons2_sync=0;
    (* async_reg="true" *) reg valid1_meta=0,valid1_sync=0;
    (* async_reg="true" *) reg valid2_meta=0,valid2_sync=0;
    always @(posedge clk_sys) begin
        if(rst) begin
            buttons1_meta<=0; buttons1_sync<=0;
            buttons2_meta<=0; buttons2_sync<=0;
            valid1_meta<=0; valid1_sync<=0;
            valid2_meta<=0; valid2_sync<=0;
        end else begin
            buttons1_meta<=buttons1; buttons1_sync<=buttons1_meta;
            buttons2_meta<=buttons2; buttons2_sync<=buttons2_meta;
            valid1_meta<=valid1; valid1_sync<=valid1_meta;
            valid2_meta<=valid2; valid2_sync<=valid2_meta;
        end
    end
    jtframe_llapi_arcade_map #(.BUTTONS(BUTTONS)) u_map(
        .buttons1(buttons1_sync),.buttons2(buttons2_sync),
        .valid1(valid1_sync),.valid2(valid2_sync),.osd_active(osd_active),
        .usb1(usb1),.usb2(usb2),.joy1(joy1),.joy2(joy2),
        .start(start),.coin(coin),.osd_request(osd_request));
endmodule

module jtframe_llapi_arcade_map #(parameter BUTTONS=3)(
    input [31:0] buttons1,buttons2,
    input valid1,valid2,osd_active,
    input [15:0] usb1,usb2,
    output [15:0] joy1,joy2,
    output [3:0] start,coin,
    output osd_request
);
    wire [31:0] p1=valid1 ? buttons1 : 32'd0;
    wire [31:0] p2=valid2 ? buttons2 : 32'd0;
    assign osd_request=(p1[26]&p1[5]&p1[0]) | (p2[26]&p2[5]&p2[0]);
    wire inhibit=osd_active | osd_request;
    function automatic [15:0] game_buttons(input [31:0] p);
        integer n;
        begin
            game_buttons=0;
            game_buttons[3:0]=p[27:24]; // up, down, left, right
            for(n=0;n<3;n=n+1)
                if(n<BUTTONS) game_buttons[4+n]=p[n];
        end
    endfunction
    // Preserve the existing arcade allocation: one LLAPI socket reserves
    // its player slot; USB player 1 fills the other slot.
    assign joy1=valid1 ? (inhibit ? 16'd0 : game_buttons(p1)) : usb1;
    assign joy2=valid2 ? (inhibit ? 16'd0 : game_buttons(p2)) :
                         (valid1 ? usb1 : usb2);
    // Arcade convention: button 5 starts P1 and button 6 starts P2,
    // from either socket. Button 4 is that socket's coin input.
    assign start=inhibit ? 4'd0 : {2'b0,p1[6]|p2[6],p1[5]|p2[5]};
    assign coin=inhibit ? 4'd0 : {2'b0,p2[4],p1[4]};
endmodule
