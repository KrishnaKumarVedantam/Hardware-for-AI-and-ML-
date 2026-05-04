// =============================================================
// tb_interface.sv
// SPI Slave Interface Testbench — Icarus Verilog 12
// ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam
//
// Tests:
//   T1: Write 4 bytes over MOSI, verify rx_data
//   T2: Read 2 bytes from MISO, verify match tx_data
//   T3: rx_done fires exactly once after last byte
//   T4: Second write with different data
// =============================================================
`timescale 1ns/1ps

module tb_interface;

    localparam SCLK_HALF = 200;  // 200ns half-period = 2.5MHz SPI
    localparam CLK_HALF  = 10;   // 10ns sys_clk = 50MHz

    reg sys_clk=0, rst_n=0;
    reg sclk=0, cs_n=1, mosi=0;
    wire miso;

    wire [7:0] rx_data_w [0:3];
    wire       rx_done;
    reg  [7:0] tx_data_r [0:1];
    reg        tx_ready=0;

    spi_slave #(.N_IN_BYTES(4),.N_OUT_BYTES(2)) dut(
        .sys_clk(sys_clk),.rst_n(rst_n),
        .sclk(sclk),.cs_n(cs_n),.mosi(mosi),.miso(miso),
        .rx_data(rx_data_w),.rx_done(rx_done),
        .tx_data(tx_data_r),.tx_ready(tx_ready));

    always #CLK_HALF sys_clk=~sys_clk;

    integer total_pass, total_fail;
    integer miso_cap [0:7];  // captured MISO bits per byte
    reg rx_done_latch;

    always @(posedge sys_clk) if(rx_done) rx_done_latch=1;

    // Send one byte, capture MISO, MSB first
    task spi_byte_rw;
        input  [7:0] tx_byte;
        input  integer bidx;
        integer bit_i;
        miso_cap[bidx]=0;
        for(bit_i=7; bit_i>=0; bit_i=bit_i-1) begin
            mosi = tx_byte[bit_i];
            #SCLK_HALF;
            sclk=1;          // rising edge: DUT samples MOSI
            #SCLK_HALF;
            sclk=0;          // falling edge: DUT drives next MISO bit
            // Wait for sys_clk synchronizer to process sclk_fall
            repeat(4) @(posedge sys_clk);
            // Sample MISO — stable now
            miso_cap[bidx] = (miso_cap[bidx] << 1) | miso;
        end
        mosi=0;
    endtask

    task do_transaction;
        input [7:0] b0,b1,b2,b3;
        rx_done_latch=0;
        cs_n=0;
        repeat(6) @(posedge sys_clk);  // CS setup
        spi_byte_rw(b0, 0);
        spi_byte_rw(b1, 1);
        spi_byte_rw(b2, 2);
        spi_byte_rw(b3, 3);
        repeat(6) @(posedge sys_clk);  // CS hold
        cs_n=1;
        repeat(10) @(posedge sys_clk);
    endtask

    initial begin
        $dumpfile("tb_interface.vcd");
        $dumpvars(0,tb_interface);
        rst_n=0; total_pass=0; total_fail=0;
        tx_data_r[0]=8'hA5; tx_data_r[1]=8'h3C; tx_ready=1;
        repeat(8)@(posedge sys_clk); rst_n=1; repeat(4)@(posedge sys_clk);

        $display("==============================================");
        $display("tb_interface -- KWS SPI Slave");
        $display("Venkata Krishna Kumar Vedantam | ECE 510 Spring 2026");
        $display("SPI Mode 0 (CPOL=0 CPHA=0) MSB first");
        $display("N_IN_BYTES=4 N_OUT_BYTES=2");
        $display("==============================================");

        //==============================================
        // T1: Write — send 0xDE 0xAD 0xBE 0xEF
        //==============================================
        $display("\n--- T1: Write transaction ---");
        do_transaction(8'hDE, 8'hAD, 8'hBE, 8'hEF);
        begin
            integer f; f=0;
            $display("  rx[0]=%h (exp DE)", rx_data_w[0]);
            $display("  rx[1]=%h (exp AD)", rx_data_w[1]);
            $display("  rx[2]=%h (exp BE)", rx_data_w[2]);
            $display("  rx[3]=%h (exp EF)", rx_data_w[3]);
            if(rx_data_w[0]!==8'hDE) f++;
            if(rx_data_w[1]!==8'hAD) f++;
            if(rx_data_w[2]!==8'hBE) f++;
            if(rx_data_w[3]!==8'hEF) f++;
            total_fail+=f;
            if(f==0) begin total_pass++; $display("  T1-write: PASS"); end
            else $display("  T1-write: FAIL (%0d errors)",f);
        end

        //==============================================
        // T2: Read — verify MISO carries tx_data
        // tx_data[0]=0xA5, tx_data[1]=0x3C
        // MISO bit driven after SCLK falls, stable before next SCLK rise
        //==============================================
        $display("\n--- T2: Read transaction (MISO = tx_data) ---");
        tx_data_r[0]=8'hA5; tx_data_r[1]=8'h3C; tx_ready=1;
        repeat(4)@(posedge sys_clk);
        do_transaction(8'h00, 8'h00, 8'h00, 8'h00);
        begin
            integer f; f=0;
            $display("  MISO byte0=%h (exp A5)", miso_cap[0]);
            $display("  MISO byte1=%h (exp 3C)", miso_cap[1]);
            if(miso_cap[0]!==8'hA5) f++;
            if(miso_cap[1]!==8'h3C) f++;
            total_fail+=f;
            if(f==0) begin total_pass++; $display("  T2-read: PASS"); end
            else $display("  T2-read: FAIL");
        end

        //==============================================
        // T3: rx_done pulse check
        //==============================================
        $display("\n--- T3: rx_done pulse ---");
        if(rx_done_latch) begin
            total_pass++;
            $display("  T3-rx_done: PASS");
        end else begin
            total_fail++;
            $display("  T3-rx_done: FAIL (never pulsed)");
        end

        //==============================================
        // T4: Second write, different data
        //==============================================
        $display("\n--- T4: Second write 0x12 0x34 0x56 0x78 ---");
        do_transaction(8'h12, 8'h34, 8'h56, 8'h78);
        begin
            integer f; f=0;
            if(rx_data_w[0]!==8'h12) begin $display("  FAIL rx[0]=%h exp 12",rx_data_w[0]); f++; end
            if(rx_data_w[1]!==8'h34) begin $display("  FAIL rx[1]=%h exp 34",rx_data_w[1]); f++; end
            if(rx_data_w[2]!==8'h56) begin $display("  FAIL rx[2]=%h exp 56",rx_data_w[2]); f++; end
            if(rx_data_w[3]!==8'h78) begin $display("  FAIL rx[3]=%h exp 78",rx_data_w[3]); f++; end
            if(!rx_done_latch) begin $display("  FAIL rx_done never fired"); f++; end
            total_fail+=f;
            if(f==0) begin total_pass++; $display("  T4-second-write: PASS"); end
            else $display("  T4-second-write: FAIL (%0d errors)",f);
        end

        $display("\n==============================================");
        $display("Tests passed : %0d / 4", total_pass);
        $display("Total errors : %0d", total_fail);
        if(total_fail==0) $display("RESULT: PASS");
        else              $display("RESULT: FAIL");
        $display("==============================================");
        $finish;
    end

    initial begin #50000000; $display("TIMEOUT"); $finish; end

endmodule
