// =============================================================
// interface.sv
// KWS Accelerator — SPI Slave Interface Module
// ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam
//
// NOTE: 'interface' is reserved in SV. Module named spi_slave.
//
// Protocol: SPI Mode 0 (CPOL=0, CPHA=0)
//   SCLK idle LOW. Sample on RISE. Shift on FALL. MSB first.
//
// Ports use flat packed arrays for Yosys synthesis compatibility:
//   rx_data: [N_IN_BYTES*8-1:0] — byte b = rx_data[b*8+:8]
//   tx_data: [N_OUT_BYTES*8-1:0] — byte b = tx_data[b*8+:8]
//
// Ports:
//   sys_clk   in  1                    System clock (>4x SCLK)
//   rst_n     in  1                    Async active-low reset
//   sclk      in  1                    SPI clock
//   cs_n      in  1                    Chip select active low
//   mosi      in  1                    Master out slave in
//   miso      out 1                    Master in slave out
//   rx_data   out N_IN_BYTES*8         Received bytes (flat packed)
//   rx_done   out 1                    Pulses 1 cycle on last byte
//   tx_data   in  N_OUT_BYTES*8        Bytes to transmit (flat packed)
//   tx_ready  in  1                    tx_data is valid
// =============================================================

module spi_slave #(
    parameter N_IN_BYTES  = 64,
    parameter N_OUT_BYTES = 10
)(
    input  wire                      sys_clk,
    input  wire                      rst_n,

    // SPI pins
    input  wire                      sclk,
    input  wire                      cs_n,
    input  wire                      mosi,
    output reg                       miso,

    // Flat packed ports (Yosys compatible)
    output reg  [N_IN_BYTES*8-1:0]   rx_data,
    output reg                       rx_done,
    input  wire [N_OUT_BYTES*8-1:0]  tx_data,
    input  wire                      tx_ready
);

    // ── 3-FF synchronizer ──
    reg sclk_s1, sclk_s2, sclk_s3;
    reg cs_s1,   cs_s2,   cs_s3;
    reg mosi_s1, mosi_s2;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_s1<=1'b0; sclk_s2<=1'b0; sclk_s3<=1'b0;
            cs_s1<=1'b1;   cs_s2<=1'b1;   cs_s3<=1'b1;
            mosi_s1<=1'b0; mosi_s2<=1'b0;
        end else begin
            sclk_s1<=sclk; sclk_s2<=sclk_s1; sclk_s3<=sclk_s2;
            cs_s1<=cs_n;   cs_s2<=cs_s1;     cs_s3<=cs_s2;
            mosi_s1<=mosi; mosi_s2<=mosi_s1;
        end
    end

    wire sclk_rise = ( sclk_s2 && !sclk_s3);
    wire sclk_fall = (!sclk_s2 &&  sclk_s3);
    wire cs_fall   = (!cs_s2   &&  cs_s3);
    wire cs_rise   = ( cs_s2   && !cs_s3);

    // ── RX state ──
    reg [7:0]   rx_shift;
    reg [2:0]   rx_bit_cnt;
    reg [11:0]  rx_byte_cnt;  // 12 bits for up to 4000
    reg         rx_active;

    // ── TX state ──
    reg [7:0]  tx_shift;
    reg [2:0]  tx_bit_cnt;
    reg [3:0]  tx_byte_cnt;   // 4 bits for up to 10

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift    <= 8'b0;
            rx_bit_cnt  <= 3'b0;
            rx_byte_cnt <= 12'b0;
            rx_done     <= 1'b0;
            rx_active   <= 1'b0;
            tx_shift    <= 8'b0;
            tx_bit_cnt  <= 3'b0;
            tx_byte_cnt <= 4'b0;
            miso        <= 1'b0;
            rx_data     <= {(N_IN_BYTES*8){1'b0}};
        end else begin
            rx_done <= 1'b0;

            if (cs_fall) begin
                rx_bit_cnt  <= 3'b0;
                rx_byte_cnt <= 12'b0;
                tx_bit_cnt  <= 3'b0;
                tx_byte_cnt <= 4'b0;
                rx_active   <= 1'b1;
                // Pre-drive MISO with MSB of first TX byte
                miso     <= tx_ready ? tx_data[7] : 1'b1;
                tx_shift <= tx_ready ? {tx_data[6:0], 1'b0} : 8'hFF;
            end

            if (cs_rise) begin
                rx_active <= 1'b0;
                miso      <= 1'b0;
            end

            if (rx_active && !cs_s2) begin

                if (sclk_rise) begin
                    rx_shift <= {rx_shift[6:0], mosi_s2};
                    if (rx_bit_cnt == 3'd7) begin
                        rx_bit_cnt <= 3'b0;
                        if (rx_byte_cnt < N_IN_BYTES) begin
                            // Write byte into flat rx_data
                            rx_data[rx_byte_cnt*8 +: 8] <=
                                {rx_shift[6:0], mosi_s2};
                            if (rx_byte_cnt == N_IN_BYTES - 1)
                                rx_done <= 1'b1;
                            rx_byte_cnt <= rx_byte_cnt + 12'b1;
                        end
                    end else begin
                        rx_bit_cnt <= rx_bit_cnt + 3'b1;
                    end
                end

                if (sclk_fall) begin
                    if (tx_bit_cnt == 3'd7) begin
                        miso        <= tx_shift[7];
                        tx_bit_cnt  <= 3'b0;
                        tx_byte_cnt <= tx_byte_cnt + 4'b1;
                        if (tx_ready && tx_byte_cnt < N_OUT_BYTES - 1) begin
                            // Next byte from flat tx_data
                            miso     <= tx_data[(tx_byte_cnt+1)*8+7];
                            tx_shift <= {tx_data[(tx_byte_cnt+1)*8+6 -: 6],
                                         1'b0, 1'b0};
                        end else begin
                            miso     <= 1'b1;
                            tx_shift <= 8'hFF;
                        end
                    end else begin
                        miso       <= tx_shift[7];
                        tx_shift   <= {tx_shift[6:0], 1'b0};
                        tx_bit_cnt <= tx_bit_cnt + 3'b1;
                    end
                end
            end
        end
    end

endmodule
