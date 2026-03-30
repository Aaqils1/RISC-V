`timescale 1ns / 1ps
// =============================================================
//  Testbench
//
//  Expected:
//    MATMUL 3×3  A=B=[[1,2,3],[4,5,6],[7,8,9]]:
//      x20=30  x21=36  x22=42
//      x23=66  x24=81  x25=96
//      x26=102 x27=126 x19=150
//    SOP  x1*x2+x3*x4+x5*x6+x7*x8 = 1*2+3*4+5*6+7*8 = 100
//      result in x31 (dbg_sop)
//
//  Cycle budget:
//    MATMUL: 45 micro-instrs + 2 overhead = ~47 cycles
//    Normal instrs: ~10 cycles
//    SOP: 7 micro-instrs + 2 overhead = ~9 cycles
//    Total: ~70 cycles - run 120 to be safe
// =============================================================
module tb_DATAPATH;

    reg clk, reset;

    wire [31:0] dbg_pc, dbg_instr, dbg_alu_y;
    wire [31:0] dbg_x19;
    wire [31:0] dbg_x20, dbg_x21, dbg_x22;
    wire [31:0] dbg_x23, dbg_x24, dbg_x25;
    wire [31:0] dbg_x26, dbg_x27;
    wire [31:0] dbg_sop;
    wire [31:0] dbg_t0, dbg_t1, dbg_t2;
    wire        dbg_micro_running, dbg_micro_done;

    DATAPATH dut (
        .clk              (clk),
        .reset            (reset),
        .dbg_pc           (dbg_pc),
        .dbg_instr        (dbg_instr),
        .dbg_alu_y        (dbg_alu_y),
        .dbg_x19          (dbg_x19),
        .dbg_x20          (dbg_x20), .dbg_x21 (dbg_x21), .dbg_x22 (dbg_x22),
        .dbg_x23          (dbg_x23), .dbg_x24 (dbg_x24), .dbg_x25 (dbg_x25),
        .dbg_x26          (dbg_x26), .dbg_x27 (dbg_x27),
        .dbg_sop          (dbg_sop),
        .dbg_t0           (dbg_t0),  .dbg_t1  (dbg_t1),  .dbg_t2  (dbg_t2),
        .dbg_micro_running(dbg_micro_running),
        .dbg_micro_done   (dbg_micro_done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("riscv_pipeline.vcd");
        $dumpvars(0, tb_DATAPATH);
    end

    integer cycle;
    integer pass_count, fail_count;

    initial begin
        pass_count = 0; fail_count = 0;

        $display("=======================================================");
        $display(" 2-Stage RISC-V  |  3x3 MATMUL + SOP simulation");
        $display("=======================================================");

        reset = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;
        $display("[t=%0t] Reset released", $time);

        for (cycle = 0; cycle < 120; cycle = cycle + 1) begin
            @(posedge clk); #1;

            if (dbg_micro_running && cycle % 10 == 0)
                $display("[cyc %3d] micro running | t0=%0d t1=%0d t2=%0d",
                         cycle, dbg_t0, dbg_t1, dbg_t2);

            if (dbg_micro_done)
                $display("[cyc %3d] *** micro-program DONE ***", cycle);
        end

        // ── RESULTS ───────────────────────────────────────────
        $display("");
        $display("=======================================================");
        $display(" MATMUL 3x3  (A=B=[[1,2,3],[4,5,6],[7,8,9]])");
        $display("=======================================================");
        $display("  x20 C[0][0] = %3d  (expected  30)", dbg_x20);
        $display("  x21 C[0][1] = %3d  (expected  36)", dbg_x21);
        $display("  x22 C[0][2] = %3d  (expected  42)", dbg_x22);
        $display("  x23 C[1][0] = %3d  (expected  66)", dbg_x23);
        $display("  x24 C[1][1] = %3d  (expected  81)", dbg_x24);
        $display("  x25 C[1][2] = %3d  (expected  96)", dbg_x25);
        $display("  x26 C[2][0] = %3d  (expected 102)", dbg_x26);
        $display("  x27 C[2][1] = %3d  (expected 126)", dbg_x27);
        $display("  x19 C[2][2] = %3d  (expected 150)", dbg_x19);

        if (dbg_x20===32'd30  && dbg_x21===32'd36  && dbg_x22===32'd42  &&
            dbg_x23===32'd66  && dbg_x24===32'd81  && dbg_x25===32'd96  &&
            dbg_x26===32'd102 && dbg_x27===32'd126 && dbg_x19===32'd150)
        begin
            $display("  >> MATMUL PASS"); pass_count = pass_count + 1;
        end else begin
            $display("  >> MATMUL FAIL"); fail_count = fail_count + 1;
        end

        $display("");
        $display("=======================================================");
        $display(" SOP  5*5 + 10*4 + 24*6 + 7*8 = 25 + 40 + 144 + 56 = 265");
        $display("=======================================================");
        $display("  x31 (SOP) = %0d  (expected 100)", dbg_sop);
        if (dbg_sop === 32'd265) begin
            $display("  >> SOP PASS"); pass_count = pass_count + 1;
        end else begin
            $display("  >> SOP FAIL"); fail_count = fail_count + 1;
        end

        $display("");
        $display("=======================================================");
        $display(" SUMMARY: %0d PASS  /  %0d FAIL", pass_count, fail_count);
        $display("=======================================================");
        $finish;
    end
endmodule