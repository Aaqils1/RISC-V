`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/16/2026 08:04:56 AM
// Design Name: 
// Module Name: micro_fifo_1
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module micro_fifo(

input clk,
input reset,

input write_en,
input read_en,

input  [31:0] data_in,
output reg [31:0] data_out,

output full,
output empty

);

reg [31:0] mem [0:3];

reg [1:0] write_ptr;
reg [1:0] read_ptr;
reg [2:0] count;

assign full  = (count == 4);
assign empty = (count == 0);

always @(posedge clk or posedge reset) begin

if(reset) begin
    write_ptr <= 0;
    read_ptr  <= 0;
    count     <= 0;
    data_out  <= 0;
end

else begin

    // WRITE
    if(write_en && !full) begin
        mem[write_ptr] <= data_in;
        write_ptr <= write_ptr + 1;
        count <= count + 1;
    end

    // READ
    if(read_en && !empty) begin
        data_out <= mem[read_ptr];
        read_ptr <= read_ptr + 1;
        count <= count - 1;
    end

end

end

endmodule
