`timescale 1ns / 1ps

module DATA_MEM_tb;

reg clk;
reg memread, memwrite;
reg [31:0] addr;
reg [31:0] wd;
wire [31:0] rd;

// Instantiate DUT
DATA_MEM dut (
    .clk(clk),
    .memread(memread),
    .memwrite(memwrite),
    .addr(addr),
    .wd(wd),
    .rd(rd)
);

// Clock generation
always #5 clk = ~clk;

// Display task
task show;
begin
    #1;
    $display("Time=%0t | addr=%0d | memwrite=%b memread=%b | wd=%0d | rd=%0d",
             $time, addr, memwrite, memread, wd, rd);
end
endtask

initial begin

    clk = 0;
    memread = 0;
    memwrite = 0;
    addr = 0;
    wd = 0;

    $display("\n=========== DATA MEMORY TEST START ===========\n");

    // -------------------------------------
    // 1️⃣ Write 100 to address 0
    // -------------------------------------
    addr = 0;
    wd = 100;
    memwrite = 1;
    #10;  // wait posedge
    memwrite = 0;
    show();

    // -------------------------------------
    // 2️⃣ Read from address 0
    // -------------------------------------
    memread = 1;
    #5;
    show();
    memread = 0;

    // -------------------------------------
    // 3️⃣ Write to address 4 (next word)
    // -------------------------------------
    addr = 4;
    wd = 200;
    memwrite = 1;
    #10;
    memwrite = 0;

    // Read it
    memread = 1;
    #5;
    show();
    memread = 0;

    // -------------------------------------
    // 4️⃣ Ensure write disabled works
    // -------------------------------------
    addr = 8;
    wd = 300;
    memwrite = 0;
    #10;

    memread = 1;
    #5;
    show();  // should be 0 (never written)
    memread = 0;

    // -------------------------------------
    // 5️⃣ Multiple writes
    // -------------------------------------
    addr = 12; wd = 400; memwrite = 1; #10;
    addr = 16; wd = 500; #10;
    memwrite = 0;

    // Read both
    memread = 1;

    addr = 12; #5; show();
    addr = 16; #5; show();

    memread = 0;

    $display("\n=========== DATA MEMORY TEST COMPLETE ===========\n");

    $stop;

end

endmodule