// SPDX-License-Identifier: GPL-3.0-or-later
// Optional digital SNAC readers for the 1943 LLAPI pilot.
// USER pin assignments follow MiSTer-devel SNES, Genesis and Saturn cores.
// Saturn nibble order also checked against Timothy Redaelli's joydb9saturn
// reader in MiSTer-DB9/jtcores; this is a single-port SNAC implementation.
module jtframe_serial_arcade_stock #(parameter BUTTONS=3)(
    input clk_50,clk_sys,rst,vblank,osd_active,repoll_off,
    input autofire_enable,autofire_toggle,
`ifdef JTFRAME_ENHANCED_CONTROLS
    input autofire_enable2,autofire_toggle2,
    input [1:0] autofire_rate1,autofire_rate2,
    input loss_resume,
    output loss_paused,
    output [1:0] loss_players,
    output [1:0] loss_countdown,
    input info_clk,
    output [19:0] controller_info,
    output [7:0] link_diagnostics,
`ifdef JTFRAME_LLAPI_POLL_DIAG
    output [63:0] poll_timing_us,
`endif
    output [3:0] last_fault_reason,
`endif
    input [2:0] mode, // 0 LLAPI, 1 Saturn, 2 SEGA, 3 original DB15, 4 SNES, 5 PCE 2-button, 6 NES
    input [6:0] user_in,
    output [6:0] user_out,
    input [15:0] usb1,usb2,
    output [15:0] joy1,joy2,
    output [3:0] start,coin,
    output db15_drive,
    output osd_request
);
    (* async_reg="true" *) reg [2:0] mode_meta=0,mode50=0;
    reg [2:0] previous_mode=0;
    reg [12:0] settle=7500;
    wire ready50=(settle==0) && mode50==previous_mode;
    always @(posedge clk_50) begin
        mode_meta<=mode; mode50<=mode_meta;
        previous_mode<=mode50;
        if(mode50!=previous_mode) settle<=13'd7500; // 150 us released
        else if(settle!=0) settle<=settle-1'b1;
    end
    wire [6:0] llapi_out,snac_out;
    wire [15:0] llapi_joy1,llapi_joy2;
    wire [3:0] llapi_start,llapi_coin;
    wire llapi_osd;
    wire [1:0] llapi_af,snac_af,llapi_connected;
`ifdef JTFRAME_ENHANCED_CONTROLS
    wire [1:0] llapi_type_changed;
`endif
    jtframe_llapi_arcade_stock #(.BUTTONS(BUTTONS)) u_llapi(.repoll_off(repoll_off),
        .clk_50(clk_50),.clk_sys(clk_sys),.rst(rst),.vblank(vblank),
        .enable(ready50 && mode50==0),.osd_active(osd_active),
        .user_in(user_in),.user_out(llapi_out),.usb1(usb1),.usb2(usb2),
        .joy1(llapi_joy1),.joy2(llapi_joy2),.start(llapi_start),
        .coin(llapi_coin),.osd_request(llapi_osd),.autofire_hold(llapi_af),.connected(llapi_connected)
`ifdef JTFRAME_ENHANCED_CONTROLS
        ,.loss_resume(loss_resume),.loss_paused(loss_paused),.loss_countdown(loss_countdown),.loss_players(loss_players),.info_clk(info_clk),.controller_info(controller_info),.link_diagnostics(link_diagnostics)
`ifdef JTFRAME_LLAPI_POLL_DIAG
        ,.poll_timing_us(poll_timing_us)
