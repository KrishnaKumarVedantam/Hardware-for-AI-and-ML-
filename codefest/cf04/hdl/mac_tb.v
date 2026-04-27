// Testbench for MAC unit
// Tests: a=3,b=4 for 3 cycles, rst, then a=-5,b=2 for 2 cycles

`timescale 1ns/1ps

module mac_tb;

    // inputs
    reg        clk;
    reg        rst;
    reg signed [7:0]  a;
    reg signed [7:0]  b;

    // output
    wire signed [31:0] out;

    // instantiate the MAC (testing LLM A first)
    mac uut (
        .clk(clk),
        .rst(rst),
        .a(a),
        .b(b),
        .out(out)
    );

    // clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // test sequence
    initial begin
        $dumpfile("mac_tb.vcd");
        $dumpvars(0, mac_tb);

        // initialize
        rst = 1; a = 0; b = 0;
        @(posedge clk); #1;

        // release reset
        rst = 0;
        a = 3; b = 4;

        // cycle 1: expect out = 12
        @(posedge clk); #1;
        $display("Cycle 1: out = %0d (expect 12)", out);

        // cycle 2: expect out = 24
        @(posedge clk); #1;
        $display("Cycle 2: out = %0d (expect 24)", out);

        // cycle 3: expect out = 36
        @(posedge clk); #1;
        $display("Cycle 3: out = %0d (expect 36)", out);

        // assert reset
        rst = 1;
        @(posedge clk); #1;
        $display("After rst: out = %0d (expect 0)", out);

        // release reset, apply a=-5, b=2
        rst = 0;
        a = -5; b = 2;

        // cycle 1: expect out = -10
        @(posedge clk); #1;
        $display("Cycle 4: out = %0d (expect -10)", out);

        // cycle 2: expect out = -20
        @(posedge clk); #1;
        $display("Cycle 5: out = %0d (expect -20)", out);

        $display("Simulation done!");
        $finish;
    end

endmodule
