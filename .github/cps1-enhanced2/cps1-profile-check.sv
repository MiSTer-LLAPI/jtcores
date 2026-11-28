module check_profiles; reg clk=0,rom=1,wr=1; reg [26:0] addr; reg [7:0] data; wire [2:0] profile;
cps1_autofire_header dut(clk,rom,wr,addr,data,profile);
task put(input integer a,input integer d); begin addr=a;data=d;#1;clk=1;#1;clk=0;end endtask
initial begin
put(0,0); if(profile!==0) $fatal; put(16,8'hff);put(34,8'h18);put(39,8'h01);if(profile!==3'd0) $fatal(1,"cworld2j");
put(0,0); if(profile!==0) $fatal; put(16,8'hff);put(34,8'h04);put(39,8'h04);if(profile!==3'd6) $fatal(1,"captcomm");
put(0,0); if(profile!==0) $fatal; put(16,8'h20);put(34,8'h24);put(39,8'h00);if(profile!==3'd0) $fatal(1,"dynwar");
put(0,0); if(profile!==0) $fatal; put(16,8'hff);put(34,8'h0e);put(39,8'h00);if(profile!==3'd0) $fatal(1,"forgottn");
put(0,0); if(profile!==0) $fatal; put(16,8'hff);put(34,8'h0a);put(39,8'h00);if(profile!==3'd0) $fatal(1,"ghouls");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h28);put(39,8'h00);if(profile!==3'd0) $fatal(1,"gulunpa");
put(0,0); if(profile!==0) $fatal; put(16,8'hff);put(34,8'h0d);put(39,8'h02);if(profile!==3'd4) $fatal(1,"knights");
put(0,0); if(profile!==0) $fatal; put(16,8'h2e);put(34,8'h11);put(39,8'h00);if(profile!==3'd0) $fatal(1,"msword");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h20);put(39,8'h00);if(profile!==3'd0) $fatal(1,"mpumpkin");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h1b);put(39,8'h01);if(profile!==3'd0) $fatal(1,"megaman");
put(0,0); if(profile!==0) $fatal; put(16,8'h1e);put(34,8'h06);put(39,8'h00);if(profile!==3'd0) $fatal(1,"mtwins");
put(0,0); if(profile!==0) $fatal; put(16,8'h20);put(34,8'h13);put(39,8'h02);if(profile!==3'd4) $fatal(1,"mercs");
put(0,0); if(profile!==0) $fatal; put(16,8'h0e);put(34,8'h12);put(39,8'h00);if(profile!==3'd0) $fatal(1,"nemo");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h14);put(39,8'hc1);if(profile!==3'd0) $fatal(1,"pang3");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h15);put(39,8'h01);if(profile!==3'd0) $fatal(1,"pnickj");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h16);put(39,8'h00);if(profile!==3'd0) $fatal(1,"pokonyan");
put(0,0); if(profile!==0) $fatal; put(16,8'hff);put(34,8'h1a);put(39,8'h01);if(profile!==3'd0) $fatal(1,"qad");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h26);put(39,8'h01);if(profile!==3'd0) $fatal(1,"qtono2j");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h23);put(39,8'h08);if(profile!==3'd0) $fatal(1,"sf2");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h1f);put(39,8'h09);if(profile!==3'd0) $fatal(1,"sf2ce");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h1f);put(39,8'h09);if(profile!==3'd0) $fatal(1,"sf2cre");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h1f);put(39,8'h09);if(profile!==3'd0) $fatal(1,"sf2hf");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h1f);put(39,8'h09);if(profile!==3'd0) $fatal(1,"sf2hfsce");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h20);put(39,8'h11);if(profile!==3'd0) $fatal(1,"sfzch");
put(0,0); if(profile!==0) $fatal; put(16,8'hff);put(34,8'h22);put(39,8'h00);if(profile!==3'd0) $fatal(1,"strider");
put(0,0); if(profile!==0) $fatal; put(16,8'hff);put(34,8'h0b);put(39,8'h03);if(profile!==3'd4) $fatal(1,"kod");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h1d);put(39,8'h00);if(profile!==3'd0) $fatal(1,"3wonders");
put(0,0); if(profile!==0) $fatal; put(16,8'h32);put(34,8'h01);put(39,8'h00);if(profile!==3'd0) $fatal(1,"unsquad");
put(0,0); if(profile!==0) $fatal; put(16,8'h20);put(34,8'h28);put(39,8'h01);if(profile!==3'd0) $fatal(1,"varth");
put(0,0); if(profile!==0) $fatal; put(16,8'hff);put(34,8'h29);put(39,8'h00);if(profile!==3'd0) $fatal(1,"willow");
put(0,0);put(39,32);if(profile!==0)$fatal; $display("PASS: 30 MRA headers, game change and incomplete header");$finish;end endmodule