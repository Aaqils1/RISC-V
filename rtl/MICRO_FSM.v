`timescale 1ns / 1ps
// =============================================================
//  micro_fsm  -  Clean final version
//
//  Works with combinational ROM output (no registered instr_out).
//  The combinational loop is broken in DATAPATH by registering
//  micro_start with a 1-cycle pulse generator.
//
//  States:
//    IDLE → RUN → DONE → WAIT → IDLE
//
//  WAIT prevents re-trigger while macro_valid is still high
//  (e.g. PC halted at end of program, custom opcode frozen
//  in ex_instr_cpu keeping micro_start=1 indefinitely).
// =============================================================
module micro_fsm (
    input            clk,
    input            reset,
    input            macro_valid,   // registered 1-cycle pulse from DATAPATH
    input      [5:0] op_base,
    input      [5:0] op_last,
    output reg       rom_enable,
    output reg [5:0] rom_addr,
    output reg       running,
    output reg       done
);
    localparam IDLE = 2'd0;
    localparam RUN  = 2'd1;
    localparam DONE = 2'd2;
    localparam WAIT = 2'd3;

    reg [1:0] state;
    reg [5:0] last_addr;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            rom_addr   <= 6'd0;
            rom_enable <= 1'b0;
            running    <= 1'b0;
            done       <= 1'b0;
            last_addr  <= 6'd0;
        end else begin
            done <= 1'b0; // default: pulse for one cycle only

            case (state)
            //----------------------------------------------
            IDLE: begin
                running    <= 1'b0;
                rom_enable <= 1'b0;
                if (macro_valid) begin
                    rom_addr   <= op_base;
                    last_addr  <= op_last;
                    rom_enable <= 1'b1;
                    running    <= 1'b1;
                    state      <= RUN;
                end
            end
            //----------------------------------------------
            RUN: begin
                running    <= 1'b1;
                rom_enable <= 1'b1;
                if (rom_addr == last_addr) begin
                    state <= DONE;
                    // do NOT increment - last instr executes this cycle
                end else begin
                    rom_addr <= rom_addr + 6'd1;
                end
            end
            //----------------------------------------------
            DONE: begin
                running    <= 1'b0;
                rom_enable <= 1'b0;
                done       <= 1'b1;
                state      <= WAIT;
            end
            //----------------------------------------------
            // Stay in WAIT until micro_start deasserts.
            // This prevents immediate re-trigger if the custom
            // opcode is still frozen in ex_instr_cpu.
            WAIT: begin
                if (!macro_valid)
                    state <= IDLE;
            end
            //----------------------------------------------
            default: state <= IDLE;
            endcase
        end
    end
endmodule