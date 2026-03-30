`timescale 1ns / 1ps
// =============================================================
//  Immediate Generator
//  Supports: I, S, B, U, J types
// =============================================================
module IMM_GEN (
    input  [31:0] instr,
    output reg [31:0] imm
);
    always @(*) begin
        case (instr[6:0])
        // I-type: ADDI, load, JALR
        7'b001_0011,
        7'b000_0011,
        7'b110_0111: imm = {{20{instr[31]}}, instr[31:20]};
 
        // S-type: store
        7'b010_0011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
 
        // B-type: branch
        7'b110_0011: imm = {{19{instr[31]}},
                             instr[31],
                             instr[7],
                             instr[30:25],
                             instr[11:8],
                             1'b0};
 
        // U-type: LUI, AUIPC
        7'b011_0111,
        7'b001_0111: imm = {instr[31:12], 12'b0};
 
        // J-type: JAL
        7'b110_1111: imm = {{11{instr[31]}},
                             instr[31],
                             instr[19:12],
                             instr[20],
                             instr[30:21],
                             1'b0};
 
        default: imm = 32'd0;
        endcase
    end
endmodule
