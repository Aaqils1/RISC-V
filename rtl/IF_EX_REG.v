`timescale 1ns / 1ps
// =============================================================
//  IF_EX Pipeline Register - clock-enable version
//
//  clk_en: connected to HAZARD_UNIT.if_ex_clk_en
//    1 = normal operation (update on posedge)
//    0 = clock gated     (hold current value, no switching)
//
//  On Xilinx FPGA: Vivado maps "if (clk_en)" to the dedicated
//  CE (clock enable) input on slice flip-flops. This is
//  equivalent to clock gating without routing clock signals
//  through logic (which would violate FPGA timing rules).
//
//  flush takes priority over clk_en: even when gated, a
//  flush can insert a NOP (flush is only asserted by
//  control hazards which cannot occur during micro-execution,
//  so this priority never creates a conflict in practice).
// =============================================================
module IF_EX_REG (
    input             clk,
    input             reset,
    input             clk_en,    // from HAZARD_UNIT (was stall_i)
    input             flush_i,
    input  [31:0]     pc_i,
    input  [31:0]     instr_i,
    output reg [31:0] pc_o,
    output reg [31:0] instr_o
);
    localparam NOP = 32'h0000_0013;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_o    <= 32'd0;
            instr_o <= NOP;
        end else if (flush_i) begin
            // Flush: insert NOP regardless of clk_en
            instr_o <= NOP;
            pc_o    <= pc_i;
        end else if (clk_en) begin
            // Normal: update only when clock is enabled
            pc_o    <= pc_i;
            instr_o <= instr_i;
        end
        // else clk_en=0: hold current values (clock gated)
    end
endmodule