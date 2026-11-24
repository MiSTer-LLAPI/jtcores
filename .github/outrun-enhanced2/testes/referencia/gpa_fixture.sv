`timescale 1ns/1ps
module timeout_adapter #(
    parameter integer REPLY_DELAY = 0,
    parameter integer REPORT_TYPE = 27
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
                device_data=~packet[byte_index][bit_index]; ticks(115);
            end
            device_data=1; ticks(49); device_data=0; ticks(50);
        end
        device_latch=1; device_data=1;
    endtask
    initial forever begin
        @(negedge host_latch); ticks(251);
        for (integer bit_index=0;bit_index<8;bit_index=bit_index+1) begin
            opcode[bit_index]=~host_data;
            if (bit_index<7) ticks(224);
        end
        @(posedge host_latch); ticks(600);
        case (opcode)
            8'h00: begin
                polls=polls+1;
                device_latch=0; device_data=0; ticks(200);
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

