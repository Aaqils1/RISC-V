`timescale 1ns / 1ps
// =============================================================
//  micro_fifo  -  Fully corrected
//
//  Changes from previous version:
//
//  1. mem[] initialized to NOP (32'h00000013).
//     When FIFO is empty, data_out = mem[read_ptr] = NOP.
//     This prevents X-propagation from uninitialized memory
//     reaching CONTROL and causing spurious register writes.
//
//  2. data_out explicitly gated: when empty, output NOP.
//     Belt-and-suspenders against X propagation.
//
//  3. Depth = 8 (unchanged).
//
//  Async read: data_out is combinational from mem[read_ptr].
//  Sync write: mem updated at posedge clk when write_en=1.
//  Sync read pointer: read_ptr advances at posedge when read_en=1.
// =============================================================
module micro_fifo (
    input             clk,
    input             reset,
    input             write_en,
    input             read_en,
    input      [31:0] data_in,
    output     [31:0] data_out,
    output            full,
    output            empty
);
    localparam DEPTH = 8;
    localparam ABITS = 3;
    localparam NOP   = 32'h0000_0013;

    reg [31:0]      mem [0:DEPTH-1];
    reg [ABITS-1:0] write_ptr;
    reg [ABITS-1:0] read_ptr;
    reg [ABITS:0]   count;

    integer j;
    initial begin
        for (j = 0; j < DEPTH; j = j + 1)
            mem[j] = NOP;   // initialize to NOP - prevents X propagation
        write_ptr = 0;
        read_ptr  = 0;
        count     = 0;
    end

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // Async read, gated: output NOP when FIFO is empty
    assign data_out = empty ? NOP : mem[read_ptr];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            write_ptr <= 0;
            read_ptr  <= 0;
            count     <= 0;
            for (j = 0; j < DEPTH; j = j + 1)
                mem[j] <= NOP;
        end else begin
            if (write_en && !full) begin
                mem[write_ptr] <= data_in;
                write_ptr      <= write_ptr + 1;
            end

            if (read_en && !empty) begin
                read_ptr <= read_ptr + 1;
            end

            case ({write_en && !full, read_en && !empty})
                2'b10:   count <= count + 1;
                2'b01:   count <= count - 1;
                default: ;
            endcase
        end
    end
endmodule