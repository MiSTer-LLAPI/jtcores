// SPDX-License-Identifier: GPL-3.0-or-later
// Frame-based hold-to-fire pulse generator; map the physical button upstream.
module hold_autofire #(parameter HALF_PERIOD_FRAMES=3)(
 input clk,rst,frame,hold_button,manual_fire,inhibit,
 output fire
);
localparam CW=HALF_PERIOD_FRAMES<2 ? 1 : $clog2(HALF_PERIOD_FRAMES);
reg [CW-1:0] count=0;
reg phase=1,previous_frame=0;
always @(posedge clk) begin
 previous_frame<=frame;
 if(rst || inhibit || !hold_button) begin count<=0;phase<=1;end
 else if(frame && !previous_frame) begin
  if(count==HALF_PERIOD_FRAMES-1) begin count<=0;phase<=~phase;end
  else count<=count+1'b1;
 end
end
assign fire=!rst && !inhibit && (manual_fire || (hold_button && phase));
endmodule
