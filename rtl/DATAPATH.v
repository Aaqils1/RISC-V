`timescale 1ns / 1ps
// =============================================================
//  DATAPATH  -  Fixed: forwarding mux removed
//
//  ROOT CAUSE OF WRONG RESULTS WAS:
//  HAZARD_UNIT set forward_a=1 when ex_rd==ex_rs1 (same instr).
//  This fired on "add t0, t0, t1" (rd=28, rs1=28).
//  wb_reg (previous instr's result) was used instead of regf[t0].
//  Fix: remove forwarding mux. Use rd1/rd2 directly from REG_FILE.
// =============================================================
module DATAPATH (
    input  clk, input  reset,
    output [31:0] dbg_pc, dbg_instr, dbg_alu_y, dbg_x19,
    output [31:0] dbg_x20, dbg_x21, dbg_x22, dbg_x23,
    output [31:0] dbg_x24, dbg_x25, dbg_x26, dbg_x27,
    output [31:0] dbg_sop, dbg_t0, dbg_t1, dbg_t2,
    output        dbg_micro_running, dbg_micro_done,
    output        dbg_raw_hazard, dbg_load_use,
    output        dbg_forward_a, dbg_forward_b,
    output        dbg_power_gate_if, dbg_if_ex_clk_en
);
    wire [31:0] if_pc, if_instr, ex_pc, ex_instr_cpu;
    wire [31:0] ex_instr_micro;
    wire        micro_running, micro_done;

    wire micro_start_raw = (ex_instr_cpu[6:0] == 7'b000_1011) ||
                           (ex_instr_cpu[6:0] == 7'b010_1011);
    reg  micro_start_prev;
    always @(posedge clk or posedge reset) begin
        if (reset) micro_start_prev <= 1'b0;
        else       micro_start_prev <= micro_start_raw;
    end
    wire micro_start = micro_start_raw & ~micro_start_prev;

    wire [31:0] ex_instr = micro_running ? ex_instr_micro : ex_instr_cpu;

    wire        regwrite, alusrc, memread, memwrite, memtoreg, branch, jump;
    wire [3:0]  alu_ctrl;
    wire        ctrl_unused;
    wire [31:0] rd1, rd2, imm, alu_b, alu_y, mem_rd, wb;
    wire        zero, carry, sign_flag, overflow;

    wire pc_stall, if_ex_stall, if_ex_clk_en, if_ex_flush, power_gate_if;
    wire forward_a, forward_b, raw_hazard_det, load_use_det;

    HAZARD_UNIT hu (
        .ex_rs1(ex_instr[19:15]), .ex_rs2(ex_instr[24:20]),
        .ex_rd(ex_instr[11:7]),   .ex_regwrite(regwrite),
        .ex_memread(memread),     .branch(branch),
        .jump(jump),              .zero(zero),
        .micro_running(micro_running),
        .pc_stall(pc_stall),      .if_ex_stall(if_ex_stall),
        .if_ex_clk_en(if_ex_clk_en), .if_ex_flush(if_ex_flush),
        .power_gate_if(power_gate_if),
        .forward_a(forward_a),    .forward_b(forward_b),
        .raw_hazard_detected(raw_hazard_det),
        .load_use_detected(load_use_det)
    );

    IFU ifu (
        .clk(clk), .reset(reset),
        .jump_i(jump), .branch_i(branch), .zero_i(zero),
        .pc_stall_i(pc_stall), .power_gate_i(power_gate_if),
        .imm_i(imm), .pc_o(if_pc), .instr_o(if_instr)
    );

    IF_EX_REG if_ex (
        .clk(clk), .reset(reset),
        .clk_en(if_ex_clk_en), .flush_i(if_ex_flush),
        .pc_i(if_pc), .instr_i(if_instr),
        .pc_o(ex_pc), .instr_o(ex_instr_cpu)
    );

    CONTROL cu (
        .opcode(ex_instr[6:0]), .funct3(ex_instr[14:12]),
        .funct7(ex_instr[31:25]), .regwrite(regwrite),
        .alusrc(alusrc), .memread(memread), .memwrite(memwrite),
        .memtoreg(memtoreg), .branch(branch), .jump(jump),
        .alu_ctrl(alu_ctrl), .micro_start(ctrl_unused)
    );

    MICRO_DECODER_TOP mdec (
        .clk(clk), .reset(reset),
        .micro_start(micro_start), .opcode(ex_instr_cpu[6:0]),
        .instr_out(ex_instr_micro), .running(micro_running), .done(micro_done)
    );

    REG_FILE rf (
        .clk(clk), .we(regwrite),
        .rs1(ex_instr[19:15]), .rs2(ex_instr[24:20]),
        .rd(ex_instr[11:7]),   .wd(wb),
        .rd1(rd1), .rd2(rd2),
        .dbg_x19(dbg_x19),
        .dbg_x20(dbg_x20), .dbg_x21(dbg_x21), .dbg_x22(dbg_x22),
        .dbg_x23(dbg_x23), .dbg_x24(dbg_x24), .dbg_x25(dbg_x25),
        .dbg_x26(dbg_x26), .dbg_x27(dbg_x27),
        .dbg_sop(dbg_sop), .dbg_t0(dbg_t0), .dbg_t1(dbg_t1), .dbg_t2(dbg_t2)
    );

    IMM_GEN ig (.instr(ex_instr), .imm(imm));

    // ── ALU: rd1/rd2 directly - NO forwarding mux ─────────────
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
    assign dbg_raw_hazard    = raw_hazard_det;
    assign dbg_load_use      = load_use_det;
    assign dbg_forward_a     = forward_a;
    assign dbg_forward_b     = forward_b;
    assign dbg_power_gate_if = power_gate_if;
    assign dbg_if_ex_clk_en  = if_ex_clk_en;
endmodule