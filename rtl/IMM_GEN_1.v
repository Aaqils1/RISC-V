`timescale 1ns / 1ps

// =============================================================
//  Immediate Generator
//  Supports: I, S, B, U, J types (RV32I)
// =============================================================
module IMM_GEN (
    input  [31:0] instr,
    output reg [31:0] imm
);

always @(*) begin
    case (instr[6:0])

    // ---------------- I-TYPE ----------------
    // ADDI, LW, JALR
    7'b0010011,
    7'b0000011,
    7'b1100111: begin
        imm = {{20{instr[31]}}, instr[31:20]};
    end

    // ---------------- S-TYPE ----------------
    // SW
    7'b0100011: begin
        imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    end

    // ---------------- B-TYPE ----------------
    // BEQ, BNE, etc.
    7'b1100011: begin
        imm = {{19{instr[31]}},
               instr[31],
               instr[7],
               instr[30:25],
               instr[11:8],
               1'b0};
    end

    // ---------------- U-TYPE ----------------
    // LUI, AUIPC
    7'b0110111,
    7'b0010111: begin
        imm = {instr[31:12], 12'b0};
    end

    // ---------------- J-TYPE ----------------
    // JAL
    7'b1101111: begin
        imm = {{11{instr[31]}},
               instr[31],
               instr[19:12],
               instr[20],
               instr[30:21],
               1'b0};
    end

    // ---------------- DEFAULT ----------------
    default: begin
        imm = 32'd0;
    end

    endcase
end

endmodule