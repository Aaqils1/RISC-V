`timescale 1ns / 1ps

module CONTROL_tb;

reg [6:0] opcode;
reg [2:0] funct3;
reg [6:0] funct7;

wire regwrite, alusrc, memread, memwrite;
wire memtoreg, branch, jump;
wire [3:0] alu_ctrl;

// Instantiate DUT
CONTROL dut(
    opcode, funct3, funct7,
    regwrite, alusrc, memread, memwrite,
    memtoreg, branch, jump,
    alu_ctrl
);

// Task to display state
task show;
    input [255:0] name;
begin
    #5;
    $display("--------------------------------------------------");
    $display("Instruction : %s", name);
    $display("opcode=%b funct3=%b funct7=%b", opcode, funct3, funct7);
    $display("regwrite=%b alusrc=%b memread=%b memwrite=%b",
              regwrite, alusrc, memread, memwrite);
    $display("memtoreg=%b branch=%b jump=%b alu_ctrl=%b",
              memtoreg, branch, jump, alu_ctrl);
end
endtask


initial begin

    $display("\n=========== CONTROL UNIT TEST START ===========\n");

    // ---------------------------------
    // R-Type ADD
    // ---------------------------------
    opcode = 7'b0110011;
    funct3 = 3'b000;
    funct7 = 7'b0000000;
    show("R-TYPE ADD");

    // ---------------------------------
    // R-Type SUB
    // ---------------------------------
    funct7 = 7'b0100000;
    show("R-TYPE SUB");

    // ---------------------------------
    // I-Type ADDI
    // ---------------------------------
    opcode = 7'b0010011;
    show("I-TYPE ADDI");

    // ---------------------------------
    // Load LW
    // ---------------------------------
    opcode = 7'b0000011;
    show("LOAD LW");

    // ---------------------------------
    // Store SW
    // ---------------------------------
    opcode = 7'b0100011;
    show("STORE SW");

    // ---------------------------------
    // Branch BEQ
    // ---------------------------------
    opcode = 7'b1100011;
    show("BRANCH BEQ");

    // ---------------------------------
    // Jump JAL
    // ---------------------------------
    opcode = 7'b1101111;
    show("JUMP JAL");

    // ---------------------------------
    // U-Type LUI
    // ---------------------------------
    opcode = 7'b0110111;
    show("U-TYPE LUI");

    $display("\n=========== CONTROL UNIT TEST END ===========\n");

    $stop;

end

endmodule