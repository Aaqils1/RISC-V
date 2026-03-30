`timescale 1ns / 1ps
// =============================================================
//  micro_fsm  -  FIFO producer, fixed
//
//  The FSM reads micro-instructions from the ROM and writes them
//  into the FIFO.  It uses fifo_full as backpressure.
//
//  WAIT state: after DONE, wait until macro_valid goes LOW before
//  returning to IDLE.  This prevents re-trigger when the custom
//  opcode is frozen in ex_instr_cpu (stalled PC / end of program).
//
//  States:
//    IDLE → RUN → DONE → WAIT → IDLE
//
//  In RUN:
//    Each cycle that fifo_full=0: write rom_data to FIFO, advance addr.
//    When rom_addr reaches last_addr and FIFO accepts the write:
//      → go to DONE (all instructions enqueued).
//    If fifo_full=1: hold rom_addr, do not write.
// =============================================================
module micro_fsm (
    input            clk,
    input            reset,
    input            macro_valid,  // 1-cycle pulse
    input      [5:0] op_base,
    input      [5:0] op_last,
    input            fifo_full,
    output reg       write_en,
    output reg [5:0] rom_addr,
    output reg       fsm_running,
    output reg       fsm_done     // 1-cycle pulse: all instrs enqueued
);
    localparam IDLE = 2'd0;
    localparam RUN  = 2'd1;
    localparam DONE = 2'd2;
    localparam WAIT = 2'd3;

    reg [1:0] state;
    reg [5:0] last_addr;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            rom_addr    <= 6'd0;
            write_en    <= 1'b0;
            fsm_running <= 1'b0;
            fsm_done    <= 1'b0;
            last_addr   <= 6'd0;
        end else begin
            fsm_done <= 1'b0;  // default: no pulse
            write_en <= 1'b0;  // default: no write

            case (state)
            //--------------------------------------------------
            IDLE: begin
                fsm_running <= 1'b0;
                if (macro_valid) begin
                    rom_addr    <= op_base;
                    last_addr   <= op_last;
                    fsm_running <= 1'b1;
                    state       <= RUN;
                end
            end
            //--------------------------------------------------
            RUN: begin
                fsm_running <= 1'b1;
                if (!fifo_full) begin
                    write_en <= 1'b1;              // push this cycle
                    if (rom_addr == last_addr)
                        state <= DONE;             // last entry pushed
                    else
                        rom_addr <= rom_addr + 6'd1;
                end
                // else: fifo full - stall, hold rom_addr
            end
            //--------------------------------------------------
            DONE: begin
                fsm_running <= 1'b0;
                fsm_done    <= 1'b1;   // pulse: enqueuing complete
                state       <= WAIT;
            end
            //--------------------------------------------------
            // Wait for macro_valid to go low before re-arming.
            // Prevents immediate re-trigger if custom opcode is
            // still frozen in ex_instr_cpu (halted PC).
            WAIT: begin
                if (!macro_valid)
                    state <= IDLE;
            end
            //--------------------------------------------------
            default: state <= IDLE;
            endcase
        end
    end
endmodule