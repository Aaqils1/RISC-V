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


`timescale 1ns / 1ps
// =============================================================
//  ALU
//  Operations encoded in alu_ctrl (4-bit):
//   0000 AND  0001 OR   0010 ADD  0011 SUB
//   0100 SLL  0101 SRL  0110 XOR  0111 MUL (lower 32)
//   1000 MULH (upper 32, signed×signed)
//   1001 SRA
//  Flags: zero, carry (ADD/SUB only), sign, overflow (ADD/SUB)
// =============================================================
module ALU (
    input  signed [31:0] a,
    input  signed [31:0] b,
    input         [3:0]  alu_ctrl,
    output reg signed [31:0] y,
    output zero,
    output carry,
    output sign,
    output overflow
);
    reg [32:0]  add_ext;    // 33-bit for carry detection
    reg signed [63:0] mul64;

    always @(*) begin
        add_ext = 33'd0;
        mul64   = 64'd0;
        y       = 32'd0;

        case (alu_ctrl)
        4'b0000: y = a & b;                         // AND
        4'b0001: y = a | b;                         // OR
        4'b0010: begin                               // ADD
            add_ext = {1'b0, a} + {1'b0, b};
            y = add_ext[31:0];
        end
        4'b0011: begin                               // SUB
            add_ext = {1'b0, a} - {1'b0, b};
            y = add_ext[31:0];
        end
        4'b0100: y = a << b[4:0];                   // SLL
        4'b0101: y = $unsigned(a) >> b[4:0];        // SRL
        4'b0110: y = a ^ b;                         // XOR
        4'b0111: begin                               // MUL (lo32)
            mul64 = a * b;
            y = mul64[31:0];
        end
        4'b1000: begin                               // MULH (hi32, signed)
            mul64 = a * b;
            y = mul64[63:32];
        end
        4'b1001: y = a >>> b[4:0];                  // SRA (arithmetic)
        4'b1010: y = ($unsigned(a) < $unsigned(b)) ? 32'd1 : 32'd0; // SLTU
        4'b1011: y = ($signed(a)   < $signed(b))   ? 32'd1 : 32'd0; // SLT
        default: y = 32'd0;
        endcase
    end

    assign zero     = (y == 32'd0);
    assign sign     = y[31];
    assign carry    = add_ext[32];
    assign overflow =
        (alu_ctrl == 4'b0010) ? (a[31]==b[31] && y[31]!=a[31]) :
        (alu_ctrl == 4'b0011) ? (a[31]!=b[31] && y[31]!=a[31]) :
        1'b0;
endmodule