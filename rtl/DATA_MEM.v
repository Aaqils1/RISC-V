`timescale 1ns / 1ps
// =============================================================
//  Data Memory  -  512 words × 32-bit  (2 KB)
//
//  Memory map (word addresses, each word = 4 bytes):
//
//    Addr   0 ..  3  : Normal program scratch (sw results)
//    Addr  64 .. 319 : Matrix A  [16][16]  (256 words, row-major)
//                      A[i][j] at word addr = 64 + i*16 + j
//    Addr 320 .. 575 : Matrix B  [16][16]  (256 words, row-major)
//                      B[i][j] at word addr = 320 + i*16 + j
//    Addr 576 .. 831 : Matrix C  [16][16]  result (256 words)
//                      C[i][j] at word addr = 576 + i*16 + j
//
//  Byte address = word_addr × 4
//  ALU produces byte addresses; we index by addr[10:2] (9 bits → 512 words)
//
//  Matrix A initialised to A[i][j] = i+1   (rows 1..16)
//  Matrix B initialised to B[i][j] = j+1   (cols 1..16)
//  Expected C[i][j] = (i+1)*Σ(k=0..15)(k+1) = (i+1)*136
//    e.g. C[0][0]=136, C[1][0]=272, ... C[15][0]=2176
// =============================================================
module DATA_MEM (
    input             clk,
    input             memread,
    input             memwrite,
    input      [31:0] addr,    // byte address from ALU
    input      [31:0] wd,
    output     [31:0] rd
);
    reg [31:0] mem [0:511];   // 512 words
    integer r, c;

    initial begin : init_mem
        integer i;
        // Zero everything first
        for (i = 0; i < 512; i = i + 1) mem[i] = 32'd0;

        // ── Initialise Matrix A: A[i][j] = i+1  (row-value) ──
        for (r = 0; r < 16; r = r + 1)
            for (c = 0; c < 16; c = c + 1)
                mem[64 + r*16 + c] = r + 1;

        // ── Initialise Matrix B: B[i][j] = j+1  (col-value) ──
        for (r = 0; r < 16; r = r + 1)
            for (c = 0; c < 16; c = c + 1)
                mem[320 + r*16 + c] = c + 1;
    end

    // Synchronous write
    always @(posedge clk)
        if (memwrite) mem[addr[10:2]] <= wd;

    // Asynchronous read
    assign rd = memread ? mem[addr[10:2]] : 32'd0;
endmodule