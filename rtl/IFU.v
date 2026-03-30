`timescale 1ns / 1ps
// =============================================================
//  IFU  -  Register conflict fully resolved
//
//  Register usage analysis:
//    x1-x9   : Matrix A operands → READ by SOP and MATMUL
//    x10-x18 : Matrix B operands → READ by MATMUL only
//    x19-x27 : MATMUL results    → CHECKED by testbench
//    x28-x30 : Micro temp regs   → used during micro execution
//    x31     : SOP result        → CHECKED by testbench
//
//  Normal instructions run AFTER MATMUL, BEFORE SOP.
//  They must NOT write to: x1-x9 (SOP reads), x19-x27 (TB checks),
//  x31 (SOP result, TB checks).
//
//  SAFE registers for normal instructions: x10, x11, x12
//    - MATMUL is already done, B matrix no longer needed
//    - SOP does not read x10-x18
//    - Testbench does not check x10-x18
//
//  Program order:
//    imem[0]  0x00: MATMUL  → results in x19-x27
//    imem[1]  0x04: addi x10, x0, 5   safe scratch
//    imem[2]  0x08: addi x11, x0, 5   safe scratch
//    imem[3]  0x0C: add  x12, x10, x11 safe scratch, x12=10
//    imem[4]  0x10: sw   x12, 0(x0)   store to mem[0]
//    imem[5]  0x14: jal  x0, +8       jump, no reg write
//    imem[6]  0x18: lui  x10, 0x12345 SKIPPED by jal
//    imem[7]  0x1C: beq  x11, x10, +8 x10==x11==5, taken → 0x24
//    imem[8]  0x20: NOP               SKIPPED by beq
//    imem[9]  0x24: SOP
// =============================================================
module IFU (
    input             clk,
    input             reset,
    input             jump_i,
    input             branch_i,
    input             zero_i,
    input             stall_i,
    input  [31:0]     imm_i,
    output reg [31:0] pc_o,
    output     [31:0] instr_o
);
    reg [31:0] imem [0:63];
    integer k;

    initial begin
        for (k = 0; k < 64; k = k + 1)
            imem[k] = 32'h0000_0013;

        // 0x00: MATMUL
        imem[0] = {7'b000_0000, 5'd0, 5'd0, 3'b000, 5'd0, 7'b010_1011};

        // 0x04: addi x10, x0, 5  (x10 is safe - B matrix done, SOP ignores it)
        imem[1] = {12'd5, 5'd0, 3'b000, 5'd10, 7'b001_0011};

        // 0x08: addi x11, x0, 5
        imem[2] = {12'd5, 5'd0, 3'b000, 5'd11, 7'b001_0011};

        // 0x0C: add x12, x10, x11  → x12 = 10
        imem[3] = {7'b000_0000, 5'd11, 5'd10, 3'b000, 5'd12, 7'b011_0011};

        // 0x10: sw x12, 0(x0)  store result
        imem[4] = {7'b000_0000, 5'd12, 5'd0, 3'b010, 5'b00000, 7'b010_0011};

        // 0x14: jal x0, +8  → jump to 0x1C, discard return address
        imem[5] = {1'b0, 10'b000_0000_100, 1'b0, 8'b0000_0000, 5'd0, 7'b110_1111};

        // 0x18: lui x10, 0x12345  (SKIPPED by jal)
        imem[6] = {20'h12345, 5'd10, 7'b011_0111};

        // 0x1C: beq x11, x10, +8  x10==x11==5 → taken → 0x24
        imem[7] = {1'b0, 6'b000000, 5'd11, 5'd10, 3'b000, 4'b0100, 1'b0, 7'b110_0011};

        // 0x20: NOP (skipped by beq)
        imem[8] = 32'h0000_0013;

        // 0x24: SOP
        imem[9] = {7'b000_0000, 5'd2, 5'd1, 3'b000, 5'd31, 7'b000_1011};
    end

    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_o <= 32'd0;
        else if (stall_i)
            pc_o <= pc_o;
        else if (jump_i)
            pc_o <= pc_o + imm_i;
        else if (branch_i && zero_i)
            pc_o <= pc_o + imm_i;
        else if (pc_o < 32'd36)
            pc_o <= pc_o + 32'd4;
    end

    assign instr_o = imem[pc_o[7:2]];
endmodule