`endif
        ,.last_fault_reason(last_fault_reason),.type_changed(llapi_type_changed)
`endif
    );
    wire [8:0] snac_pad,snac_pad2;
    wire [2:0] reader_mode=mode50==1 ? 3 : mode50==2 ? 2 : mode50==4 ? 1 : mode50==5 ? 4 : mode50==6 ? 5 : 0;
    jtframe_snac_arcade #(.BUTTONS(BUTTONS)) u_snac(.clk_50(clk_50),
        .enable(ready50 && reader_mode!=0),.mode(reader_mode),
        .user_in(user_in),.user_out(snac_out),.pad(snac_pad),.pad2(snac_pad2),.autofire_hold(snac_af));
    // Only one mux drives the physical connector. Inactive readers cannot
    // drive pins, and all pins are released while changing protocol.
    assign db15_drive=ready50 && mode50==3;
    wire db_clk,db_load;
    wire [15:0] db1,db2;
    // Preserve Jotego's original Antonio Villena DB15 splitter reader.
    joy_db15 u_db15(.clk(clk_50),.JOY_CLK(db_clk),.JOY_LOAD(db_load),
        .JOY_DATA(user_in[5]),.joystick1(db1),.joystick2(db2));
    wire [8:0] port1=mode50==3 ? {db1[11:10],db1[6:0]} : snac_pad;
    wire [8:0] port2=mode50==3 ? {db2[11:10],db2[6:0]} : (mode50==4 || mode50==6) ? snac_pad2 : 9'd0;
    assign user_out=!ready50 ? 7'h7f : mode50==0 ? llapi_out :
                    mode50==3 ? {5'h1f,db_clk,db_load} : snac_out;
    (* async_reg="true" *) reg [8:0] pad_meta=0,pad_sys=0,pad2_meta=0,pad2_sys=0;
    (* async_reg="true" *) reg [2:0] active_meta=0,active_sys=0;
    (* async_reg="true" *) reg ready_meta=0,ready_sys=0;
    always @(posedge clk_sys) begin
        pad_meta<=port1; pad_sys<=pad_meta;
        pad2_meta<=port2; pad2_sys<=pad2_meta;
        active_meta<=mode50; active_sys<=active_meta;
        ready_meta<=ready50; ready_sys<=ready_meta;
    end
    wire stable=ready_sys && active_sys==mode;
    wire snac_selected=stable && active_sys!=0 && active_sys<=6;
    wire db15_selected=stable && active_sys==3;
    wire dual_snac=stable && (active_sys==3 || active_sys==4 || active_sys==6);
    wire snac_menu=snac_selected && (db15_selected ?
        ((pad_sys[7] && pad_sys[6]) || (pad2_sys[7] && pad2_sys[6])) :
        ((pad_sys[2] && pad_sys[7] && pad_sys[4]) ||
         ((active_sys==4 || active_sys==6) && pad2_sys[2] && pad2_sys[7] && pad2_sys[4])));
    wire inhibit=osd_active || snac_menu;
    wire [15:0] raw_joy1,raw_joy2;
    assign raw_joy1=!stable ? usb1 : !snac_selected ? llapi_joy1 :
                 inhibit ? 16'd0 : {9'd0,pad_sys[6:0]};
    assign raw_joy2=!stable ? usb2 : dual_snac ?
                 (inhibit ? 16'd0 : {9'd0,pad2_sys[6:0]}) :
                 snac_selected ? usb1 : llapi_joy2;
`ifdef JTFRAME_LLAPI_HOLD_AUTOFIRE
    (* async_reg="true" *) reg [1:0] snac_af_meta=0,snac_af_sys=0;
    (* async_reg="true" *) reg vb_meta=0,vb_sync=0;
    always @(posedge clk_sys) begin
        snac_af_meta<=snac_af;snac_af_sys<=snac_af_meta;
        vb_meta<=vblank;vb_sync<=vb_meta;
    end
    wire [1:0] db_af={db2[7],db1[7]};
    (* async_reg="true" *) reg [1:0] db_af_meta=0,db_af_sys=0;
    always @(posedge clk_sys) begin db_af_meta<=db_af;db_af_sys<=db_af_meta;end
    // Two-button SNAC pads have no spare autofire control. Never consume manual fire.
    wire autofire_available=active_sys==0 || active_sys==2 || active_sys==3 || active_sys==4 || active_sys==1;
    wire effective_autofire=autofire_enable && autofire_available;
    wire [1:0] held=stable && !inhibit ?
        (active_sys==0 ? llapi_af : (active_sys==4 || active_sys==2 || (active_sys==1 && BUTTONS!=2)) ? snac_af_sys : active_sys==1 && BUTTONS==2 ? {1'b0,pad_sys[6]} : active_sys==3 ? db_af_sys : 2'b0) : 2'b0;
    wire fire1,fire2;
`ifdef JTFRAME_ENHANCED_CONTROLS
    wire [1:0] clear_af={2{!stable}} | ({2{active_sys==0}} & (~llapi_connected | llapi_type_changed));
    enhanced_autofire af1(clk_sys,rst,vb_sync,held[0],raw_joy1[4],inhibit,
        effective_autofire,autofire_toggle,clear_af[0],autofire_rate1,fire1);
    enhanced_autofire af2(clk_sys,rst,vb_sync,held[1],raw_joy2[4],inhibit,
        autofire_enable2 && autofire_available,autofire_toggle2,clear_af[1],autofire_rate2,fire2);
`else
    selectable_autofire af1(clk_sys,rst,vb_sync,held[0],raw_joy1[4],inhibit,effective_autofire,autofire_toggle,!stable || (active_sys==0 && !llapi_connected[0]),fire1);
    selectable_autofire af2(clk_sys,rst,vb_sync,held[1],raw_joy2[4],inhibit,effective_autofire,autofire_toggle,!stable || (active_sys==0 && !llapi_connected[1]),fire2);
`endif
    assign joy1={raw_joy1[15:5],fire1,raw_joy1[3:0]};
    assign joy2={raw_joy2[15:5],fire2,raw_joy2[3:0]};
`else
    assign joy1=raw_joy1;assign joy2=raw_joy2;
`endif
    assign start=!stable ? 4'd0 : !snac_selected ? llapi_start :
                 {2'd0,dual_snac && pad2_sys[7] && !inhibit,
                  pad_sys[7] && (!pad_sys[8] || db15_selected) && !inhibit};
    assign coin=!stable ? 4'd0 : !snac_selected ? llapi_coin :
                 {2'd0,dual_snac && pad2_sys[8] && !inhibit,pad_sys[8] && !inhibit};
    assign osd_request=stable && (snac_selected ? snac_menu : llapi_osd);
endmodule

