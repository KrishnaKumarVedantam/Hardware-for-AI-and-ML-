// =============================================================
// compute_core.sv  (M4 — OpenRAM SRAM + sliding window)
// KWS Accelerator — Binary Conv2 XOR+popcount Compute Core
// ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam
//
// M4 vs M3:
//   REMOVED: reg [63:0] act_buf [0:499]  — 32,000 FFs (timing root cause)
//   ADDED:   2× sky130_sram_1kbyte_1rw1r_32x256_8 SRAM macros
//   ADDED:   reg [63:0] win_buf [0:2] — sliding window (fanout=1 per bit)
//
// BUG FIX (adversarial audit v2): Verilog NBA timing
//   SRAM dout1 is updated in NBA region — compute_core active region
//   reads STALE dout if capture is in same cycle as SRAM fire.
//   Fix: capture win_buf one cycle AFTER SRAM fires.
//   PRE_FETCH: 3 states, each waiting for NBA to settle.
//   COMPUTE:   issue read at oc=C_OUT-3, capture at oc=C_OUT-1.
// =============================================================

module compute_core (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    output reg          done,
    input  wire [63:0]  act_in,
    input  wire [8:0]   act_pos,
    input  wire         act_valid,
    input  wire [191:0] wt_data,
    input  wire [5:0]   wt_oc,
    input  wire         wt_valid,
    output reg signed [8:0]  out_data,
    output reg [5:0]          out_oc,
    output reg [8:0]          out_pos,
    output reg                out_valid
);

    localparam C_IN  = 64;
    localparam C_OUT = 64;
    localparam K     = 3;
    localparam PAD   = 1;
    localparam N_POS = 8;  // = N_IN_BYTES/8 = 64/8

    // ── SRAM signals ─────────────────────────────────────────────
    reg        sram_csb0, sram_web0;
    reg [7:0]  sram_waddr;
    reg [31:0] sram_din_lo, sram_din_hi;
    reg        sram_csb1;
    reg [7:0]  sram_raddr;
    wire [31:0] sram_dout_lo, sram_dout_hi;

    // SRAM A: lo 32 bits
    sky130_sram_1kbyte_1rw1r_32x256_8 u_sram_a (
        .clk0(clk), .csb0(sram_csb0), .web0(sram_web0), .wmask0(4'hF),
        .addr0(sram_waddr), .din0(sram_din_lo), .dout0(),
        .clk1(clk), .csb1(sram_csb1), .addr1(sram_raddr), .dout1(sram_dout_lo)
    );

    // SRAM B: hi 32 bits
    sky130_sram_1kbyte_1rw1r_32x256_8 u_sram_b (
        .clk0(clk), .csb0(sram_csb0), .web0(sram_web0), .wmask0(4'hF),
        .addr0(sram_waddr), .din0(sram_din_hi), .dout0(),
        .clk1(clk), .csb1(sram_csb1), .addr1(sram_raddr), .dout1(sram_dout_hi)
    );

    // ── Weight buffer ─────────────────────────────────────────────
    reg [191:0] wt_buf [0:C_OUT-1];
    always @(posedge clk or negedge rst_n) begin : wt_load
        if (!rst_n) begin
            wt_buf[0]<=192'b0; wt_buf[1]<=192'b0;
            wt_buf[2]<=192'b0; wt_buf[3]<=192'b0;
        end else if (wt_valid) begin
            wt_buf[wt_oc] <= wt_data;
        end
    end

    // ── Sliding window buffer (fanout=1 per bit — timing fix) ────
    reg [63:0] win_buf [0:2];

    // ── FSM ──────────────────────────────────────────────────────
    // PRE_FETCH timing (NBA-aware):
    // IDLE:        issue read addr=0 (csb1=0)
    // PRE_FETCH0:  SRAM fires addr=0, dout=act[0] in NBA
    //              issue read addr=1 (csb1=0) — DON'T capture yet
    // PRE_FETCH1:  capture win_buf[1]=act[0] (from PRE_FETCH0 NBA)
    //              SRAM fires addr=1, dout=act[1] in NBA
    // PRE_FETCH2:  capture win_buf[2]=act[1] (from PRE_FETCH1 NBA)
    //              → COMPUTE starts with win_buf=[0,act[0],act[1]] ✓
    localparam IDLE       = 3'd0;
    localparam PRE_FETCH0 = 3'd1;
    localparam PRE_FETCH1 = 3'd2;
    localparam PRE_FETCH2 = 3'd3;
    localparam COMPUTE    = 3'd4;
    localparam FINISH     = 3'd5;

    reg [2:0] state;
    reg [5:0] oc_cnt;
    reg [8:0] pos_cnt;

    // ── XOR computation — win_buf[k][ic] fanout = 1 ──────────────
    wire [191:0] xor_vec;
    genvar ic, k;
    generate
        for (ic = 0; ic < C_IN; ic = ic + 1) begin : gen_ic
            for (k = 0; k < K; k = k + 1) begin : gen_k
                wire signed [9:0] p_in;
                assign p_in = {1'b0, pos_cnt} + k - PAD;
                wire in_range;
                assign in_range = (p_in >= 0) && (p_in < N_POS);
                wire a_bit;
                assign a_bit = in_range ? win_buf[k][ic] : 1'b0;
                assign xor_vec[ic*K + k] = a_bit ^ wt_buf[oc_cnt][ic*K+k];
            end
        end
    endgenerate

    // ── Adder tree (identical to M3) ─────────────────────────────
    wire [1:0] pop_s0 [0:95]; genvar s0;
    generate for(s0=0;s0<96;s0=s0+1) begin:gen_s0
        assign pop_s0[s0]={1'b0,xor_vec[s0*2]}+{1'b0,xor_vec[s0*2+1]};
    end endgenerate
    wire [2:0] pop_s1 [0:47]; genvar s1;
    generate for(s1=0;s1<48;s1=s1+1) begin:gen_s1
        assign pop_s1[s1]={1'b0,pop_s0[s1*2]}+{1'b0,pop_s0[s1*2+1]};
    end endgenerate
    wire [3:0] pop_s2 [0:23]; genvar s2;
    generate for(s2=0;s2<24;s2=s2+1) begin:gen_s2
        assign pop_s2[s2]={1'b0,pop_s1[s2*2]}+{1'b0,pop_s1[s2*2+1]};
    end endgenerate
    wire [4:0] pop_s3 [0:11]; genvar s3;
    generate for(s3=0;s3<12;s3=s3+1) begin:gen_s3
        assign pop_s3[s3]={1'b0,pop_s2[s3*2]}+{1'b0,pop_s2[s3*2+1]};
    end endgenerate
    wire [5:0] pop_s4 [0:5]; genvar s4;
    generate for(s4=0;s4<6;s4=s4+1) begin:gen_s4
        assign pop_s4[s4]={1'b0,pop_s3[s4*2]}+{1'b0,pop_s3[s4*2+1]};
    end endgenerate
    wire [6:0] pop_s5 [0:2]; genvar s5;
    generate for(s5=0;s5<3;s5=s5+1) begin:gen_s5
        assign pop_s5[s5]={1'b0,pop_s4[s5*2]}+{1'b0,pop_s4[s5*2+1]};
    end endgenerate
    wire [7:0] pop_cnt;
    assign pop_cnt={1'b0,pop_s5[0]}+{1'b0,pop_s5[1]}+{1'b0,pop_s5[2]};
    wire signed [8:0] acc;
    assign acc=9'($signed(10'd192)-$signed({1'b0,pop_cnt,1'b0}));

    // ── Main FSM ─────────────────────────────────────────────────
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=IDLE; done<=0; out_valid<=0;
            out_data<=0; out_oc<=0; out_pos<=0;
            oc_cnt<=0; pos_cnt<=0;
            sram_csb0<=1; sram_web0<=1; sram_csb1<=1;
            sram_raddr<=0; sram_waddr<=0;
            sram_din_lo<=0; sram_din_hi<=0;
            win_buf[0]<=0; win_buf[1]<=0; win_buf[2]<=0;
        end else begin
            done      <= 1'b0;
            out_valid <= 1'b0;
            sram_csb0 <= 1'b1;  // default: write port deselected
            sram_web0 <= 1'b1;
            sram_csb1 <= 1'b1;  // default: read port deselected

            // SRAM write — independent of FSM state
            if (act_valid && (act_pos < N_POS)) begin
                sram_csb0  <= 1'b0;
                sram_web0  <= 1'b0;
                sram_waddr <= act_pos[7:0];
                sram_din_lo<= act_in[31:0];
                sram_din_hi<= act_in[63:32];
            end

            case (state)
                // ──────────────────────────────────────────────────
                IDLE: begin
                    if (start) begin
                        oc_cnt<=0; pos_cnt<=0;
                        win_buf[0]<=64'b0;  // padding: pos=-1
                        win_buf[1]<=64'b0;
                        win_buf[2]<=64'b0;
                        // Issue read for pos=0
                        // SRAM fires at PRE_FETCH0 active, dout ready in NBA
                        sram_csb1  <= 1'b0;
                        sram_raddr <= 8'd0;
                        state <= PRE_FETCH0;
                    end
                end

                // ──────────────────────────────────────────────────
                // SRAM fires here with addr=0 (from IDLE NBA)
                // dout=act[0] available AFTER this cycle's NBA
                // DON'T capture yet — dout stale in active region
                PRE_FETCH0: begin
                    sram_csb1  <= 1'b0;   // issue read for pos=1
                    sram_raddr <= 8'd1;   // SRAM fires at PRE_FETCH1
                    state <= PRE_FETCH1;
                end

                // ──────────────────────────────────────────────────
                // dout = act[0] (from PRE_FETCH0 NBA) ← correct now
                // SRAM fires here with addr=1, dout=act[1] in NBA
                PRE_FETCH1: begin
                    win_buf[1] <= {sram_dout_hi, sram_dout_lo}; // = act[0] ✓
                    // no new read needed here
                    state <= PRE_FETCH2;
                end

                // ──────────────────────────────────────────────────
                // dout = act[1] (from PRE_FETCH1 NBA) ← correct
                // win_buf = [0, act[0], act[1]] → ready for COMPUTE
                PRE_FETCH2: begin
                    win_buf[2] <= {sram_dout_hi, sram_dout_lo}; // = act[1] ✓
                    state <= COMPUTE;
                end

                // ──────────────────────────────────────────────────
                COMPUTE: begin
                    out_data  <= acc;
                    out_oc    <= oc_cnt;
                    out_pos   <= pos_cnt;
                    out_valid <= 1'b1;

                    // Issue read at oc=C_OUT-3 (=61)
                    // SRAM fires at oc=62 active, dout=act[pos+2] in NBA
                    // Capture at oc=63 active reads correct dout ✓
                    if (oc_cnt == C_OUT - 3) begin
                        if (pos_cnt + 2 < N_POS) begin
                            sram_csb1  <= 1'b0;
                            sram_raddr <= pos_cnt[7:0] + 8'd2;
                        end
                    end

                    if (oc_cnt == C_OUT - 1) begin
                        oc_cnt <= 6'b0;
                        // Slide window [pos-1,pos,pos+1]→[pos,pos+1,pos+2]
                        win_buf[0] <= win_buf[1];
                        win_buf[1] <= win_buf[2];
                        // dout = act[pos+2] (from oc=62 NBA) ← now correct
                        if (pos_cnt + 2 < N_POS)
                            win_buf[2] <= {sram_dout_hi, sram_dout_lo};
                        else
                            win_buf[2] <= 64'b0; // padding
                        if (pos_cnt == N_POS - 1)
                            state <= FINISH;
                        else
                            pos_cnt <= pos_cnt + 9'b1;
                    end else begin
                        oc_cnt <= oc_cnt + 6'b1;
                    end
                end

                // ──────────────────────────────────────────────────
                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
