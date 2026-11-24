`timescale 1ns/1ps
module bench;
  parameter integer S=0, EXT=1, REPOLL=0; // S: 0 measured,1 fast,2 absent,3 stuck,4 disable during long ACK,5 pending ACK before busy deadline
  reg clk=0,enable=0,dp=1,dm=1;
  always #10 clk=~clk;
  reg vblank=0;
  integer frame_edges=0,edges_at_ack=0, max_edges_held=0;
  // jtpktgal_video configures jtframe_vtimer for 384 pixels x 260 lines at 6 MHz.
  // 16.640 ms per frame, 36 blank lines at 64 us each, 50 MHz LLAPI clock.
  initial if(S==6) begin
    repeat(650000) @(negedge clk);
    forever begin
      vblank=1;frame_edges++;
      repeat(115200) @(negedge clk);
      vblank=0;repeat(716800) @(negedge clk);
    end
  end
  wire hd,hm,gd,gm; wire pd=hd&dp,pm=hm&dm;
  wire valid,report,fault;wire[7:0] id,modes,refid,refmodes;
  wire[31:0] buttons,refbuttons;
  wire [71:0] analog_out,refanalog; wire active,type_changed,refactive,refchanged;
  wire[1:0] fault_reason,refreason;
  wire refvalid,refreport,reffault;
  `define PINS .CLK_50M(clk),.LLAPI_SYNC(vblank),.ENABLE(enable),.IO_LATCH_IN(pd),.IO_DATA_IN(pm)
  LLAPI #(.EXTENDED_POLL_ACK(EXT)) dut(
    `PINS,.IO_LATCH_OUT(hd),.IO_DATA_OUT(hm),.REPOLL_OFF(!REPOLL),.LLAPI_TYPE(id),.LLAPI_BUTTONS(buttons),
    .STATUS_VALID(valid),.STATUS_UPDATE(report),.LINK_FAULT(fault),.LAST_FAULT_REASON(fault_reason),.TYPE_CHANGED(type_changed),.LLAPI_EN(active),.LLAPI_ANALOG(analog_out),.LLAPI_MODES(modes));
  LLAPI_reference baseline(`PINS,.IO_LATCH_OUT(gd),.IO_DATA_OUT(gm),.REPOLL_OFF(!REPOLL),.LLAPI_TYPE(refid),.LLAPI_BUTTONS(refbuttons),
    .STATUS_VALID(refvalid),.STATUS_UPDATE(refreport),.LINK_FAULT(reffault),.LAST_FAULT_REASON(refreason),.TYPE_CHANGED(refchanged),.LLAPI_EN(refactive),.LLAPI_ANALOG(refanalog),.LLAPI_MODES(refmodes));
  integer n=0,polls=0,statuses=0,reports=0,faults=0,launch=0,status_at=0,report_at=0,ack_at=0,release_at=0,first_fault=0;
  integer hold_ticks=1310600,ack_turn=152;
  integer first_host_tx=0,host_tx=0;
  reg [7:0] pkt[0:12];reg[7:0] opcode;
  always @(posedge clk) begin
    n++;
    if(report) begin reports++;if(!report_at)report_at=n;end
    if(fault) begin faults++;if(!first_fault)first_fault=n;end
    #1;
    if(n>6 && (!EXT || S==1) &&
      {hd,hm,active,valid,report,fault,type_changed,fault_reason,id,modes,buttons,analog_out} !==
      {gd,gm,refactive,refvalid,refreport,reffault,refchanged,refreason,refid,refmodes,refbuttons,refanalog})
       $fatal(1,"Changed stock output at clock %0d",n);
  end
  task ticks(input integer times);repeat(times) @(negedge clk);endtask
  task packet_reply(input bit short_packet);
    dp=0;dm=1;ticks(100);
    for(integer b=0;b<(short_packet?1:13);b++) begin
      for(integer i=0;i<8;i++) begin
        dm=1;ticks(109);dm=short_packet?1:~pkt[b][i];ticks(115);
      end
      dm=1;ticks(49);dm=0;ticks(50);
    end
    dp=1;dm=1;
  endtask
  always @(negedge hd) begin host_tx++;if(!first_host_tx)first_host_tx=n;end
  integer tx_n;
  initial forever begin
    @(negedge hd);tx_n=n;ticks(251);
    for(integer k=0;k<8;k++)begin opcode[k]=~pm;if(k<7)ticks(224);end
    @(posedge hd);
    case(opcode)
      8'h00:begin
        polls++;
        if(!launch)launch=tx_n;
        if(S!=2 || polls!=1)begin
          ticks(polls==1?ack_turn:152);
          ack_at=n;edges_at_ack=frame_edges;dp=0;dm=0;
          if(S==3 && polls==1)begin
            wait(faults>0);ticks(5000);
            if(host_tx!=1) $fatal(1,"transmitted into stuck-low GP");
          end else if(S==4 && polls==1) begin wait(!enable);ticks(10);end
          else ticks(polls==1 || S==6 ? hold_ticks:200);
          release_at=n;dp=1;dm=1;
          if(frame_edges-edges_at_ack>max_edges_held) max_edges_held=frame_edges-edges_at_ack;
        end
      end
      8'h01:begin
        statuses++;
        if(!status_at)status_at=tx_n;
        if(S==6) begin pkt[1]=statuses%2;pkt[12]=statuses%2?2:8;end
        ticks(600);packet_reply(0);
      end
      8'h21:begin ticks(600);packet_reply(1);end
      default:$fatal(1,"invalid host command %h at %0d",opcode,n);
    endcase
  end
  initial begin
    for(integer j=0;j<13;j++)pkt[j]=0;
    pkt[0]=8'h1b;pkt[1]=8'h01;pkt[12]=8'h08;
    if(S==1||S==2||S==3||S==4)hold_ticks=200;
    if(S==5)ack_turn=300000;
    ticks(4);
    ticks(1);enable=1;
    if(S==6) begin
      for(integer j=1;j<=3;j++) begin
        wait(reports>=j);ticks(5);
        if(!valid || id!=8'h1b || buttons[0]!==j[0] || buttons[24]!==j[0] || faults) $fatal(1,"missed press/release S=%0d j=%0d buttons=%h faults=%0d",S,j,buttons,faults);
        $display("Pocket Gal frame REPOLL=%0d report=%0d valid=%b fire+right=%b/%b faults=%0d now=%0d",REPOLL,j,valid,buttons[0],buttons[24],faults,n);
      end
      if(max_edges_held<2) $fatal(1,"did not overlap two VBlank edges, got %0d",max_edges_held);
      $display("Pocket Gal real cadence covered %0d rising VBlank edges during one busy ACK across %0d total frames",max_edges_held,frame_edges);
    end else if(!EXT && (S==0||S==5)) begin
      wait(faults>0);wait(release_at>0);
      if(statuses || reports) $fatal(1,"Stock incorrectly reported long first poll");
      if(first_fault-launch<349990 || first_fault-launch>350010) $fatal(1,"Original deadline clocks %d",first_fault-launch);
    end else begin
      if(S==3) begin
        wait(faults>=1);
        if(EXT)begin
          if(first_fault-ack_at<1999980 || first_fault-ack_at>2000020)
            $fatal(1,"Extended stuck not bounded at 40ms %d",first_fault-ack_at);
        end else if(first_fault-launch<349990||first_fault-launch>350010) $fatal(1,"Stock stuck not bounded");
      end
      if(S==2) begin
        wait(faults>=1);
        if(first_fault-launch<349990 || first_fault-launch>350010) $fatal(1,"No-ACK deadline changed %d",first_fault-launch);
      end
      if(S==4) begin
        wait(ack_at>0);ticks(110000);enable=0;ticks(400);
        if(!hd||!hm||active||valid||buttons!=0) $fatal(1,"disable failed");
        enable=1;
      end
      wait(reports>=1);ticks(10);
      if(!valid || id!=8'h1b || buttons[0]!=1) $fatal(1,"wrong controller report");
      if((S==0 || S==1 || S==5) && faults) $fatal(1,"spurious fault");
    end
    $display("PASS scenario=%0d EXT=%0d REPOLL=%0d ACK=%0d width=%0d STATUS=%0d REPORT=%0d fault=%0d id=%h fire=%b",S,EXT,REPOLL,ack_at-launch,release_at-ack_at,status_at-launch,report_at-launch,first_fault-launch,id,buttons[0]);
    $finish;
  end
  initial begin ticks(8800000);$fatal(1,"simulation hang S=%0d EXT=%0d polls=%0d statuses=%0d reports=%0d faults=%0d",S,EXT,polls,statuses,reports,faults);end
endmodule
