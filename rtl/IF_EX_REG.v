`timescale 1ns / 1ps
// =============================================================
//  IF/EX Pipeline Register
//  Separates the Instruction Fetch and Execute stages.
//  Stalls (holds its value) when stall_i is asserted.
//  Flushes to NOP (0x00000013 = addi x0,x0,0) on flush_i.
// =============================================================
module IF_EX_REG (
    input             clk,
    input             reset,
    input             stall_i,   // hold when micro-execution is running
    input             flush_i,   // insert NOP on taken branch/jump
    input  [31:0]     pc_i,
    input  [31:0]     instr_i,
    output reg [31:0] pc_o,
    output reg [31:0] instr_o
);
    localparam NOP = 32'h0000_0013; // addi x0, x0, 0

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_o    <= 32'd0;
            instr_o <= NOP;
        end else if (flush_i) begin
            // Insert bubble - keep PC so writeback address is still valid
            instr_o <= NOP;
            pc_o    <= pc_i;
        end else if (!stall_i) begin
            pc_o    <= pc_i;
            instr_o <= instr_i;
        end
        // else: stall - hold current values
    end
endmodule