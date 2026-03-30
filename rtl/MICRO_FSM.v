`timescale 1ns / 1ps
module micro_fsm (
    input            clk,
    input            reset,
    input            macro_valid,   // 1-cycle pulse from DATAPATH
    input      [5:0] op_base,
    input      [5:0] op_last,
    input            fifo_full,     // backpressure: stall if full
    output reg       write_en,      // push to FIFO this cycle
    output reg [5:0] rom_addr,      // address into micro_rom
    output reg       fsm_running,   // HIGH while FSM in RUN state
    output reg       fsm_done       // 1-cycle pulse on completion
);
    localparam IDLE = 2'b00;
    localparam RUN  = 2'b01;
    localparam DONE = 2'b10;

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
            fsm_done <= 1'b0;   // default: no pulse
            write_en <= 1'b0;   // default: no push

            case (state)

            IDLE: begin
                fsm_running <= 1'b0;
                if (macro_valid) begin
                    rom_addr    <= op_base;
                    last_addr   <= op_last;
                    fsm_running <= 1'b1;
                    state       <= RUN;
                end
            end

            RUN: begin
                fsm_running <= 1'b1;
                if (!fifo_full) begin
                    write_en <= 1'b1;          // push rom[rom_addr]
                    if (rom_addr == last_addr)
                        state <= DONE;         // last entry pushed
                    else
                        rom_addr <= rom_addr + 6'd1;
                end
                // fifo_full: hold rom_addr, no write_en
            end

            DONE: begin
                fsm_running <= 1'b0;
                fsm_done    <= 1'b1;   // 1-cycle pulse
                state       <= IDLE;
            end

            default: state <= IDLE;
            endcase
        end
    end
endmodule