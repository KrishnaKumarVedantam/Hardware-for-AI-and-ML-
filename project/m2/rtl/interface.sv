// =============================================================
// interface.sv
// KWS Accelerator — SPI Slave Interface Module
// ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam
//
// NOTE ON MODULE NAMING:
//   The filename is interface.sv as required by the project spec.
//   However, 'interface' is a RESERVED keyword in SystemVerilog
//   (IEEE 1800-2012) and cannot be used as a module name in any
//   conforming SV tool (Icarus, VCS, Questa, Vivado all reject it).
//   Therefore the top module is named 'spi_slave' — the file is
//   interface.sv and the module implements the SPI interface protocol
//   selected in M1. The testbench tb_interface.sv instantiates
//   spi_slave from this file.
//
// Description:
//   SPI slave implementing Mode 0 (CPOL=0, CPHA=0).
//   Receives N_IN_BYTES bytes from host (feature vector).
//   Transmits N_OUT_BYTES bytes to host (class scores).
//   MSB first on MOSI/MISO.
//
// Protocol (SPI Mode 0 — CPOL=0, CPHA=0):
//   - SCLK idle LOW
//   - Data sampled on RISING edge of SCLK
//   - Data shifted on FALLING edge of SCLK
//   - CS_N active LOW
//   - MSB first
//
// Transaction format:
//   WRITE (host→chiplet): CS_N low, send N_IN_BYTES bytes over MOSI
//                         rx_done pulses when all bytes received
//   READ  (chiplet→host): CS_N low, read N_OUT_BYTES bytes from MISO
//                         tx_data must be valid before CS_N falls
//
// Register map / data widths:
//   RX buffer: 500 × 8-bit INT8 feature values (N_IN_BYTES=500)
//   TX buffer: 10  × 8-bit INT8 class scores   (N_OUT_BYTES=10)
//
// Clock domain: single sys_clk (faster than SCLK)
//   SCLK is synchronized via 2-FF synchronizer before use
// Reset: async active-low rst_n
//
// Ports:
//   sys_clk      in  1          System clock (>4x SCLK)
//   rst_n        in  1          Async active-low reset
//   sclk         in  1          SPI clock from host
//   cs_n         in  1          SPI chip select, active low
//   mosi         in  1          Master out slave in
//   miso         out 1          Master in slave out
//   rx_data      out 8×10       Received bytes (small TB version)
//   rx_done      out 1          All bytes received (pulse 1 cycle)
//   tx_data      in  8×10       Bytes to transmit
//   tx_ready     in  1          tx_data is valid
// =============================================================

