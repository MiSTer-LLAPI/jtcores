module cps1_game_ports_tb;
reg clk=0,rst=1,wr=0;
reg [7:0] data=0;
reg [4:0] addr=0;
reg [9:0] joy3='1,joy4='1;
reg [3:0] start='1,coin='1;
wire [15:0] result;
always #5 clk=~clk;
jtcps1_mmr dut(.clk(clk),.rst(rst),.ppu_rstn(1'b1),.ppu2_cs(1'b1),.ppu1_cs(1'b0),.dsn(2'b11),
  .addr(addr),.cfg_we(wr),.cfg_data(data),.joystick3(joy3),.joystick4(joy4),.coin(coin),.cab_1p(start),.mmr_dout(result));
task load_header(input [191:0] header);
integer i;
begin
 for(i=0;i<24;i=i+1) begin
  @(negedge clk);data=header[191-i*8 -:8];wr=1;
  @(negedge clk);wr=0;
 end
end
endtask
task check_port(input [4:0] address,input integer player);
 integer bitno;reg [7:0] expected;
 begin
 addr=address;
 for(bitno=0;bitno<8;bitno=bitno+1)begin
  @(negedge clk);expected=~(8'b1<<bitno);
  if(bitno<6)begin if(player==3)joy3[bitno]=0;else joy4[bitno]=0;end
  else if(bitno==6)coin[player-1]=0;else start[player-1]=0;
  repeat(3) @(negedge clk);if(result!=={expected,expected}) $fatal(1,"P%0d input %0d read %h",player,bitno,result);
  joy3='1;joy4='1;coin='1;start='1;
  repeat(3) @(negedge clk);if(result!==16'hffff)$fatal(1,"release failed");
 end
 end
endtask
initial begin
repeat(3) @(negedge clk);rst=0;
load_header(192'h2042ffffffff2c2a2826243600220204080013406633ff02); // mercs
check_port(5'd27,3);
load_header(192'hffff06040200202e2c2a283638302012120004408873ff04); // captcomm
check_port(5'd27,3);
check_port(5'd28,4);
load_header(192'hffff1e1c1a18202e2c2a28360030300830000b408873ff03); // kod
check_port(5'd27,3);
load_header(192'hffff060402002826242220360030201002000d408873ff02); // knights
check_port(5'd27,3);
$display("PASS: CPS-B P3/P4 inputs and release across four game headers");$finish;end endmodule
