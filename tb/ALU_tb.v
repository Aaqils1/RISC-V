`timescale 1ns / 1ps

module ALU_tb;

reg  signed [31:0] a, b;
reg  [3:0] alu_ctrl;

wire signed [31:0] y;
wire zero, carry, sign, overflow;

reg signed [63:0] full_product;
reg signed [63:0] reconstructed;

// Instantiate ALU
ALU dut (
    .a(a),
    .b(b),
    .alu_ctrl(alu_ctrl),
    .y(y),
    .zero(zero),
    .carry(carry),
    .sign(sign),
    .overflow(overflow)
);

// Pretty operation name
reg [80*8:1] op_name;

// Generic test task
task apply_test;
    input signed [31:0] in_a;
    input signed [31:0] in_b;
    input [3:0] ctrl;
    input [80*8:1] name;
begin
    a = in_a;
    b = in_b;
    alu_ctrl = ctrl;
    op_name = name;

    #10;

    $display("-------------------------------------------------");
    $display("Operation : %s", op_name);
    $display("ALU_CTRL  : %b", alu_ctrl);
    $display("A = %0d  B = %0d", a, b);
    $display("Result = %0d (0x%h)", y, y);
    $display("Zero=%b Carry=%b Sign=%b Overflow=%b",
              zero, carry, sign, overflow);
end
endtask


initial begin

    $display("\n=========== ALU COMPLETE TEST STARTED ===========\n");

    // AND
    apply_test(6, 3, 4'b0000, "AND");

    // OR
    apply_test(6, 3, 4'b0001, "OR");

    // ADD
    apply_test(5, 5, 4'b0010, "ADD");

    // ADD Overflow
    apply_test(32'sd2147483647, 1, 4'b0010, "ADD OVERFLOW");

    // SUB
    apply_test(10, 5, 4'b0011, "SUB");

    // SUB Zero
    apply_test(5, 5, 4'b0011, "SUB ZERO");

    // SLL
    apply_test(4, 1, 4'b0100, "SHIFT LEFT");

    // SRL
    apply_test(8, 1, 4'b0101, "SHIFT RIGHT");

    // XOR
    apply_test(6, 3, 4'b0110, "XOR");


//     ======================================
//      MULTIPLICATION VERIFICATION
//     ======================================

    a = 32'sd100000;
    b = 32'sd50000;

    full_product = a * b;

    $display("\n======= MUL / MULH COMBINED TEST =======");
    $display("\n A = 0%d B = 0%d \n", a,b);
    $display("Expected Full 64-bit Product = %0d (0x%h)",
              full_product, full_product);

    // ---- MUL (lower 32 bits) ----
    alu_ctrl = 4'b0111;   // MUL
    #10;

    $display("MUL  (low 32 bits)  = 0x%h", y);

    // ---- MULH (upper 32 bits) ----
    alu_ctrl = 4'b1000;   // MULH
    #10;
    reconstructed[63:32] = y;

    $display("MULH (high 32 bits) = 0x%h", y);



    $display("\n=========== ALU TEST FINISHED ===========\n");

    $stop;
end

endmodule