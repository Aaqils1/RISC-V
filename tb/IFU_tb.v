`timescale 1ns / 1ps

module IFU_tb;

reg clk;
reg reset;
reg jump;
reg branch;
reg zero;
reg [31:0] imm;

wire [31:0] pc;
wire [31:0] instr;

// Instantiate IFU
IFU dut(
    .clk(clk),
    .reset(reset),
    .jump(jump),
    .branch(branch),
    .zero(zero),
    .imm(imm),
    .pc(pc),
    .instr(instr)
);

// Clock generation
always #5 clk = ~clk;

initial begin
    $display("Time\tPC\tInstruction\tjump branch zero imm");

    clk = 0;
    reset = 1;
    jump = 0;
    branch = 0;
    zero = 0;
    imm = 0;

    #10 reset = 0;   // Release reset

    // ==============================
    // 1️⃣ Normal sequential execution
    // ==============================
    #40;

    // ==============================
    // 2️⃣ Test JUMP
    // ==============================
    imm = 8;
    jump = 1;
    #10;
    jump = 0;

    #20;

    // ==============================
    // 3️⃣ Test BRANCH TAKEN
    // ==============================
    imm = 8;
    branch = 1;
    zero = 1;
    #10;
    branch = 0;
    zero = 0;

    #20;

    // ==============================
    // 4️⃣ Test BRANCH NOT TAKEN
    // ==============================
    imm = 8;
    branch = 1;
    zero = 0;
    #10;
    branch = 0;

    #20;

    // ==============================
    // 5️⃣ Let PC run until stop at 32
    // ==============================
    #100;

    $finish;
end

// Monitor signals
initial begin
    $monitor("%0t\t%h\t%h\t%b\t%b\t%b\t%h",
             $time, pc, instr, jump, branch, zero, imm);
end

endmodule