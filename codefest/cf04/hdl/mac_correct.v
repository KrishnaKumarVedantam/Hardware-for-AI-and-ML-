// MAC Unit - INT8 Multiply-Accumulate
// Corrected version by: Claude Sonnet 4.6
// Fixes:
//   1. No blocking assignments inside always_ff
//   2. Uses $signed() for portable sign extension
//   3. No intermediate signals needed

module mac (
    input  logic        clk,
    input  logic        rst,
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [31:0] out
);

    always_ff @(posedge clk) begin
        if (rst) begin
            out <= 32'sd0;
        end else begin
            out <= out + ($signed(a) * $signed(b));
        end
    end

endmodule
