`timescale 1ns / 1ps
// =============================================================
//  DATAPATH  -  Loop-free, registered micro_start pulse
//
//  How the combinational loop is broken:
//
//  OLD (broken):
//    ex_instr_cpu[6:0] → micro_start (combinational)
//    → FSM running (registered) → ex_instr mux
//    → instr_out (combinational ROM) → ex_instr
//    → CONTROL → ... (no loop, but micro_start re-checked
//    every delta because ex_instr changes with running)
//
//  The actual loop was:
//    wb (combinational) → REG_FILE forwarding → rd1/rd2
//    → ALU → alu_y → wb  [FIXED by removing forwarding]
//
//  And secondary concern:
//    micro_start held high continuously while custom opcode
//    is in ex_instr_cpu (stalled PC) → FSM re-triggered.
//
//  FINAL FIX - micro_start as a registered 1-cycle pulse:
//    micro_start_raw = (ex_instr_cpu == custom_opcode)
//    micro_start     = micro_start_raw & ~micro_start_prev
//    micro_start_prev is registered
//
//  This gives a clean rising-edge pulse that fires EXACTLY
//  ONCE per custom instruction, regardless of how long the
//  custom opcode stays in ex_instr_cpu.
//
//  The FSM's WAIT state provides a secondary guard, but the
//  pulse generator is the primary mechanism.
// =============================================================
module DATAPATH (
    input  clk,
    input  reset,

    output [31:0] dbg_pc,
    output [31:0] dbg_instr,
    output [31:0] dbg_alu_y,
    output [31:0] dbg_x19,
    output [31:0] dbg_x20, dbg_x21, dbg_x22,
    output [31:0] dbg_x23, dbg_x24, dbg_x25,
    output [31:0] dbg_x26, dbg_x27,
    output [31:0] dbg_sop,
    output [31:0] dbg_t0, dbg_t1, dbg_t2,
    output        dbg_micro_running,
    output        dbg_micro_done
);
    // ── IF stage ──────────────────────────────────────────────
    wire [31:0] if_pc, if_instr;

    // ── Pipeline register outputs (REGISTERED - loop safe) ────
    wire [31:0] ex_pc, ex_instr_cpu;

    // ── Micro decoder outputs ─────────────────────────────────
    wire [31:0] ex_instr_micro;  // combinational ROM output
    wire        micro_running;   // registered FSM output
    wire        micro_done;      // registered FSM output (1-cycle pulse)

    // ── micro_start: rising-edge pulse generator ───────────────
    // Detects the FIRST cycle that a custom opcode appears in
    // ex_instr_cpu. Fires for exactly 1 cycle per instruction.
    // This is derived from ex_instr_cpu (registered), not from
    // any combinational signal - fully loop safe.
    wire micro_start_raw = (ex_instr_cpu[6:0] == 7'b000_1011) ||  // SOP
                           (ex_instr_cpu[6:0] == 7'b010_1011);    // MATMUL

    reg micro_start_prev;
    always @(posedge clk or posedge reset) begin
        if (reset) micro_start_prev <= 1'b0;
        else        micro_start_prev <= micro_start_raw;
    end

    // 1-cycle pulse: high only on the rising edge of micro_start_raw
    wire micro_start = micro_start_raw & ~micro_start_prev;

    // ── Effective instruction mux ─────────────────────────────
    wire [31:0] ex_instr = micro_running ? ex_instr_micro : ex_instr_cpu;

    // ── Control signals ───────────────────────────────────────
    wire        regwrite, alusrc, memread, memwrite, memtoreg, branch, jump;
    wire [3:0]  alu_ctrl;
    wire        ctrl_micro_start_unused;

    // ── EX datapath wires ─────────────────────────────────────
    wire [31:0] rd1, rd2, imm, alu_b, alu_y, mem_rd, wb;
    wire        zero, carry, sign_flag, overflow;

    // ── Stall / Flush ─────────────────────────────────────────
    wire stall = micro_running;
    wire flush = (jump | (branch & zero)) & !stall;

    // =========================================================
    //  STAGE 1: Instruction Fetch
    // =========================================================
    IFU ifu (
        .clk      (clk),
        .reset    (reset),
        .jump_i   (jump),
        .branch_i (branch),
        .zero_i   (zero),
        .stall_i  (stall),
        .imm_i    (imm),
        .pc_o     (if_pc),
        .instr_o  (if_instr)
    );

    IF_EX_REG if_ex (
        .clk     (clk),   .reset   (reset),
        .stall_i (stall), .flush_i (flush),
        .pc_i    (if_pc), .instr_i (if_instr),
        .pc_o    (ex_pc), .instr_o (ex_instr_cpu)
    );

    // =========================================================
    //  STAGE 2: Execute
    // =========================================================

    // ── Control ───────────────────────────────────────────────
    // Decode ex_instr (muxed: micro or cpu) for all execution
    // control signals. micro_start handled separately above.
    CONTROL cu (
        .opcode      (ex_instr[6:0]),
        .funct3      (ex_instr[14:12]),
        .funct7      (ex_instr[31:25]),
        .regwrite    (regwrite),
        .alusrc      (alusrc),
        .memread     (memread),
        .memwrite    (memwrite),
        .memtoreg    (memtoreg),
        .branch      (branch),
        .jump        (jump),
        .alu_ctrl    (alu_ctrl),
        .micro_start (ctrl_micro_start_unused)
    );

    // ── Micro Decoder ─────────────────────────────────────────
    MICRO_DECODER_TOP mdec (
        .clk         (clk),
        .reset       (reset),
        .micro_start (micro_start),         // 1-cycle registered pulse
        .opcode      (ex_instr_cpu[6:0]),   // registered - which custom op
        .instr_out   (ex_instr_micro),      // combinational ROM output
        .running     (micro_running),
        .done        (micro_done)
    );

    // ── Register File ─────────────────────────────────────────
    // No forwarding - pure register array read (loop safe)
    REG_FILE rf (
        .clk     (clk),
        .we      (regwrite),
        .rs1     (ex_instr[19:15]),
        .rs2     (ex_instr[24:20]),
        .rd      (ex_instr[11:7]),
        .wd      (wb),
        .rd1     (rd1),   .rd2 (rd2),
        .dbg_x19 (dbg_x19),
        .dbg_x20 (dbg_x20), .dbg_x21 (dbg_x21), .dbg_x22 (dbg_x22),
        .dbg_x23 (dbg_x23), .dbg_x24 (dbg_x24), .dbg_x25 (dbg_x25),
        .dbg_x26 (dbg_x26), .dbg_x27 (dbg_x27),
        .dbg_sop (dbg_sop),
        .dbg_t0  (dbg_t0),  .dbg_t1  (dbg_t1),  .dbg_t2  (dbg_t2)
    );

    // ── IMM GEN ───────────────────────────────────────────────
    IMM_GEN ig (.instr (ex_instr), .imm (imm));

    // ── ALU ───────────────────────────────────────────────────
    assign alu_b = alusrc ? imm : rd2;
    ALU alu (
        .a        (rd1),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .y        (alu_y),
        .zero     (zero),
        .carry    (carry),
        .sign     (sign_flag),
        .overflow (overflow)
    );

    // ── Data Memory ───────────────────────────────────────────
    DATA_MEM dm (
        .clk      (clk),
        .memread  (memread),
        .memwrite (memwrite),
        .addr     (alu_y),
        .wd       (rd2),
        .rd       (mem_rd)
    );

    // ── Writeback ─────────────────────────────────────────────
    assign wb = jump     ? (ex_pc + 32'd4) :
                memtoreg ? mem_rd           :
                           alu_y;

    // ── Debug ─────────────────────────────────────────────────
    assign dbg_pc            = if_pc;
    assign dbg_instr         = ex_instr;
    assign dbg_alu_y         = alu_y;
    assign dbg_micro_running = micro_running;
    assign dbg_micro_done    = micro_done;
endmodule