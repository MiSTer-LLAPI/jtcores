// SPDX-License-Identifier: GPL-3.0-or-later
// Optional digital SNAC readers for the 1943 LLAPI pilot.
// USER pin assignments follow MiSTer-devel SNES, Genesis and Saturn cores.
// Saturn nibble order also checked against Timothy Redaelli's joydb9saturn
// reader in MiSTer-DB9/jtcores; this is a single-port SNAC implementation.
module jtframe_serial_arcade #(parameter BUTTONS=3)(
    input clk_50,clk_sys,rst,vblank,osd_active,
    input [1:0] mode,
    input saturn_blissbox,
    input [6:0] user_in,
    output [6:0] user_out,
    input [15:0] usb1,usb2,
    output [15:0] joy1,joy2,
    output [3:0] start,coin,
    output osd_request
);
    (* async_reg="true" *) reg [2:0] mode_meta=0,mode50=0;
    reg [2:0] previous_mode=0;
    reg [12:0] settle=7500;
    wire ready50=(settle==0) && mode50==previous_mode;
    always @(posedge clk_50) begin
        mode_meta<={saturn_blissbox,mode}; mode50<=mode_meta;
        previous_mode<=mode50;
        if(mode50!=previous_mode) settle<=13'd7500; // 150 us released
        else if(settle!=0) settle<=settle-1'b1;
    end
    wire [6:0] llapi_out,snac_out;
    wire [15:0] llapi_joy1,llapi_joy2;
    wire [3:0] llapi_start,llapi_coin;
    wire llapi_osd;
    jtframe_llapi_arcade #(.BUTTONS(BUTTONS)) u_llapi(
        .clk_50(clk_50),.clk_sys(clk_sys),.rst(rst),.vblank(vblank),
        .enable(ready50 && mode50[1:0]==0),.osd_active(osd_active),
        .user_in(user_in),.user_out(llapi_out),.usb1(usb1),.usb2(usb2),
        .joy1(llapi_joy1),.joy2(llapi_joy2),.start(llapi_start),
        .coin(llapi_coin),.osd_request(llapi_osd));
    wire [8:0] snac_pad;
    jtframe_snac_arcade u_snac(.clk_50(clk_50),
        .enable(ready50 && mode50[1:0]!=0),.mode(mode50[1:0]),.saturn_blissbox(mode50[2]),
        .user_in(user_in),.user_out(snac_out),.pad(snac_pad));
    // Only one mux drives the physical connector. Inactive readers cannot
    // drive pins, and all pins are released while changing protocol.
    assign user_out=!ready50 ? 7'h7f : mode50[1:0]==0 ? llapi_out : snac_out;
    (* async_reg="true" *) reg [8:0] pad_meta=0,pad_sys=0;
    (* async_reg="true" *) reg [2:0] active_meta=0,active_sys=0;
    (* async_reg="true" *) reg ready_meta=0,ready_sys=0;
    always @(posedge clk_sys) begin
        pad_meta<=snac_pad; pad_sys<=pad_meta;
        active_meta<=mode50; active_sys<=active_meta;
        ready_meta<=ready50; ready_sys<=ready_meta;
    end
    wire stable=ready_sys && active_sys=={saturn_blissbox,mode};
    wire snac_selected=stable && active_sys[1:0]!=0;
    wire snac_menu=snac_selected && pad_sys[2] && pad_sys[7] && pad_sys[4];
    wire inhibit=osd_active || snac_menu;
    assign joy1=!stable ? usb1 : !snac_selected ? llapi_joy1 :
                 inhibit ? 16'd0 : {9'd0,pad_sys[6:0]};
    assign joy2=!stable ? usb2 : snac_selected ? usb1 : llapi_joy2;
    assign start=!stable ? 4'd0 : !snac_selected ? llapi_start :
                 {3'd0,pad_sys[7] && !pad_sys[8] && !inhibit};
    assign coin=!stable ? 4'd0 : !snac_selected ? llapi_coin :
                 {3'd0,pad_sys[8] && !inhibit};
    assign osd_request=stable && (snac_selected ? snac_menu : llapi_osd);
endmodule

module jtframe_snac_arcade #(
    parameter TICK_CYCLES=500, // 10 us at 50 MHz; shortened only in simulation
    parameter SCAN_TICKS=250  // 2.5 ms; allows MD six-button timeout to reset
)(
    input clk_50,enable,
    input [1:0] mode, // 1 SNES, 2 Mega Drive, 3 Saturn digital
    input saturn_blissbox, // requires the documented passive HDMI remapper
    input [6:0] user_in,
    output reg [6:0] user_out=7'h7f,
    // [8] coin, [7] start, [6:4] buttons, [3:0] UDLR, active high
    output reg [8:0] pad=0
);
    (* async_reg="true" *) reg [6:0] input_meta=7'h7f,input_sync=7'h7f;
    always @(posedge clk_50) begin input_meta<=user_in; input_sync<=input_meta; end
    reg [15:0] ticks=0;
    reg [8:0] phase=0;
    reg [2:0] old_mode=0;
    reg [15:0] snes=16'hffff;
    reg [5:0] md_high=6'h3f;
    reg [1:0] md_as=2'b11;
    reg md_valid=0,md_six=0;
    reg [3:0] md_extra=4'hf;
    reg [3:0] sat_extra=4'hf,sat_main=4'hf,sat_dir=4'hf;
    wire [5:0] md_in={input_sync[6],input_sync[2],input_sync[3],input_sync[5],input_sync[0],input_sync[1]}; // C B R L D U
    wire [3:0] sat_in=saturn_blissbox ? input_sync[3:0] : {input_sync[3],input_sync[5],input_sync[0],input_sync[1]}; // D3..D0
    always @(posedge clk_50) begin
        old_mode<={saturn_blissbox,mode};
        if(!enable || mode==0 || {saturn_blissbox,mode}!=old_mode) begin
            ticks<=0; phase<=0; user_out<=7'h7f; pad<=0;
            snes<=16'hffff; md_valid<=0; md_six<=0;
            md_high<=6'h3f; md_as<=2'b11; md_extra<=4'hf;
            sat_extra<=4'hf; sat_main<=4'hf; sat_dir<=4'hf;
        end else if(ticks==TICK_CYCLES-1) begin
            ticks<=0;
            phase<=phase==SCAN_TICKS-1 ? 0 : phase+1'b1;
            case(mode)
                1: begin
                    // SNES: latch=USER0, clock=USER1, serial data=USER5.
                    // Sample before each falling edge; controller advances
                    // on that edge, leaving a full period for the next bit.
                    if(phase==0 || phase==1) begin user_out<=7'h7f; snes<=16'hffff; end
                    if(phase==2) user_out[0]<=0;
                    if(phase>=3 && phase<=33 && phase[0]) begin
                        snes[(phase-3)>>1]<=input_sync[5]; user_out[1]<=0;
                    end
                    if(phase>=4 && phase<=34 && !phase[0]) user_out[1]<=1;
                    if(phase==35) begin
                        if(snes[15:12]==4'hf)
                            pad<={~snes[2],~snes[3],~snes[1],~snes[8],~snes[0],~snes[4],~snes[5],~snes[6],~snes[7]};
                        else pad<=0;
                    end
                end
                2: begin
                    // Mega Drive: TH=USER4. Other pins remain released inputs.
                    case(phase)
                        0: begin user_out<=7'h6f; md_six<=0; md_extra<=4'hf; end
                        1: user_out[4]<=1;
                        2: begin md_high<=md_in; user_out[4]<=0; end
                        3: begin md_as<=md_in[5:4]; md_valid<=(md_in[3:2]==0); user_out[4]<=1; end
                        4: user_out[4]<=0;
                        5: begin md_six<=(md_in[3:0]==0); user_out[4]<=1; end
                        6: begin md_extra<=md_in[3:0]; user_out[4]<=0; end
                        7: begin
                            user_out[4]<=1;
                            if(md_valid) begin
                                pad[3:0]<=~{md_high[0],md_high[1],md_high[2],md_high[3]};
                                pad[6:4]<=~{md_high[5],md_as[0],md_high[4]}; // C,A,B => buttons 3,2,1
                                pad[7]<=~md_as[1];
                                // Mode on a 6-button pad; Down+Start also
                                // works on a 3-button pad (consumes Start).
                                pad[8]<=(md_six && !md_extra[3]) || (!md_high[1] && !md_as[1]);
                            end else pad<=0;
                        end
                    endcase
                end
                3: begin
                    // Saturn digital: TH=USER4, TR=USER6; D3..0 use
                    // USER3,5,0,1. TL/USER2 is released (input).
                    // Bliss-Box + passive remapper: TH=USER6, TR=USER4,
                    // D3..0=USER3..0, TL/USER5 remains released.
                    case(phase)
                        0: user_out<=7'h2f; // TH=0, TR=0 in either supported layout
                        1: begin sat_extra<=sat_in; user_out[saturn_blissbox ? 6 : 4]<=1; end
                        2: begin sat_main<=sat_in; user_out[saturn_blissbox ? 6 : 4]<=0; user_out[saturn_blissbox ? 4 : 6]<=1; end
                        3: begin sat_dir<=sat_in; user_out[saturn_blissbox ? 6 : 4]<=1; end
                        4: begin
                            // Digital pad ID: final phase is {L,1,0,0}.
                            // Reject an analog-handshake pad instead of
                            // retaining stale data or inventing button presses.
                            if(sat_in[2:0]==3'b100) begin
                                pad[3:0]<=~{sat_dir[0],sat_dir[1],sat_dir[2],sat_dir[3]};
                                pad[6:4]<=~{sat_main[2],sat_main[1],sat_main[0]}; // A,C,B
                                pad[7]<=~sat_main[3];
                                pad[8]<=~sat_in[3]; // L inserts coin
                            end else pad<=0;
                        end
                    endcase
                end
            endcase
        end else ticks<=ticks+1'b1;
    end
endmodule
