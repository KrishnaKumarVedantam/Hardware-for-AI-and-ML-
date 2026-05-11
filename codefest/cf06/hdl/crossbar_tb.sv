// =============================================================
// crossbar_tb.sv  (final, verified — ECE 410/510 Codefest 6)
//
// Prof spec (Task 5 verbatim):
//   "Load weights [[1,−1,1,−1],[1,1,−1,−1],[−1,1,1,−1],[−1,−1,−1,1]],
//    apply input [10, 20, 30, 40], compute the expected outputs by hand,
//    simulate, and confirm the results match."
//
// Hand-calculated expected outputs (out[j] = Σ_i W[i][j]·in[i]):
//   out[0] = (+1)·10+(+1)·20+(−1)·30+(−1)·40 = 10+20−30−40 = −40
//   out[1] = (−1)·10+(+1)·20+(+1)·30+(−1)·40 = −10+20+30−40 =   0
//   out[2] = (+1)·10+(−1)·20+(+1)·30+(−1)·40 = 10−20+30−40 = −20
//   out[3] = (−1)·10+(−1)·20+(−1)·30+(+1)·40 = −10−20−30+40 = −20
//
// weight_in encoding: bit[i*4+j] = 1 → W[i][j]=+1, 0 → W[i][j]=−1
//   Row0 [1,−1,1,−1]  → bits[3:0]  = 4'b0101
//   Row1 [1,1,−1,−1]  → bits[7:4]  = 4'b0011
//   Row2 [−1,1,1,−1]  → bits[11:8] = 4'b0110
//   Row3 [−1,−1,−1,1] → bits[15:12]= 4'b1000
//   Combined → 16'b1000_0110_0011_0101 = 16'h8635
// =============================================================
`timescale 1ns/1ps

module crossbar_tb;

    // ---- DUT signals ----
    logic        clk, rst_n, load_w;
    logic [15:0] weight_in;
    logic signed [7:0]  in0, in1, in2, in3;
    logic signed [10:0] out0, out1, out2, out3;  // 11-bit: covers 4×128=512

    // ---- DUT instantiation ----
    crossbar_mac dut (
        .clk(clk), .rst_n(rst_n), .load_w(load_w),
        .weight_in(weight_in),
        .in0(in0), .in1(in1), .in2(in2), .in3(in3),
        .out0(out0), .out1(out1), .out2(out2), .out3(out3)
    );

    // ---- 10 ns clock ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Counters ----
    int pass_count = 0, fail_count = 0;

    // ---- Check helper ----
    task automatic check(
        input string nm,
        input signed [10:0] e0, e1, e2, e3
    );
        if (out0===e0 && out1===e1 && out2===e2 && out3===e3) begin
            $display("  [PASS] %-35s out=[%0d, %0d, %0d, %0d]",
                     nm, out0, out1, out2, out3);
            pass_count++;
        end else begin
            $display("  [FAIL] %s", nm);
            $display("         Expected: [%0d, %0d, %0d, %0d]", e0, e1, e2, e3);
            $display("         Got:      [%0d, %0d, %0d, %0d]",
                     out0, out1, out2, out3);
            fail_count++;
        end
    endtask

    // ---- Helpers ----
    task tick(input int n); repeat(n) @(posedge clk); #1; endtask

    task load_weights(input logic [15:0] w);
        load_w=1; weight_in=w; tick(1); load_w=0;
    endtask

    // apply inputs, wait 2 ticks (1 to latch r_in, 1 to latch out), then check
    task apply_check(
        input signed [7:0] a, b, c, d,
        input signed [10:0] e0, e1, e2, e3,
        input string nm
    );
        in0=a; in1=b; in2=c; in3=d;
        tick(1); tick(1);
        check(nm, e0, e1, e2, e3);
    endtask

    // ================================================================
    initial begin
        $display("=======================================================");
        $display(" crossbar_mac Testbench — ECE 410/510 Codefest 6");
        $display("=======================================================");

        // Reset
        rst_n=0; load_w=0; weight_in=0; in0=0; in1=0; in2=0; in3=0;
        tick(3); rst_n=1; tick(1);

        // ============================================================
        // SECTION A — PROF'S REQUIRED TEST (Task 5 exact spec)
        // ============================================================
        $display("\n=== SECTION A: Prof Required Test ===");
        load_weights(16'b1000_0110_0011_0101);   // W as specified
        apply_check(10, 20, 30, 40,  -40, 0, -20, -20,
                    "T1 Prof[10,20,30,40] => [-40,0,-20,-20]");

        // ============================================================
        // SECTION B — BASELINE / SANITY
        // ============================================================
        $display("\n=== SECTION B: Baseline Sanity ===");

        // B1: Zero input always gives zero output regardless of weights
        apply_check(0,0,0,0,  0,0,0,0,  "B1 zero input");

        // B2: All +1 weights, uniform input → sum = 4×value
        load_weights(16'hFFFF);
        apply_check(1,1,1,1,  4,4,4,4,  "B2 all+1, in=1→4");
        apply_check(10,10,10,10, 40,40,40,40, "B3 all+1, in=10→40");

        // B3: All -1 weights, uniform positive input
        load_weights(16'h0000);
        apply_check(1,1,1,1,  -4,-4,-4,-4, "B4 all-1, in=1→-4");

        // ============================================================
        // SECTION C — WEIGHT MATRIX COLUMN VERIFICATION
        // Apply unit basis vectors → each output equals one column of W
        // ============================================================
        $display("\n=== SECTION C: Weight Column Verification (unit inputs) ===");
        load_weights(16'b1000_0110_0011_0101);  // prof weights
        // in=[1,0,0,0]: out[j] = W[0][j]*1 = row0 = [1,-1,1,-1]
        apply_check(1,0,0,0,   1,-1, 1,-1,  "C1 in=[1,0,0,0] reads row0");
        // in=[0,1,0,0]: out[j] = W[1][j] = [1,1,-1,-1]
        apply_check(0,1,0,0,   1, 1,-1,-1,  "C2 in=[0,1,0,0] reads row1");
        // in=[0,0,1,0]: out[j] = W[2][j] = [-1,1,1,-1]
        apply_check(0,0,1,0,  -1, 1, 1,-1,  "C3 in=[0,0,1,0] reads row2");
        // in=[0,0,0,1]: out[j] = W[3][j] = [-1,-1,-1,1]
        apply_check(0,0,0,1,  -1,-1,-1, 1,  "C4 in=[0,0,0,1] reads row3");

        // ============================================================
        // SECTION D — WEIGHT RELOAD AND PERSISTENCE
        // ============================================================
        $display("\n=== SECTION D: Weight Reload ===");
        load_weights(16'hFFFF);
        apply_check(10,10,10,10, 40,40,40,40, "D1 all+1 loaded, in=10");
        // Reload to all -1 without re-applying inputs
        load_weights(16'h0000);
        apply_check(10,10,10,10, -40,-40,-40,-40, "D2 reloaded all-1, in=10");
        // Reload back to prof weights
        load_weights(16'b1000_0110_0011_0101);
        apply_check(10,20,30,40, -40,0,-20,-20, "D3 reloaded prof weights");

        // ============================================================
        // SECTION E — SIGNED / NEGATIVE INPUT TESTS
        // ============================================================
        $display("\n=== SECTION E: Signed / Negative Inputs ===");
        load_weights(16'hFFFF);   // all +1 weights
        apply_check(-10,-20,-30,-40, -100,-100,-100,-100, "E1 neg inputs all+1");
        apply_check(50,-50,50,-50,     0,  0,  0,  0,    "E2 cancellation=0");
        apply_check(-1, 2,-3, 4,       2,  2,  2,  2,    "E3 mixed-sign sum");

        load_weights(16'h0000);   // all -1 weights: negates everything
        apply_check(-10,-20,-30,-40, 100,100,100,100, "E4 neg input, -1 weights");

        // ============================================================
        // SECTION F — OVERFLOW CORNER CASE (the real crack point)
        // ============================================================
        $display("\n=== SECTION F: Overflow Corner Cases ===");
        // Max positive: 4 × 127 = 508
        load_weights(16'hFFFF);
        apply_check(127,127,127,127, 508,508,508,508, "F1 max+ inputs → 508");
        // Max negative: 4 × (−127) = −508
        apply_check(-127,-127,-127,-127, -508,-508,-508,-508, "F2 max- inputs →-508");
        // The real boundary: all-1 weights, input=-128 → each term = -(-128)=128, sum=512
        // 11-bit signed holds up to 1023, so 512 fits correctly (NOT possible in 10-bit!)
        load_weights(16'h0000);  // all -1 weights
        apply_check(-8'sd128,-8'sd128,-8'sd128,-8'sd128,
                    512, 512, 512, 512,  "F3 in=-128,w=-1 → 512 (11-bit needed!)");
        // Opposite: all+1 weights, input=127 → 508
        load_weights(16'hFFFF);
        apply_check(127,127,127,127, 508,508,508,508, "F4 in=127,w=+1 → 508");
        // Extreme negative: all+1, input=-128 → 4*(−128) = −512
        apply_check(-8'sd128,-8'sd128,-8'sd128,-8'sd128,
                    -512,-512,-512,-512, "F5 in=-128,w=+1 →-512 (11-bit needed!)");

        // ============================================================
        // SECTION G — RESET BEHAVIOR
        // ============================================================
        $display("\n=== SECTION G: Reset Behavior ===");
        // Reset during active computation
        load_weights(16'hFFFF);
        in0=99; in1=99; in2=99; in3=99; tick(1);
        rst_n=0; tick(1);
        check("G1 rst_n=0 clears outputs", 0,0,0,0);
        rst_n=1; tick(1);
        // Weights are also cleared by reset, so reload
        load_weights(16'hFFFF);
        apply_check(5,5,5,5, 20,20,20,20, "G2 resumes correctly after reset");

        // ============================================================
        // SECTION H — SUPER CRACK: Simultaneous load_w + new inputs
        // ============================================================
        $display("\n=== SECTION H: Simultaneous Weight Load + Input ===");
        // Drive load_w=1 AND new inputs in same cycle
        load_w=1; weight_in=16'b1000_0110_0011_0101;
        in0=10; in1=20; in2=30; in3=40;
        tick(1); load_w=0;
        // After this posedge: w[] latched to prof weights, r_in[] = [10,20,30,40]
        tick(1);   // mac_result registered to out[]
        check("H1 simultaneous load+input", -40, 0, -20, -20);

        // ============================================================
        // SECTION I — SUPER CRACK: load_w held multiple cycles
        // ============================================================
        $display("\n=== SECTION I: load_w Held Multiple Cycles ===");
        load_w=1; weight_in=16'hFFFF; tick(3); load_w=0;
        apply_check(7,7,7,7, 28,28,28,28, "I1 multi-cycle load_w");

        // ============================================================
        // SECTION J — SUPER CRACK: Back-to-back inputs (pipeline)
        // ============================================================
        $display("\n=== SECTION J: Back-to-Back Input Pipeline ===");
        load_weights(16'hFFFF);  // all +1
        // Drive vector 1
        in0=1; in1=2; in2=3; in3=4; tick(1);  // r_in=[1,2,3,4] latched
        // Drive vector 2 on very next cycle
        in0=5; in1=5; in2=5; in3=5; tick(1);  // out gets mac([1,2,3,4])=10
        check("J1 pipeline: out from [1,2,3,4]", 10,10,10,10);
        tick(1);  // out gets mac([5,5,5,5])=20
        check("J2 pipeline: out from [5,5,5,5]", 20,20,20,20);

        // ============================================================
        // SECTION K — SUPER CRACK: Asymmetric weight patterns
        // ============================================================
        $display("\n=== SECTION K: Asymmetric Weight Patterns ===");
        // Only col-0 all +1, rest all -1
        // bit[i*4+0] = 1, rest 0 → weight_in = 16'b0001_0001_0001_0001
        load_weights(16'b0001_0001_0001_0001);
        // in=[1,1,1,1]:
        // out[0] = (+1+1+1+1)=4  out[1]=(-1-1-1-1)=-4
        // out[2] = (-1-1-1-1)=-4 out[3]=(-1-1-1-1)=-4
        apply_check(1,1,1,1, 4,-4,-4,-4, "K1 col0=+1 rest=-1");

        // Identity-like: diagonal +1, off-diagonal -1
        // W[j][j]=+1, rest -1 → bit[j*4+j]=1, rest 0
        // bits: [0]=1,[5]=1,[10]=1,[15]=1 → 16'b1000_0100_0010_0001
        load_weights(16'b1000_0100_0010_0001);
        // in=[a,b,c,d]: out[j] = W[j][j]*in[j] + sum_{i≠j}(-1)*in[i]
        //   out[0] = +a - b - c - d
        //   out[1] = -a + b - c - d
        //   out[2] = -a - b + c - d
        //   out[3] = -a - b - c + d
        // for [1,2,3,4]: out[0]=1-2-3-4=-8, out[1]=-1+2-3-4=-6,
        //                out[2]=-1-2+3-4=-4, out[3]=-1-2-3+4=-2
        apply_check(1,2,3,4, -8,-6,-4,-2, "K2 diagonal+1 off-diag-1");

        // ============================================================
        // SECTION L — SUPER CRACK: Prof vector negated
        // ============================================================
        $display("\n=== SECTION L: Negated Prof Vector ===");
        load_weights(16'b1000_0110_0011_0101);
        // in=[-10,-20,-30,-40]: each output should negate
        apply_check(-10,-20,-30,-40, 40,0,20,20, "L1 negated prof inputs");
        // Scaled: in=[5,10,15,20] = prof/2 → out/2
        apply_check(5,10,15,20, -20,0,-10,-10, "L2 prof inputs halved");

        // ============================================================
        // FINAL SUMMARY
        // ============================================================
        $display("\n=======================================================");
        $display(" FINAL: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display(" *** ALL TESTS PASSED — GOOD TO GO ***");
        else
            $display(" *** FAILURES — DO NOT SUBMIT ***");
        $display("=======================================================");
        $finish;
    end

    initial begin #50000; $display("TIMEOUT"); $finish; end

endmodule
