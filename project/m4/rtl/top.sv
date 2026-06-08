// =============================================================
// top.sv
// KWS Accelerator — Integrated Top Module (M3)
// ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam
//
// Integrates spi_slave (interface.sv) and compute_core.
//
// Data flow:
//   Host → SPI → spi_slave → rx_data[flat] → glue FSM →
//   compute_core → result_buf → tx_data[flat] → spi_slave → Host
//
// Input packing (C_IN=64, L=500):
//   500 positions × 8 bytes = 4000 bytes over SPI
//   rx_data is flat [31999:0]: byte b = rx_data[b*8+:8]
//   Position p: bytes p*8..p*8+7 → act_in[63:0]
//
// Glue FSM:
//   G_IDLE    → wait for rx_done
//   G_LOAD    → feed 500 positions to compute_core (500 cycles)
//   G_COMPUTE → wait for done, capture pos=0 results
//   G_PACK    → fill tx_data, set tx_ready
//
// Ports:
//   clk      in  1       System clock
//   rst_n    in  1       Async active-low reset
//   sclk     in  1       SPI clock
//   cs_n     in  1       SPI chip select active low
//   mosi     in  1       SPI MOSI
//   miso     out 1       SPI MISO
//   wt_data  in  192     Weight bits for one output channel
//   wt_oc    in  6       Which output channel (0..63)
//   wt_valid in  1       Load weight this cycle
// =============================================================

module top (
    input  wire         clk,
    input  wire         rst_n,

    input  wire         sclk,
    input  wire         cs_n,
    input  wire         mosi,
    output wire         miso,

    input  wire [191:0] wt_data,
    input  wire [5:0]   wt_oc,
    input  wire         wt_valid
);

    localparam N_IN_BYTES  = 64;
    localparam N_OUT_BYTES = 10;

    // ── spi_slave flat ports ──
    wire [N_IN_BYTES*8-1:0]  rx_data;  // flat: byte b = rx_data[b*8+:8]
    wire                     rx_done;
    reg  [N_OUT_BYTES*8-1:0] tx_data;  // flat: byte b = tx_data[b*8+:8]
    reg                      tx_ready;

    // ── compute_core wires ──
    reg         cc_start;
    wire        cc_done;
    reg  [63:0] cc_act_in;
    reg  [8:0]  cc_act_pos;
    reg         cc_act_valid;
    wire signed [8:0] cc_out_data;
    wire [5:0]        cc_out_oc;
    wire [8:0]        cc_out_pos;
    wire              cc_out_valid;

    // ── spi_slave instance ──
    spi_slave #(
        .N_IN_BYTES (N_IN_BYTES),
        .N_OUT_BYTES(N_OUT_BYTES)
    ) u_spi (
        .sys_clk (clk),
        .rst_n   (rst_n),
        .sclk    (sclk),
        .cs_n    (cs_n),
        .mosi    (mosi),
        .miso    (miso),
        .rx_data (rx_data),
        .rx_done (rx_done),
        .tx_data (tx_data),
        .tx_ready(tx_ready)
    );

    // ── compute_core instance ──
    compute_core u_cc (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (cc_start),
        .done     (cc_done),
        .act_in   (cc_act_in),
        .act_pos  (cc_act_pos),
        .act_valid(cc_act_valid),
        .wt_data  (wt_data),
        .wt_oc    (wt_oc),
        .wt_valid (wt_valid),
        .out_data (cc_out_data),
        .out_oc   (cc_out_oc),
        .out_pos  (cc_out_pos),
        .out_valid(cc_out_valid)
    );

    // ── Glue FSM ──
    localparam G_IDLE    = 2'd0;
    localparam G_LOAD    = 2'd1;
    localparam G_COMPUTE = 2'd2;
    localparam G_PACK    = 2'd3;

    reg [1:0] g_state;
    reg [8:0] g_pos;

    reg signed [8:0] result_buf [0:63];

    // Array init via initial block (synthesis: power-on reset)
    integer ii;
    initial begin
        for (ii = 0; ii < 64; ii = ii + 1)
            result_buf[ii] = 9'b0;
        tx_data = {(N_OUT_BYTES*8){1'b1}};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            g_state      <= G_IDLE;
            g_pos        <= 9'b0;
            cc_start     <= 1'b0;
            cc_act_valid <= 1'b0;
            cc_act_in    <= 64'b0;
            cc_act_pos   <= 9'b0;
            tx_ready     <= 1'b0;
        end else begin
            cc_start     <= 1'b0;
            cc_act_valid <= 1'b0;

            case (g_state)

                G_IDLE: begin
                    if (rx_done) begin
                        tx_ready <= 1'b0;
                        g_pos    <= 9'b0;
                        g_state  <= G_LOAD;
                    end
                end

                G_LOAD: begin
                    // Unpack flat rx_data into cc_act_in
                    // Position p: byte b at rx_data[(p*8+b)*8 +: 8]
                    // act_in[7:0]   = byte 0 of position g_pos
                    // act_in[63:56] = byte 7 of position g_pos
                    cc_act_in <= {
                        rx_data[((g_pos<<3)+7)*8 +: 8],
                        rx_data[((g_pos<<3)+6)*8 +: 8],
                        rx_data[((g_pos<<3)+5)*8 +: 8],
                        rx_data[((g_pos<<3)+4)*8 +: 8],
                        rx_data[((g_pos<<3)+3)*8 +: 8],
                        rx_data[((g_pos<<3)+2)*8 +: 8],
                        rx_data[((g_pos<<3)+1)*8 +: 8],
                        rx_data[((g_pos<<3)+0)*8 +: 8]
                    };
                    cc_act_pos   <= g_pos;
                    cc_act_valid <= 1'b1;

                    if (g_pos == 9'd499) begin
                        cc_start <= 1'b1;
                        g_state  <= G_COMPUTE;
                    end else begin
                        g_pos <= g_pos + 9'b1;
                    end
                end

                G_COMPUTE: begin
                    if (cc_out_valid && cc_out_pos == 9'b0)
                        result_buf[cc_out_oc] <= cc_out_data;
                    if (cc_done)
                        g_state <= G_PACK;
                end

                G_PACK: begin
                    // Pack result_buf[0..9] into flat tx_data
                    tx_data[0*8  +: 8] <= result_buf[0][7:0];
                    tx_data[1*8  +: 8] <= result_buf[1][7:0];
                    tx_data[2*8  +: 8] <= result_buf[2][7:0];
                    tx_data[3*8  +: 8] <= result_buf[3][7:0];
                    tx_data[4*8  +: 8] <= result_buf[4][7:0];
                    tx_data[5*8  +: 8] <= result_buf[5][7:0];
                    tx_data[6*8  +: 8] <= result_buf[6][7:0];
                    tx_data[7*8  +: 8] <= result_buf[7][7:0];
                    tx_data[8*8  +: 8] <= result_buf[8][7:0];
                    tx_data[9*8  +: 8] <= result_buf[9][7:0];
                    tx_ready <= 1'b1;
                    g_state  <= G_IDLE;
                end

                default: g_state <= G_IDLE;
            endcase
        end
    end

endmodule
