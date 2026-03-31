`timescale 1ns / 1ps
// =============================================================
//  HAZARD_UNIT  -  Fixed: forwarding disabled
//
//  ROOT CAUSE OF WRONG RESULTS:
//  The original HAZARD_UNIT set forward_a=1 when ex_rd==ex_rs1
//  within the SAME instruction. This fires for instructions like
//  "add t0, t0, t1" where rd=t0=28 and rs1=t0=28 - meaning the
//  instruction reads the register it writes. The hazard unit
//  incorrectly forwarded wb_reg (previous instruction's result)
//  instead of letting the register file provide the correct value.
//
//  WHY forwarding is NOT needed in this 2-stage pipeline:
//  The pipeline has only IF and EX stages. The register file has
//  ASYNCHRONOUS reads. A write at posedge N makes the new value
//  visible to async reads immediately in cycle N+1. Since there
//  is only ONE instruction between write and next read (the pipeline
//  register holds each instruction for exactly one EX cycle), the
//  new value is always ready when the next instruction needs it.
//
//  THEREFORE: forward_a and forward_b are always 0.
//  The DATAPATH uses rd1/rd2 directly (no forwarding mux).
//
//  Stall and flush logic is preserved correctly.
// =============================================================
module HAZARD_UNIT (
    input      [4:0]  ex_rs1,
    input      [4:0]  ex_rs2,
    input      [4:0]  ex_rd,
    input             ex_regwrite,
    input             ex_memread,
    input             branch,
    input             jump,
    input             zero,
    input             micro_running,

    output            pc_stall,
    output            if_ex_stall,
    output            if_ex_clk_en,
    output            if_ex_flush,
    output            power_gate_if,
    output            forward_a,
    output            forward_b,
    output            raw_hazard_detected,
    output            load_use_detected
);
    // ── Control hazard ────────────────────────────────────────
    wire branch_taken   = branch & zero;
    wire control_hazard = branch_taken | jump;

    // ── RAW / load-use detection (diagnostic only) ────────────
    // These are informational - they do NOT drive stalls or
    // forwarding in this pipeline (async reads resolve them).
    wire raw_rs1 = ex_regwrite && (ex_rd != 5'd0) && (ex_rd == ex_rs1);
    wire raw_rs2 = ex_regwrite && (ex_rd != 5'd0) && (ex_rd == ex_rs2);

    assign raw_hazard_detected = raw_rs1 | raw_rs2;
    assign load_use_detected   = ex_memread &&
                                 (ex_rd != 5'd0) &&
                                 ((ex_rd == ex_rs1) || (ex_rd == ex_rs2));

    // ── Forwarding: DISABLED ──────────────────────────────────
    // In a 2-stage pipeline with async register reads, RAW hazards
    // resolve automatically. Forwarding is NOT needed and causes
    // INCORRECT results when rd==rs1 in the same instruction
    // (e.g. add t0, t0, t1) because it uses wb_reg (previous
    // instruction's result) instead of the correct register value.
    assign forward_a = 1'b0;
    assign forward_b = 1'b0;

    // ── Stall ─────────────────────────────────────────────────
    wire micro_stall = micro_running;

    assign pc_stall    = micro_stall;
    assign if_ex_stall = micro_stall;
    assign if_ex_clk_en = ~if_ex_stall;

    // ── Flush ─────────────────────────────────────────────────
    assign if_ex_flush = control_hazard & ~if_ex_stall;

    // ── Power gate ────────────────────────────────────────────
    assign power_gate_if = micro_running;

endmodule