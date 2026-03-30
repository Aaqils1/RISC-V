`timescale 1ns / 1ps
// =============================================================
//  REG_FILE  -  No combinational forwarding
//
//  ROOT CAUSE OF SIMULATION HANG:
//  The forwarding path:
//    wd = wb = alu_y → rd1/rd2 → ALU → alu_y
//  was a pure combinational loop causing infinite delta cycles.
//
//  FIX: Remove same-cycle forwarding entirely.
//  Reads are purely asynchronous from the register array.
//  Writes are synchronous (clocked).
//  In a 2-stage pipeline this is correct because:
//    - Cycle N:   instruction in EX reads rs1/rs2
//    - Cycle N:   result written to rd at posedge clk
//    - Cycle N+1: next instruction reads the updated value
//  The stall mechanism ensures micro-instructions see correct
//  values because the pipeline is frozen during micro-execution.
// =============================================================
module REG_FILE (
    input             clk,
    input             we,
    input      [4:0]  rs1, rs2, rd,
    input      [31:0] wd,
    output     [31:0] rd1, rd2,

    output [31:0] dbg_x19,
    output [31:0] dbg_x20, dbg_x21, dbg_x22,
    output [31:0] dbg_x23, dbg_x24, dbg_x25,
    output [31:0] dbg_x26, dbg_x27,
    output [31:0] dbg_sop,
    output [31:0] dbg_t0, dbg_t1, dbg_t2
);
    reg [31:0] regf [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            regf[i] = 32'd0;

        // Matrix A in x1..x9
        regf[1]=32'd1; regf[2]=32'd2; regf[3]=32'd3;
        regf[4]=32'd4; regf[5]=32'd5; regf[6]=32'd6;
        regf[7]=32'd7; regf[8]=32'd8; regf[9]=32'd9;

        // Matrix B in x10..x18
        regf[10]=32'd1; regf[11]=32'd2; regf[12]=32'd3;
        regf[13]=32'd4; regf[14]=32'd5; regf[15]=32'd6;
        regf[16]=32'd7; regf[17]=32'd8; regf[18]=32'd9;
    end

    // Synchronous write only - no combinational forwarding
    always @(posedge clk) begin
        if (we && rd != 5'd0)
            regf[rd] <= wd;
        regf[0] <= 32'd0;  // x0 always 0
    end

    // Pure asynchronous read - no feedback to wd/wb/alu_y
    assign rd1 = (rs1 == 5'd0) ? 32'd0 : regf[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'd0 : regf[rs2];

    // Debug taps
    assign dbg_x19 = regf[19]; assign dbg_x20 = regf[20];
    assign dbg_x21 = regf[21]; assign dbg_x22 = regf[22];
    assign dbg_x23 = regf[23]; assign dbg_x24 = regf[24];
    assign dbg_x25 = regf[25]; assign dbg_x26 = regf[26];
    assign dbg_x27 = regf[27]; assign dbg_sop  = regf[31];
    assign dbg_t0  = regf[28]; assign dbg_t1   = regf[29];
    assign dbg_t2  = regf[30];
endmodule   