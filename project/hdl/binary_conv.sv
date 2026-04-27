// Binary 1D Convolution Engine
// Project: KWS Hardware Accelerator Chiplet
// ECE 510 | Portland State University | Spring 2026
// Author: Venkata Krishna Kumar Vedantam
//
// Description:
//   Computes one output of Binary Conv2 layer.
//   Weights are 1-bit packed (+1/-1 encoded as 1/0).
//   Activations are INT8.
//   Operation: result = K*C_IN - 2*popcount(XOR(weights, act_msb))
//   Interface: SPI
//   Precision: 1-bit weights, INT8 activations

module binary_conv #(
    parameter DATA_WIDTH  = 8,
    parameter KERNEL_SIZE = 3,
    parameter C_IN        = 64,
    parameter C_OUT       = 64
)(
    input  logic                         clk,
    input  logic                         rst,
    input  logic signed [DATA_WIDTH-1:0] act     [0:C_IN*KERNEL_SIZE-1],
    input  logic                         weights [0:C_IN*KERNEL_SIZE-1],
    input  logic                         valid_in,
    output logic signed [31:0]           result,
    output logic                         valid_out
);
    localparam TOTAL = C_IN * KERNEL_SIZE;

    logic [TOTAL-1:0]  xor_bits;
    logic [7:0]        popcount_val;
    logic signed [31:0] result_next;

    // XOR each weight bit with MSB of activation (binarized sign)
    genvar g;
    generate
        for (g = 0; g < TOTAL; g++) begin : xor_gen
            assign xor_bits[g] = weights[g] ^ act[g][DATA_WIDTH-1];
        end
    endgenerate

    // Popcount and result computation (combinational)
    always_comb begin
        popcount_val = 8'd0;
        for (int i = 0; i < TOTAL; i++) begin
            popcount_val = popcount_val + xor_bits[i];
        end
        // BNN result: K*C_IN - 2*popcount
        result_next = (KERNEL_SIZE * C_IN) - (32'sd2 * $signed({1'b0, popcount_val}));
    end

    // Sequential register with synchronous reset
    always_ff @(posedge clk) begin
        if (rst) begin
            result    <= 32'sd0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            result    <= result_next;
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
