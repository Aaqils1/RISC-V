`timescale 1ns / 1ps
module MICRO_DECODER_TOP (
    input             clk,
    input             reset,
    input             micro_start,   // 1-cycle pulse from DATAPATH
    input      [6:0]  opcode,
    output     [31:0] instr_out,     // direct from FIFO data_out
    output reg        running,
    output reg        done
);
    localparam SOP_BASE    = 6'd0;
    localparam SOP_LAST    = 6'd6;   // addr 0..6 = 7 instructions
    localparam MATMUL_BASE = 6'd16;
    localparam MATMUL_LAST = 6'd60;  // addr 16..60 = 45 instructions

    // ── Opcode decode ─────────────────────────────────────────
    reg [5:0] op_base_r, op_last_r;
    always @(*) begin
        case (opcode)
            7'b000_1011: begin op_base_r = SOP_BASE;    op_last_r = SOP_LAST;    end
            7'b010_1011: begin op_base_r = MATMUL_BASE; op_last_r = MATMUL_LAST; end
            default:     begin op_base_r = SOP_BASE;    op_last_r = SOP_LAST;    end
        endcase
    end

    // ── FSM (producer) ────────────────────────────────────────
    wire        fifo_full, fifo_empty;
    wire        fsm_write_en, fsm_running, fsm_done_pulse;
    wire [5:0]  rom_addr;

    micro_fsm fsm (
        .clk         (clk),
        .reset       (reset),
        .macro_valid (micro_start),
        .op_base     (op_base_r),
        .op_last     (op_last_r),
        .fifo_full   (fifo_full),
        .write_en    (fsm_write_en),
        .rom_addr    (rom_addr),
        .fsm_running (fsm_running),
        .fsm_done    (fsm_done_pulse)
    );

    // ── ROM ───────────────────────────────────────────────────
    wire [31:0] rom_data;
    micro_rom rom (.addr(rom_addr), .data(rom_data));

    // ── FIFO ─────────────────────────────────────────────────
    // read_en: pop one instruction per cycle whenever available
    wire read_en = !fifo_empty;

    micro_fifo fifo (
        .clk      (clk),
        .reset    (reset),
        .write_en (fsm_write_en),
        .read_en  (read_en),
        .data_in  (rom_data),
        .data_out (instr_out),   // wire - directly used as instr_out
        .full     (fifo_full),
        .empty    (fifo_empty)
    );

    // ── running / done ────────────────────────────────────────
    // running: HIGH while FSM is producing OR FIFO still has data
    // done:    single registered pulse after FIFO fully drains
    //
    // fsm_done_seen latches the FSM's done pulse and holds it
    // until fifo_empty confirms all instructions have been consumed.
    reg fsm_done_seen;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            running       <= 1'b0;
            done          <= 1'b0;
            fsm_done_seen <= 1'b0;
        end else begin
            done <= 1'b0; // default: no pulse

            // Latch FSM done pulse
            if (fsm_done_pulse)
                fsm_done_seen <= 1'b1;

            // running: asserted while FSM active or FIFO not empty
            if (micro_start)
                running <= 1'b1;
            else if (fsm_done_seen && fifo_empty) begin
                running       <= 1'b0;
                done          <= 1'b1;   // single-cycle pulse
                fsm_done_seen <= 1'b0;
            end
        end
    end

endmodule