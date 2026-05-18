// =============================================================
// synth_top.sv
// Synthesis target for ECE 410/510 Codefest 7 — Option B
//
// Source: corrected 4×4 Binary-Weight Crossbar MAC from CF06
// Original file: codefest/cf06/hdl/crossbar_mac.sv
//
// Prof spec (CF06 verbatim):
//   "4 input lines (8-bit signed), 4 output lines (accumulator),
//    weights encoded as +1/−1 stored in a 4×4 register array.
//    Each clock cycle computes out[j] = Σ_i weight[i][j] × in[i]."
//
// Output width: 11-bit signed (covers worst case 4×128=512,
//               which overflows 10-bit signed range of ±511)
//
// Timing (2-cycle pipeline):
//   Cycle N  : load_w=1 → weights latched
//   Cycle N+1: inputs latched into r_in[]
//   Cycle N+2: outputs valid
// =============================================================
`timescale 1ns/1ps

module crossbar_mac (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        load_w,
    input  logic [15:0] weight_in,
    input  logic signed [7:0]  in0, in1, in2, in3,
    output logic signed [10:0] out0, out1, out2, out3
);

    logic w [0:3][0:3];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            w[0][0]<=0; w[0][1]<=0; w[0][2]<=0; w[0][3]<=0;
            w[1][0]<=0; w[1][1]<=0; w[1][2]<=0; w[1][3]<=0;
            w[2][0]<=0; w[2][1]<=0; w[2][2]<=0; w[2][3]<=0;
            w[3][0]<=0; w[3][1]<=0; w[3][2]<=0; w[3][3]<=0;
        end else if (load_w) begin
            w[0][0]<=weight_in[0];  w[0][1]<=weight_in[1];
            w[0][2]<=weight_in[2];  w[0][3]<=weight_in[3];
            w[1][0]<=weight_in[4];  w[1][1]<=weight_in[5];
            w[1][2]<=weight_in[6];  w[1][3]<=weight_in[7];
            w[2][0]<=weight_in[8];  w[2][1]<=weight_in[9];
            w[2][2]<=weight_in[10]; w[2][3]<=weight_in[11];
            w[3][0]<=weight_in[12]; w[3][1]<=weight_in[13];
            w[3][2]<=weight_in[14]; w[3][3]<=weight_in[15];
        end
    end

    logic signed [7:0] r_in0, r_in1, r_in2, r_in3;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            r_in0<=0; r_in1<=0; r_in2<=0; r_in3<=0;
        end else begin
            r_in0<=in0; r_in1<=in1; r_in2<=in2; r_in3<=in3;
        end
    end

    wire signed [10:0] s0 = {{3{r_in0[7]}}, r_in0};
    wire signed [10:0] s1 = {{3{r_in1[7]}}, r_in1};
    wire signed [10:0] s2 = {{3{r_in2[7]}}, r_in2};
    wire signed [10:0] s3 = {{3{r_in3[7]}}, r_in3};

    wire signed [10:0] t00 = w[0][0] ? s0 : -s0;
    wire signed [10:0] t10 = w[1][0] ? s1 : -s1;
    wire signed [10:0] t20 = w[2][0] ? s2 : -s2;
    wire signed [10:0] t30 = w[3][0] ? s3 : -s3;

    wire signed [10:0] t01 = w[0][1] ? s0 : -s0;
    wire signed [10:0] t11 = w[1][1] ? s1 : -s1;
    wire signed [10:0] t21 = w[2][1] ? s2 : -s2;
    wire signed [10:0] t31 = w[3][1] ? s3 : -s3;

    wire signed [10:0] t02 = w[0][2] ? s0 : -s0;
    wire signed [10:0] t12 = w[1][2] ? s1 : -s1;
    wire signed [10:0] t22 = w[2][2] ? s2 : -s2;
    wire signed [10:0] t32 = w[3][2] ? s3 : -s3;

    wire signed [10:0] t03 = w[0][3] ? s0 : -s0;
    wire signed [10:0] t13 = w[1][3] ? s1 : -s1;
    wire signed [10:0] t23 = w[2][3] ? s2 : -s2;
    wire signed [10:0] t33 = w[3][3] ? s3 : -s3;

    wire signed [10:0] mac0 = t00 + t10 + t20 + t30;
    wire signed [10:0] mac1 = t01 + t11 + t21 + t31;
    wire signed [10:0] mac2 = t02 + t12 + t22 + t32;
    wire signed [10:0] mac3 = t03 + t13 + t23 + t33;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            out0<=0; out1<=0; out2<=0; out3<=0;
        end else begin
            out0<=mac0; out1<=mac1; out2<=mac2; out3<=mac3;
        end
    end

endmodule
