`timescale 1ns / 1ps
// =============================================================
//  CONTROL  -  FIXED
//
//  Added micro_start as a proper output port.
//  DATAPATH was previously computing micro_start independently,
//  causing it to be derived from ex_instr_cpu (pre-pipeline-reg)
//  while CONTROL was decoding ex_instr (post-mux).  These were
//  different signals during micro-execution, causing conflicts.
//
//  FIX: CONTROL now outputs micro_start directly from the
//  effective instruction opcode.  DATAPATH uses this output.
//  micro_start is purely combinational - no clock delay.
// =============================================================
module CONTROL (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg   regwrite,
    output reg   alusrc,
    output reg   memread,
    output reg   memwrite,
    output reg   memtoreg,
    output reg   branch,
    output reg   jump,
    output reg [3:0] alu_ctrl,
    output wire  micro_start    // ← ADDED: combinational, same cycle
);
    localparam ALU_ADD  = 4'b0010;
    localparam ALU_SUB  = 4'b0011;
    localparam ALU_AND  = 4'b0000;
    localparam ALU_OR   = 4'b0001;
    localparam ALU_XOR  = 4'b0110;
    localparam ALU_SLL  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b1001;
    localparam ALU_MUL  = 4'b0111;
    localparam ALU_MULH = 4'b1000;
    localparam ALU_SLTU = 4'b1010;
    localparam ALU_SLT  = 4'b1011;

    // Combinational micro_start - fires the SAME cycle the custom
    // opcode is in the EX stage.  No register, no delay.
    assign micro_start = (opcode == 7'b000_1011) ||  // SOP
                         (opcode == 7'b010_1011);    // MATMUL

    always @(*) begin
        regwrite = 0; alusrc = 0; memread = 0; memwrite = 0;
        memtoreg = 0; branch = 0; jump = 0; alu_ctrl = ALU_ADD;

        case (opcode)
        7'b011_0011: begin  // R-type (includes MUL)
            regwrite = 1;
            case ({funct7, funct3})
                {7'b000_0000, 3'b000}: alu_ctrl = ALU_ADD;
                {7'b010_0000, 3'b000}: alu_ctrl = ALU_SUB;
                {7'b000_0000, 3'b111}: alu_ctrl = ALU_AND;
                {7'b000_0000, 3'b110}: alu_ctrl = ALU_OR;
                {7'b000_0000, 3'b100}: alu_ctrl = ALU_XOR;
                {7'b000_0000, 3'b001}: alu_ctrl = ALU_SLL;
                {7'b000_0000, 3'b101}: alu_ctrl = ALU_SRL;
                {7'b010_0000, 3'b101}: alu_ctrl = ALU_SRA;
                {7'b000_0001, 3'b000}: alu_ctrl = ALU_MUL;
                {7'b000_0001, 3'b001}: alu_ctrl = ALU_MULH;
                {7'b000_0000, 3'b011}: alu_ctrl = ALU_SLTU;
                {7'b000_0000, 3'b010}: alu_ctrl = ALU_SLT;
                default:               alu_ctrl = ALU_ADD;
            endcase
        end
        7'b001_0011: begin  // I-type ALU
            regwrite = 1; alusrc = 1; alu_ctrl = ALU_ADD;
        end
        7'b000_0011: begin  // Load
            regwrite = 1; alusrc = 1; memread = 1; memtoreg = 1;
        end
        7'b010_0011: begin  // Store
            alusrc = 1; memwrite = 1;
        end
        7'b110_0011: begin  // Branch
            branch = 1; alu_ctrl = ALU_SUB;
        end
        7'b110_1111: begin  // JAL
            regwrite = 1; jump = 1;
        end
        7'b110_0111: begin  // JALR
            regwrite = 1; alusrc = 1; jump = 1;
        end
        7'b011_0111,
        7'b001_0111: begin  // LUI / AUIPC
            regwrite = 1; alusrc = 1;
        end
        // Custom opcodes: micro_start fires above
        // Normal writeback suppressed (regwrite stays 0)
        7'b000_1011: ; // SOP
        7'b010_1011: ; // MATMUL
        default: ;
        endcase
    end
endmodule