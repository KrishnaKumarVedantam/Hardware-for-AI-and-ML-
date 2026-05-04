// =============================================================
// compute_core.sv
// KWS Accelerator — Binary Conv2 XOR+popcount Compute Core
// ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam
//
// Description:
//   Synthesizable 1D binary convolution (dominant Conv2 kernel,
//   98.4% of total FLOPs). Replaces FP32 multiply-accumulate
//   with XOR + popcount.
//   Math: result[oc][p] = C_IN*K - 2*popcount(acts[p] XOR wts[oc])
//
// Parameters:
//   C_IN  = 4   input channels
//   C_OUT = 4   output channels
//   K     = 3   kernel size
//   L     = 8   sequence length
//   PAD   = 1   zero padding each side (act=0 = signed -1)
//   OBITS = 8   output width (signed)
//
// Clock domain: single clock (clk), async active-low reset (rst_n)
//
// Ports:
//   clk        in  1      System clock
//   rst_n      in  1      Async active-low reset
//   start      in  1      Pulse 1 cycle to begin
//   done       out 1      Pulses 1 cycle when all outputs valid
//   act_in     in  C_IN   1-bit activations for one position
//   act_pos    in  3      Position index (0..L-1)
//   act_valid  in  1      act_in valid this cycle
//   wt_data    in  C_IN*K Weights for one output channel (1-bit each)
//   wt_oc      in  2      Which output channel
//   wt_valid   in  1      Weight valid this cycle
//   out_data   out OBITS  Accumulation result (signed)
//   out_oc     out 2      Output channel index
//   out_pos    out 3      Output position index
//   out_valid  out 1      Output valid this cycle
// =============================================================

module compute_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,

    input  wire [3:0]  act_in,
    input  wire [2:0]  act_pos,
    input  wire        act_valid,

    input  wire [11:0] wt_data,
    input  wire [1:0]  wt_oc,
    input  wire        wt_valid,

    output reg signed [7:0]  out_data,
    output reg [1:0]         out_oc,
    output reg [2:0]         out_pos,
    output reg               out_valid
);

    // Parameters
    localparam C_IN  = 4;
    localparam C_OUT = 4;
    localparam K     = 3;
    localparam L     = 8;
    localparam PAD   = 1;
    localparam TOTAL = C_IN * K;  // = 12

    // ── Storage ──
    reg [3:0]  act_buf [0:7];   // [L]   C_IN bits per position
    reg [11:0] wt_buf  [0:3];   // [C_OUT] C_IN*K bits per oc

    // ── FSM ──
    localparam IDLE    = 2'd0;
    localparam COMPUTE = 2'd1;
    localparam FINISH  = 2'd2;

    reg [1:0] state;
    reg [1:0] oc_cnt;
    reg [2:0] pos_cnt;

    // ── Load activations ──
    integer li;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (li=0; li<8; li=li+1) act_buf[li] <= 4'b0;
        end else if (act_valid) begin
            act_buf[act_pos] <= act_in;
        end
    end

    // ── Load weights ──
    integer wi;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (wi=0; wi<4; wi=wi+1) wt_buf[wi] <= 12'b0;
        end else if (wt_valid) begin
            wt_buf[wt_oc] <= wt_data;
        end
    end

    // ── Compute XOR+popcount for current (oc_cnt, pos_cnt) ──
    reg [11:0] xor_vec;
    reg [3:0]  pop_cnt;   // max = 12 needs 4 bits
    reg signed [7:0] acc;

    // Build XOR vector and popcount combinationally
    integer ic, k;
    reg signed [3:0] p_in;
    reg [3:0] a_bit;

    always @(*) begin
        xor_vec = 12'b0;
        for (ic=0; ic<C_IN; ic=ic+1) begin
            for (k=0; k<K; k=k+1) begin
                p_in = $signed({1'b0, pos_cnt}) + k - PAD;
                // pad = 0 (signed -1), XOR(0,w)=w
                if (p_in < 0 || p_in >= L)
                    a_bit = 1'b0;
                else
                    a_bit = act_buf[p_in[2:0]][ic];
                xor_vec[ic*K + k] = a_bit ^ wt_buf[oc_cnt][ic*K + k];
            end
        end

        // Popcount
        pop_cnt = 4'd0;
        for (ic=0; ic<12; ic=ic+1)
            pop_cnt = pop_cnt + {3'b0, xor_vec[ic]};

        // result = TOTAL - 2*pop_cnt
        acc = $signed(8'd12) - $signed({2'b0, pop_cnt, 1'b0});
    end

    // ── Main FSM ──
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            done      <= 1'b0;
            out_valid <= 1'b0;
            out_data  <= 8'b0;
            out_oc    <= 2'b0;
            out_pos   <= 3'b0;
            oc_cnt    <= 2'b0;
            pos_cnt   <= 3'b0;
        end else begin
            done      <= 1'b0;
            out_valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        oc_cnt  <= 2'b0;
                        pos_cnt <= 3'b0;
                        state   <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Output current result
                    out_data  <= acc;
                    out_oc    <= oc_cnt;
                    out_pos   <= pos_cnt;
                    out_valid <= 1'b1;

                    // Advance: pos first, then oc
                    if (pos_cnt == 3'd7) begin
                        pos_cnt <= 3'b0;
                        if (oc_cnt == 2'd3) begin
                            state <= FINISH;
                        end else begin
                            oc_cnt <= oc_cnt + 2'b1;
                        end
                    end else begin
                        pos_cnt <= pos_cnt + 3'b1;
                    end
                end

                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
