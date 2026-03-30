`timescale 1ns / 1ps
// =============================================================
//  MICRO_DECODER_TOP  -  Clean state machine, no priority conflicts
//
//  Previous version had a priority conflict in the always block:
//  when running_pending=1 AND fsm_done_seen && fifo_empty were
//  both true in the same cycle, both if-branches would fire,
//  causing unpredictable running/done behavior.
//
//  FIX: Use an explicit 4-state FSM for running/done control.
//
//  States:
//    S_IDLE  : waiting for micro_start
//    S_WAIT1 : micro_start fired; waiting 1 cycle for FSM to write
//              first FIFO entry (running=0 this cycle so no reads)
//    S_RUN   : consuming FIFO entries (running=1)
//    S_DRAIN : FSM done, draining remaining FIFO entries (running=1)
//    S_DONE  : FIFO empty after drain; pulse done=1 for 1 cycle
//
//  Timing guarantee:
//    - S_WAIT1 lasts exactly 1 cycle after micro_start
//    - FSM writes first entry at posedge during S_WAIT1
//    - S_RUN starts cycle after, FIFO guaranteed non-empty
//    - running=1 only in S_RUN and S_DRAIN
//    - done=1 only in S_DONE (1 cycle), then back to S_IDLE
// =============================================================
module MICRO_DECODER_TOP (
    input             clk,
    input             reset,
    input             micro_start,   // 1-cycle rising-edge pulse
    input      [6:0]  opcode,
    output     [31:0] instr_out,
    output reg        running,
    output reg        done
);
    localparam SOP_BASE    = 6'd0;
    localparam SOP_LAST    = 6'd6;
    localparam MATMUL_BASE = 6'd16;
    localparam MATMUL_LAST = 6'd60;

    // States
    localparam S_IDLE  = 3'd0;
    localparam S_WAIT1 = 3'd1;
    localparam S_RUN   = 3'd2;
    localparam S_DRAIN = 3'd3;
    localparam S_DONE  = 3'd4;

    reg [2:0] state;

    // Opcode decode
    reg [5:0] op_base_r, op_last_r;
    always @(*) begin
        case (opcode)
            7'b000_1011: begin op_base_r = SOP_BASE;    op_last_r = SOP_LAST;    end
            7'b010_1011: begin op_base_r = MATMUL_BASE; op_last_r = MATMUL_LAST; end
            default:     begin op_base_r = SOP_BASE;    op_last_r = SOP_LAST;    end
        endcase
    end

    // FSM wires
    wire       fifo_full, fifo_empty;
    wire       fsm_write_en, fsm_done_pulse;
    wire [5:0] rom_addr;
    wire       fsm_running_unused;

    micro_fsm fsm (
        .clk        (clk),
        .reset      (reset),
        .macro_valid(micro_start),
        .op_base    (op_base_r),
        .op_last    (op_last_r),
        .fifo_full  (fifo_full),
        .write_en   (fsm_write_en),
        .rom_addr   (rom_addr),
        .fsm_running(fsm_running_unused),
        .fsm_done   (fsm_done_pulse)
    );

    // ROM
    wire [31:0] rom_data;
    micro_rom rom (.addr(rom_addr), .data(rom_data));

    // FIFO - read only when running (to avoid draining before datapath ready)
    wire read_en = !fifo_empty && running;

    micro_fifo fifo (
        .clk      (clk),
        .reset    (reset),
        .write_en (fsm_write_en),
        .read_en  (read_en),
        .data_in  (rom_data),
        .data_out (instr_out),
        .full     (fifo_full),
        .empty    (fifo_empty)
    );

    // running/done state machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state   <= S_IDLE;
            running <= 1'b0;
            done    <= 1'b0;
        end else begin
            done <= 1'b0; // default: no done pulse

            case (state)
            //--------------------------------------------------
            S_IDLE: begin
                running <= 1'b0;
                if (micro_start)
                    state <= S_WAIT1;
            end
            //--------------------------------------------------
            // Wait 1 cycle: FSM writes first entry to FIFO this cycle
            // running=0: no reads happen, FIFO fills safely
            S_WAIT1: begin
                running <= 1'b0;
                state   <= S_RUN;  // always advance after exactly 1 cycle
            end
            //--------------------------------------------------
            // Running: FIFO has data, datapath consumes 1/cycle
            // Stay until FSM signals done (all instrs enqueued)
            S_RUN: begin
                running <= 1'b1;
                if (fsm_done_pulse)
                    state <= S_DRAIN;
            end
            //--------------------------------------------------
            // Drain: FSM done, consume remaining FIFO entries
            S_DRAIN: begin
                running <= 1'b1;
                if (fifo_empty)
                    state <= S_DONE;
            end
            //--------------------------------------------------
            // Done: pulse done for 1 cycle, return to idle
            S_DONE: begin
                running <= 1'b0;
                done    <= 1'b1;
                state   <= S_IDLE;
            end
            //--------------------------------------------------
            default: state <= S_IDLE;
            endcase
        end
    end
endmodule