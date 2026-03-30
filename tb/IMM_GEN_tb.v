`timescale 1ns / 1ps

module IMM_GEN_tb;

reg  [31:0] instr;
wire [31:0] imm;

IMM_GEN dut (
    .instr(instr),
    .imm(imm)
);

task test;
    input [31:0] in_instr;
    input [255:0] name;
begin
    instr = in_instr;
    #10;
    $display("-----------------------------------------");
    $display("Test: %s", name);
    $display("Instruction = %h", instr);
    $display("Immediate   = %0d (0x%h)", $signed(imm), imm);
end
endtask


initial begin

    $display("\n=========== IMM_GEN TEST START ===========\n");

    // ---------------------------
    // I-Type: addi x1,x0,5
    // 00500093
    // ---------------------------
    test(32'h00500093, "I-TYPE +5");

    // I-Type Negative: addi x1,x0,-8
    test(32'hFF800093, "I-TYPE -8");

    // ---------------------------
    // S-Type: sw x3, 16(x0)
    // ---------------------------
    test(32'h00302023, "S-TYPE +16");

    // ---------------------------
    // B-Type: beq x1,x2,8
    // ---------------------------
    test(32'h00210463, "B-TYPE +8");

    // ---------------------------
    // U-Type: lui x7, 0x12345
    // ---------------------------
    test(32'h123453B7, "U-TYPE LUI");

    // ---------------------------
    // J-Type: jal x1, 16
    // ---------------------------
    test(32'h010000EF, "J-TYPE +16");

    $display("\n=========== IMM_GEN TEST END ===========\n");

    $stop;

end

endmodule