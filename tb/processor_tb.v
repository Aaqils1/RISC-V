`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2026 03:25:31 AM
// Design Name: 
// Module Name: processor_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module processor_tb;

reg clk;
reg reset;

// Instantiate processor
PROCESSOR uut (
    .clk(clk),
    .reset(reset)
);

//////////////////////////////////////////////////
// CLOCK GENERATION
// 20 ns period = 50 MHz
//////////////////////////////////////////////////
initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

//////////////////////////////////////////////////
// RESET SEQUENCE
//////////////////////////////////////////////////
initial begin
    reset = 1;
    #50;          // hold reset for 5 cycles
    reset = 0;
end

//////////////////////////////////////////////////
// SIMULATION RUNTIME
//////////////////////////////////////////////////
initial begin
    #2000;        // run long enough to see loop execution
    $finish;
end

//////////////////////////////////////////////////
// OPTIONAL DEBUG PRINTS
//////////////////////////////////////////////////
initial begin
    $display("Time\tPC\tInstruction");
    $monitor("%0t\t%h\t%h",
        $time,
        uut.cpu.pc,
        uut.cpu.instr
    );
end

endmodule
