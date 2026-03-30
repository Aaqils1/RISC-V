`timescale 1ns / 1ps
module DATAPATH (
    input  clk, input  reset,
    output [31:0] dbg_pc, dbg_instr, dbg_alu_y, dbg_x19,
    output [31:0] dbg_x20, dbg_x21, dbg_x22, dbg_x23,
    output [31:0] dbg_x24, dbg_x25, dbg_x26, dbg_x27,
    output [31:0] dbg_sop, dbg_t0, dbg_t1, dbg_t2,
    output        dbg_micro_running, dbg_micro_done
);
    wire [31:0] if_pc, if_instr;
    wire [31:0] ex_pc, ex_instr_cpu;
    wire [31:0] ex_instr_micro;
    wire        micro_running, micro_done;

    // ── micro_start: 1-cycle rising-edge pulse ─────────────────
    // ex_instr_cpu is registered (output of IF_EX_REG), so
    // micro_start_raw is stable. We detect the rising edge so
    // the FSM only triggers once even though the custom opcode
    // stays in ex_instr_cpu for many cycles (stalled PC).
    wire micro_start_raw = (ex_instr_cpu[6:0] == 7'b000_1011) ||
                           (ex_instr_cpu[6:0] == 7'b010_1011);

    reg micro_start_prev;
    always @(posedge clk or posedge reset)
        if (reset) micro_start_prev <= 1'b0;
        else       micro_start_prev <= micro_start_raw;

    wire micro_start = micro_start_raw & ~micro_start_prev;

    // ── Effective instruction ──────────────────────────────────
    wire [31:0] ex_instr = micro_running ? ex_instr_micro : ex_instr_cpu;

    wire        regwrite, alusrc, memread, memwrite, memtoreg, branch, jump;
    wire [3:0]  alu_ctrl;
    wire [31:0] rd1, rd2, imm, alu_b, alu_y, mem_rd, wb;
    wire        zero, carry, sign_flag, overflow;

    // ── stall_hold ────────────────────────────────────────────
    // Set the same cycle micro_start fires (combinational path
    // ensures IF_EX_REG is held before any posedge can advance it).
    // Cleared by micro_done - the clean registered pulse from
    // MICRO_DECODER_TOP that fires exactly when FIFO drains.
    reg stall_hold;
    always @(posedge clk or posedge reset) begin
        if (reset)
            stall_hold <= 1'b0;
        else if (micro_start)   // set: latch the stall
            stall_hold <= 1'b1;
        else if (micro_done)    // clear: FIFO fully drained
            stall_hold <= 1'b0;
    end

    // micro_start is combinational (wire) so it contributes to
    // stall immediately - no 1-cycle gap before stall_hold latches
    wire stall = micro_start | stall_hold;
    wire flush = (jump | (branch & zero)) & !stall;

    // ── Stage 1: IF ───────────────────────────────────────────
    IFU ifu (
        .clk(clk),       .reset(reset),
        .jump_i(jump),   .branch_i(branch),   .zero_i(zero),
        .stall_i(stall), .imm_i(imm),
        .pc_o(if_pc),    .instr_o(if_instr)
    );

    IF_EX_REG if_ex (
        .clk(clk),       .reset(reset),
        .stall_i(stall), .flush_i(flush),
        .pc_i(if_pc),    .instr_i(if_instr),
        .pc_o(ex_pc),    .instr_o(ex_instr_cpu)
    );

    // ── Stage 2: EX ───────────────────────────────────────────
    CONTROL cu (
        .opcode(ex_instr[6:0]),   .funct3(ex_instr[14:12]),
        .funct7(ex_instr[31:25]), .regwrite(regwrite),
        .alusrc(alusrc),          .memread(memread),
        .memwrite(memwrite),      .memtoreg(memtoreg),
        .branch(branch),          .jump(jump),
        .alu_ctrl(alu_ctrl),      .micro_start()
    );

    MICRO_DECODER_TOP mdec (
        .clk(clk),              .reset(reset),
        .micro_start(micro_start),
        .opcode(ex_instr_cpu[6:0]),
        .instr_out(ex_instr_micro),
        .running(micro_running),
        .done(micro_done)
    );

    REG_FILE rf (
        .clk(clk), .we(regwrite),
        .rs1(ex_instr[19:15]), .rs2(ex_instr[24:20]),
        .rd(ex_instr[11:7]),   .wd(wb),
        .rd1(rd1), .rd2(rd2),
        .dbg_x19(dbg_x19), .dbg_x20(dbg_x20), .dbg_x21(dbg_x21),
        .dbg_x22(dbg_x22), .dbg_x23(dbg_x23), .dbg_x24(dbg_x24),
        .dbg_x25(dbg_x25), .dbg_x26(dbg_x26), .dbg_x27(dbg_x27),
        .dbg_sop(dbg_sop),  .dbg_t0(dbg_t0),  .dbg_t1(dbg_t1),
        .dbg_t2(dbg_t2)
    );

    IMM_GEN ig (.instr(ex_instr), .imm(imm));

    assign alu_b = alusrc ? imm : rd2;
    ALU alu (
        .a(rd1), .b(alu_b), .alu_ctrl(alu_ctrl),
        .y(alu_y), .zero(zero), .carry(carry),
        .sign(sign_flag), .overflow(overflow)
    );

    DATA_MEM dm (
        .clk(clk), .memread(memread), .memwrite(memwrite),
        .addr(alu_y), .wd(rd2), .rd(mem_rd)
    );

    assign wb = jump     ? (ex_pc + 32'd4) :
                memtoreg ? mem_rd           :
                           alu_y;

    assign dbg_pc            = if_pc;
    assign dbg_instr         = ex_instr;
    assign dbg_alu_y         = alu_y;
    assign dbg_micro_running = micro_running;
    assign dbg_micro_done    = micro_done;
endmodule