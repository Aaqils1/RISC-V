`timescale 1ns / 1ps
// =============================================================
//  micro_rom  -  Bug fixes applied
//
//  BUG FIXED (Register mapping mismatch):
//  The old ROM used x9-x11 as row 0 of A and x18-x20 as row 0
//  of B, but REG_FILE initialised A into x1-x9 and B into
//  x10-x18.  This caused wrong registers to be read.
//
//  FIXED MAPPING (matches REG_FILE initial values below):
//    Matrix A (3×3), row-major:
//      Row 0: x1, x2, x3
//      Row 1: x4, x5, x6
//      Row 2: x7, x8, x9
//
//    Matrix B (3×3), row-major:
//      Row 0: x10, x11, x12
//      Row 1: x13, x14, x15
//      Row 2: x16, x17, x18
//
//    Results C (3×3):
//      C[0][0]=x20, C[0][1]=x21, C[0][2]=x22
//      C[1][0]=x23, C[1][1]=x24, C[1][2]=x25
//      C[2][0]=x26, C[2][1]=x27, C[2][2]=x19
//
//    Temp registers:
//      x28(t0), x29(t1), x30(t2)
//
//  SOP (addr 0..6):
//    x17 = x1*x2 + x3*x4 + x5*x6 + x7*x8
//    NOTE: SOP runs AFTER MATMUL so x1-x8 still hold A values.
//    With A init: x1=1,x2=2,x3=3,x4=4,x5=5,x6=6,x7=7,x8=8
//    SOP = 1*2 + 3*4 + 5*6 + 7*8 = 2+12+30+56 = 100 ✓
//
//  MATMUL 3×3 expected (A=[[1,2,3],[4,5,6],[7,8,9]]
//                        B=[[1,2,3],[4,5,6],[7,8,9]]):
//    C[0][0] = 1*1+2*4+3*7 = 1+8+21 = 30  → x20
//    C[0][1] = 1*2+2*5+3*8 = 2+10+24 = 36 → x21
//    C[0][2] = 1*3+2*6+3*9 = 3+12+27 = 42 → x22
//    C[1][0] = 4*1+5*4+6*7 = 4+20+42 = 66 → x23
//    C[1][1] = 4*2+5*5+6*8 = 8+25+48 = 81 → x24
//    C[1][2] = 4*3+5*6+6*9 = 12+30+54 = 96→ x25
//    C[2][0] = 7*1+8*4+9*7 = 7+32+63 =102 → x26
//    C[2][1] = 7*2+8*5+9*8 = 14+40+72=126 → x27
//    C[2][2] = 7*3+8*6+9*9 = 21+48+81=150 → x19
// =============================================================
module micro_rom (
    input      [5:0]  addr,
    output reg [31:0] data
);
    localparam OP   = 7'b011_0011;
    localparam MUL7 = 7'b000_0001;
    localparam ADD7 = 7'b000_0000;

    // Register numbers
    // A row 0: x1,x2,x3   row 1: x4,x5,x6   row 2: x7,x8,x9
    // B row 0: x10,x11,x12 row 1: x13,x14,x15 row 2: x16,x17,x18
    // Results: x20..x27, x19
    // Temps: x28(t0), x29(t1), x30(t2)

    always @(*) begin
        data = 32'h0000_0013; // NOP default

        case (addr)

        // ══════════════════════════════════════════════════════
        //  SOP  (addr 0..6)
        //  x17_result = x1*x2 + x3*x4 + x5*x6 + x7*x8
        //  NOTE: x17 is also B[1][2], but SOP result overwrites it.
        //        Run MATMUL first, then SOP.
        // ══════════════════════════════════════════════════════
        //  Use a dedicated result register to avoid clobbering B:
        //  Store final SOP result in x31 instead (safe scratch).
        //  tb checks x31 for SOP result.
        
        
        // =============================================================
        // SOP: x31 = x1*x2 + x3*x4 + x5*x6 + x7*x8
        // Uses:
        //   t0 = x28 (accumulator)
        //   t1 = x29 (temp)
        // =============================================================
        
//        6'd0: data = {ADD7, 5'd0,  5'd0,  3'b000, 5'd28, OP}; // add t0,x0,x0  ← RESET
//        6'd1: data = {ADD7, 5'd4,  5'd0,  3'b000, 5'd28, OP}; // add t0,x0,x0  ← RESET        
        
        6'd0: data = {MUL7, 5'd2,  5'd1,  3'b000, 5'd28, OP}; // mul t0,x1,x2
        6'd1: data = {MUL7, 5'd4,  5'd3,  3'b000, 5'd29, OP}; // mul t1,x3,x4
        6'd2: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd3: data = {MUL7, 5'd6,  5'd5,  3'b000, 5'd29, OP}; // mul t1,x5,x6
        6'd4: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd5: data = {MUL7, 5'd8,  5'd7,  3'b000, 5'd29, OP}; // mul t1,x7,x8
        6'd6: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd31, OP}; // add x31,t0,t1

        // ══════════════════════════════════════════════════════
        //  MATMUL 3×3  (addr 16..60)
        //
        //  C[i][j] = A[i][0]*B[0][j] + A[i][1]*B[1][j] + A[i][2]*B[2][j]
        //
        //  Per element: 3 MUL + 2 ADD = 5 micro-instructions
        //               but we use 2 MUL, 1 ADD, 1 MUL, 1 ADD = 5
        //  9 elements × 5 = 45 micro-instructions  (addr 16..60)
        // ══════════════════════════════════════════════════════

        // ── C[0][0] = x1*x10 + x2*x13 + x3*x16  → x20 ───────
        6'd16: data = {MUL7, 5'd10, 5'd1,  3'b000, 5'd28, OP}; // mul t0,x1,x10
        6'd17: data = {MUL7, 5'd13, 5'd2,  3'b000, 5'd29, OP}; // mul t1,x2,x13
        6'd18: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd19: data = {MUL7, 5'd16, 5'd3,  3'b000, 5'd29, OP}; // mul t1,x3,x16
        6'd20: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd20, OP}; // add x20,t0,t1

        // ── C[0][1] = x1*x11 + x2*x14 + x3*x17  → x21 ───────
        6'd21: data = {MUL7, 5'd11, 5'd1,  3'b000, 5'd28, OP}; // mul t0,x1,x11
        6'd22: data = {MUL7, 5'd14, 5'd2,  3'b000, 5'd29, OP}; // mul t1,x2,x14
        6'd23: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd24: data = {MUL7, 5'd17, 5'd3,  3'b000, 5'd29, OP}; // mul t1,x3,x17
        6'd25: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd21, OP}; // add x21,t0,t1

        // ── C[0][2] = x1*x12 + x2*x15 + x3*x18  → x22 ───────
        6'd26: data = {MUL7, 5'd12, 5'd1,  3'b000, 5'd28, OP}; // mul t0,x1,x12
        6'd27: data = {MUL7, 5'd15, 5'd2,  3'b000, 5'd29, OP}; // mul t1,x2,x15
        6'd28: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd29: data = {MUL7, 5'd18, 5'd3,  3'b000, 5'd29, OP}; // mul t1,x3,x18
        6'd30: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd22, OP}; // add x22,t0,t1

        // ── C[1][0] = x4*x10 + x5*x13 + x6*x16  → x23 ───────
        6'd31: data = {MUL7, 5'd10, 5'd4,  3'b000, 5'd28, OP}; // mul t0,x4,x10
        6'd32: data = {MUL7, 5'd13, 5'd5,  3'b000, 5'd29, OP}; // mul t1,x5,x13
        6'd33: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd34: data = {MUL7, 5'd16, 5'd6,  3'b000, 5'd29, OP}; // mul t1,x6,x16
        6'd35: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd23, OP}; // add x23,t0,t1

        // ── C[1][1] = x4*x11 + x5*x14 + x6*x17  → x24 ───────
        6'd36: data = {MUL7, 5'd11, 5'd4,  3'b000, 5'd28, OP}; // mul t0,x4,x11
        6'd37: data = {MUL7, 5'd14, 5'd5,  3'b000, 5'd29, OP}; // mul t1,x5,x14
        6'd38: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd39: data = {MUL7, 5'd17, 5'd6,  3'b000, 5'd29, OP}; // mul t1,x6,x17
        6'd40: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd24, OP}; // add x24,t0,t1

        // ── C[1][2] = x4*x12 + x5*x15 + x6*x18  → x25 ───────
        6'd41: data = {MUL7, 5'd12, 5'd4,  3'b000, 5'd28, OP}; // mul t0,x4,x12
        6'd42: data = {MUL7, 5'd15, 5'd5,  3'b000, 5'd29, OP}; // mul t1,x5,x15
        6'd43: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd44: data = {MUL7, 5'd18, 5'd6,  3'b000, 5'd29, OP}; // mul t1,x6,x18
        6'd45: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd25, OP}; // add x25,t0,t1

        // ── C[2][0] = x7*x10 + x8*x13 + x9*x16  → x26 ───────
        6'd46: data = {MUL7, 5'd10, 5'd7,  3'b000, 5'd28, OP}; // mul t0,x7,x10
        6'd47: data = {MUL7, 5'd13, 5'd8,  3'b000, 5'd29, OP}; // mul t1,x8,x13
        6'd48: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd49: data = {MUL7, 5'd16, 5'd9,  3'b000, 5'd29, OP}; // mul t1,x9,x16
        6'd50: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd26, OP}; // add x26,t0,t1

        // ── C[2][1] = x7*x11 + x8*x14 + x9*x17  → x27 ───────
        6'd51: data = {MUL7, 5'd11, 5'd7,  3'b000, 5'd28, OP}; // mul t0,x7,x11
        6'd52: data = {MUL7, 5'd14, 5'd8,  3'b000, 5'd29, OP}; // mul t1,x8,x14
        6'd53: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd54: data = {MUL7, 5'd17, 5'd9,  3'b000, 5'd29, OP}; // mul t1,x9,x17
        6'd55: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd27, OP}; // add x27,t0,t1

        // ── C[2][2] = x7*x12 + x8*x15 + x9*x18  → x19 ───────
        6'd56: data = {MUL7, 5'd12, 5'd7,  3'b000, 5'd28, OP}; // mul t0,x7,x12
        6'd57: data = {MUL7, 5'd15, 5'd8,  3'b000, 5'd29, OP}; // mul t1,x8,x15
        6'd58: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd28, OP}; // add t0,t0,t1
        6'd59: data = {MUL7, 5'd18, 5'd9,  3'b000, 5'd29, OP}; // mul t1,x9,x18
        6'd60: data = {ADD7, 5'd29, 5'd28, 3'b000, 5'd19, OP}; // add x19,t0,t1

        endcase
    end
endmodule