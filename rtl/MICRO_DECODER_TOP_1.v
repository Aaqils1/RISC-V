`timescale 1ns / 1ps
// =============================================================
//  MICRO_DECODER_TOP  -  Combinational ROM output
//
//  instr_out is now COMBINATIONAL (wire, not reg).
//  The combinational loop is broken upstream in DATAPATH by
//  using a registered 1-cycle pulse for micro_start - so the
//  FSM only ever sees a clean single-cycle trigger, and
//  micro_running (a registered FSM output) never feeds back
//  combinationally into micro_start.
//
//  ROM address ranges:
//    SOP    (0001011): addr  0 ..  6   (7 micro-instrs)
//    MATMUL (0101011): addr 16 .. 60  (45 micro-instrs)
// =============================================================
module MICRO_DECODER_TOP (
    input            clk,
    input            reset,
    input            micro_start,   // 1-cycle registered pulse
    input      [6:0] opcode,
    output     [31:0] instr_out,    // combinational - no loop now
    output           running,
    output           done
);
    localparam SOP_BASE    = 6'd0;
    localparam SOP_LAST    = 6'd6;
    localparam MATMUL_BASE = 6'd16;
    localparam MATMUL_LAST = 6'd60;

    reg [5:0] op_base_r, op_last_r;

    always @(*) begin
        case (opcode)
            7'b000_1011: begin
                op_base_r = SOP_BASE;
                op_last_r = SOP_LAST;
            end
            7'b010_1011: begin
                op_base_r = MATMUL_BASE;
                op_last_r = MATMUL_LAST;
            end
            default: begin
                op_base_r = SOP_BASE;
                op_last_r = SOP_LAST;
            end
        endcase
    end

    wire        rom_enable;
    wire [5:0]  rom_addr;

    micro_fsm fsm (
        .clk        (clk),
        .reset      (reset),
        .macro_valid(micro_start),
        .op_base    (op_base_r),
        .op_last    (op_last_r),
        .rom_enable (rom_enable),
        .rom_addr   (rom_addr),
        .running    (running),
        .done       (done)
    );

    wire [31:0] rom_data;
    micro_rom rom (
        .addr (rom_addr),
        .data (rom_data)
    );

    // Combinational output - loop-safe because micro_start
    // is a registered pulse (not derived from running/instr_out)
    assign instr_out = rom_enable ? rom_data : 32'h0000_0013;
endmodule