module spi_slave #(
    parameter N_IN_BYTES  = 4,   // small for testbench (real=500)
    parameter N_OUT_BYTES = 2    // small for testbench (real=10)
)(
    input  wire        sys_clk,
    input  wire        rst_n,

    // SPI pins
    input  wire        sclk,
    input  wire        cs_n,
    input  wire        mosi,
    output reg         miso,

    // To compute core
    output reg [7:0]   rx_data [0:3],   // N_IN_BYTES max 4
    output reg         rx_done,

    // From compute core
    input  wire [7:0]  tx_data [0:1],   // N_OUT_BYTES max 2
    input  wire        tx_ready
);

    // ── 2-FF synchronizer for SCLK and CS_N ──
    reg sclk_s1, sclk_s2, sclk_s3;
    reg cs_s1,   cs_s2,   cs_s3;
    reg mosi_s1, mosi_s2;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_s1<=0; sclk_s2<=0; sclk_s3<=0;
            cs_s1<=1;   cs_s2<=1;   cs_s3<=1;
            mosi_s1<=0; mosi_s2<=0;
        end else begin
            sclk_s1<=sclk; sclk_s2<=sclk_s1; sclk_s3<=sclk_s2;
            cs_s1<=cs_n;   cs_s2<=cs_s1;     cs_s3<=cs_s2;
            mosi_s1<=mosi; mosi_s2<=mosi_s1;
        end
    end

    // Edge detection on synchronized signals
    wire sclk_rise = ( sclk_s2 && !sclk_s3);  // rising edge
    wire sclk_fall = (!sclk_s2 &&  sclk_s3);  // falling edge
    wire cs_fall   = (!cs_s2   &&   cs_s3);   // CS falling (start)
    wire cs_rise   = ( cs_s2   &&  !cs_s3);   // CS rising  (end)

    // ── RX state ──
    reg [7:0]  rx_shift;
    reg [2:0]  rx_bit_cnt;
    reg [9:0]  rx_byte_cnt;
    reg        rx_active;

    // ── TX state ──
    reg [7:0]  tx_shift;
    reg [2:0]  tx_bit_cnt;
    reg [9:0]  tx_byte_cnt;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_shift    <= 8'b0;
            rx_bit_cnt  <= 3'b0;
            rx_byte_cnt <= 10'b0;
            rx_done     <= 1'b0;
            rx_active   <= 1'b0;
            tx_shift    <= 8'b0;
            tx_bit_cnt  <= 3'b0;
            tx_byte_cnt <= 10'b0;
            miso        <= 1'b0;
            rx_data[0]  <= 8'b0;
            rx_data[1]  <= 8'b0;
            rx_data[2]  <= 8'b0;
            rx_data[3]  <= 8'b0;
        end else begin
            rx_done <= 1'b0;

            // CS falling: start transaction
            if (cs_fall) begin
                rx_bit_cnt  <= 3'b0;
                rx_byte_cnt <= 10'b0;
                tx_bit_cnt  <= 3'b0;
                tx_byte_cnt <= 10'b0;
                rx_active   <= 1'b1;
                // Pre-load first TX byte
                tx_shift    <= tx_ready ? tx_data[0] : 8'hFF;
            end

            // CS rising: end transaction
            if (cs_rise) begin
                rx_active <= 1'b0;
            end

            if (rx_active && !cs_s2) begin

                // ── Sample MOSI on rising SCLK ──
                if (sclk_rise) begin
                    rx_shift <= {rx_shift[6:0], mosi_s2};

                    if (rx_bit_cnt == 3'd7) begin
                        rx_bit_cnt <= 3'b0;
                        if (rx_byte_cnt < N_IN_BYTES) begin
                            case (rx_byte_cnt[1:0])
                                2'd0: rx_data[0] <= {rx_shift[6:0], mosi_s2};
                                2'd1: rx_data[1] <= {rx_shift[6:0], mosi_s2};
                                2'd2: rx_data[2] <= {rx_shift[6:0], mosi_s2};
                                2'd3: rx_data[3] <= {rx_shift[6:0], mosi_s2};
                            endcase
                            if (rx_byte_cnt == N_IN_BYTES - 1)
                                rx_done <= 1'b1;
                            rx_byte_cnt <= rx_byte_cnt + 10'b1;
                        end
                    end else begin
                        rx_bit_cnt <= rx_bit_cnt + 3'b1;
                    end
                end

                // ── Drive MISO on falling SCLK ──
                if (sclk_fall) begin
                    miso     <= tx_shift[7];
                    tx_shift <= {tx_shift[6:0], 1'b0};

                    if (tx_bit_cnt == 3'd7) begin
                        tx_bit_cnt  <= 3'b0;
                        tx_byte_cnt <= tx_byte_cnt + 10'b1;
                        // Load next byte
                        if (tx_ready && tx_byte_cnt < N_OUT_BYTES - 1) begin
                            case (tx_byte_cnt[0])
                                1'b0: tx_shift <= tx_data[1];
                                1'b1: tx_shift <= 8'hFF;
                            endcase
                        end else
                            tx_shift <= 8'hFF;
                    end else begin
                        tx_bit_cnt <= tx_bit_cnt + 3'b1;
                    end
                end
            end
        end
    end

endmodule
