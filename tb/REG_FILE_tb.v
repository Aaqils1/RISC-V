`timescale 1ns / 1ps

module REG_FILE_tb;

reg clk;
reg we;
reg [4:0] rs1, rs2, rd;
reg [31:0] wd;
wire [31:0] rd1, rd2;

// Instantiate DUT
REG_FILE dut (
    .clk(clk),
    .we(we),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .wd(wd),
    .rd1(rd1),
    .rd2(rd2)
);

// Clock generation
always #5 clk = ~clk;

// Task for display
task show_state;
begin
    #1;
    $display("Time=%0t | we=%b | rs1=%0d rs2=%0d rd=%0d wd=%0d | rd1=%0d rd2=%0d",
             $time, we, rs1, rs2, rd, wd, rd1, rd2);
end
endtask

initial begin

    clk = 0;
    we = 0;
    rs1 = 0;
    rs2 = 0;
    rd  = 0;
    wd  = 0;

    $display("\n=========== REGISTER FILE TEST START ===========\n");

    // ---------------------------------------
    // 1️⃣ Check initial values
    // ---------------------------------------
    rs1 = 5;
    rs2 = 10;
    show_state();  // should show rd1=5, rd2=10

    // ---------------------------------------
    // 2️⃣ Write to register 8
    // ---------------------------------------
    rd = 8;
    wd = 12345;
    we = 1;
    #10;   // wait for posedge
    we = 0;

    rs1 = 8;
    show_state();  // rd1 should now be 12345

    // ---------------------------------------
    // 3️⃣ Write disabled test
    // ---------------------------------------
    rd = 9;
    wd = 55555;
    we = 0;
    #10;

    rs1 = 9;
    show_state();  // should still show initial value (9)

    // ---------------------------------------
    // 4️⃣ Try writing to x0 (should NOT change)
    // ---------------------------------------
    rd = 0;
    wd = 99999;
    we = 1;
    #10;
    we = 0;

    rs1 = 0;
    show_state();  // must remain 0

    // ---------------------------------------
    // 5️⃣ Simultaneous read + write
    // ---------------------------------------
    rd = 12;
    wd = 777;
    rs1 = 12;
    we = 1;
    #10;
    we = 0;

    show_state();  // rd1 should be 777

    // ---------------------------------------
    // 6️⃣ Multiple writes
    // ---------------------------------------
    rd = 15; wd = 1500; we = 1; #10;
    rd = 16; wd = 1600; #10;
    rd = 17; wd = 1700; #10;
    we = 0;

    rs1 = 15; rs2 = 16;
    show_state();

    rs1 = 17;
    show_state();

    $display("\n=========== REGISTER FILE TEST COMPLETE ===========\n");

    $stop;

end

endmodule