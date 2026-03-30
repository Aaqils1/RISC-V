`timescale 1ns / 1ps
// =============================================================
//  IFU  -  FIXED
//
//  ROOT CAUSE FIX:
//  Original IFU had an internal instruction register (instr_reg)
//  making the instruction output already one cycle delayed.
//  Then DATAPATH added IF_EX_REG on top - creating a 2-cycle
//  delay total.  The custom opcode arrived at CONTROL two cycles
//  late, after PC had already moved past it.
//
//  FIX: IFU outputs the instruction combinationally (no internal
//  register).  The single IF_EX_REG in DATAPATH provides the
//  one pipeline register that separates IF and EX stages.
//
//  Also fixed: PC now has an upper bound to prevent runaway.
// =============================================================

// Lets Check this now.

module IFU (
    input             clk,
    input             reset,
    input             jump_i,
    input             branch_i,
    input             zero_i,
    input             stall_i,
    input  [31:0]     imm_i,
    output reg [31:0] pc_o,
    output     [31:0] instr_o    // ← combinational, no register
);
    reg [31:0] imem [0:63];
    integer k;

    initial begin
        for (k = 0; k < 64; k = k + 1)
            imem[k] = 32'h0000_0013; // NOP

        // imem[0] 0x00: MATMUL custom instruction
        imem[0] = {7'b000_0000, 5'd0, 5'd0, 3'b000, 5'd0, 7'b010_1011};

        // imem[1] 0x04: addi x1, x0, 5
        imem[1] = {12'd5, 5'd0, 3'b000, 5'd1, 7'b001_0011};

        // imem[2] 0x08: addi x2, x0, 5
        imem[2] = {12'd5, 5'd0, 3'b000, 5'd2, 7'b001_0011};

        // imem[3] 0x0C: add x3, x1, x2
        imem[3] = {7'b000_0000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b011_0011};

        // imem[4] 0x10: sw x3, 0(x4)
        imem[4] = {7'b000_0000, 5'd3, 5'd4, 3'b010, 5'b00000, 7'b010_0011};

        // imem[5] 0x14: jal x5, +8  → jumps to 0x1C (skips imem[6])
        imem[5] = {1'b0, 10'b000_0000_100, 1'b0, 8'b0000_0000, 5'd5, 7'b110_1111};

        // imem[6] 0x18: lui x7, 0x12345  (SKIPPED by jal)
        imem[6] = {20'h12345, 5'd7, 7'b011_0111};

        // imem[7] 0x1C: beq x2, x1, +8  → x1==x2==5, taken → jumps to 0x24
        imem[7] = {1'b0, 6'b000000, 5'd2, 5'd1, 3'b000, 4'b0100, 1'b0, 7'b110_0011};

        // imem[8] 0x20: NOP (skipped by beq)
        imem[8] = 32'h0000_0013;

        // imem[9] 0x24: SOP custom instruction
        imem[9] = {7'b000_0000, 5'd2, 5'd1, 3'b000, 5'd31, 7'b000_1011};
    end

    // ── PC Logic ──────────────────────────────────────────────
    // FIX: added pc < 36 guard (9 instructions × 4 bytes = 36)
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_o <= 32'd0;
        else if (stall_i)
            pc_o <= pc_o;                      // freeze during micro
        else if (jump_i)
            pc_o <= pc_o + imm_i;
        else if (branch_i && zero_i)
            pc_o <= pc_o + imm_i;
        else if (pc_o < 32'd36)                // ← FIX: stop at end
            pc_o <= pc_o + 32'd4;
        // else: halt
    end

    // ── Combinational instruction output (no internal register) ──
    // FIX: was registered (instr_reg), causing double-pipeline-stage bug
    assign instr_o = imem[pc_o[7:2]];

endmodule