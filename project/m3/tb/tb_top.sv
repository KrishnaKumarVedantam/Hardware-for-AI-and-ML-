`timescale 1ns/1ps
// =============================================================
// tb_top.sv
// KWS Accelerator M3 End-to-End Co-Simulation Testbench
// ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam
//
// Drives ONLY top-level SPI pins — no internal signal access.
// C_IN=64, K=3, N_IN_BYTES=4000 matches M1 ai_calculation.md.
// Expected values from golden.py (independent Python, seed=42).
//
// Expected MISO bytes after inference:
//   byte[0] = result[OC=0][pos=0] = -8  → 0xF8
//   byte[1] = result[OC=1][pos=0] = 14  → 0x0E
// =============================================================

module tb_top;

    reg         clk, rst_n;
    reg         sclk, cs_n, mosi;
    wire        miso;
    reg [191:0] wt_data;
    reg [5:0]   wt_oc;
    reg         wt_valid;

    top dut (
        .clk(clk), .rst_n(rst_n),
        .sclk(sclk), .cs_n(cs_n),
        .mosi(mosi), .miso(miso),
        .wt_data(wt_data), .wt_oc(wt_oc), .wt_valid(wt_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    localparam SH = 40; // 12.5 MHz SCLK, 8x ratio vs 100MHz sys_clk

    reg [63:0]  acts [0:3];
    reg [191:0] wts  [0:1];

    localparam EXP_BYTE0 = 8'hF8;
    localparam EXP_BYTE1 = 8'h0E;

    integer errors, i, j, k;
    reg [7:0] miso_bytes [0:9];

    task spi_send_byte;
        input [7:0] d;
        integer b;
        begin
            for (b=7; b>=0; b=b-1) begin
                mosi=d[b]; #(SH); sclk=1; #(SH); sclk=0;
            end
        end
    endtask

    task spi_read_byte;
        output [7:0] d;
        integer b; reg bv;
        begin
            d=8'h00;
            for (b=7; b>=0; b=b-1) begin
                mosi=0; #(SH);
                sclk=1; bv=miso; #(SH); sclk=0;
                d[b]=bv;
            end
        end
    endtask

    initial begin
        $dumpfile("sim/cosim_waveform.vcd");
        $dumpvars(0, tb_top);

        errors=0; sclk=0; cs_n=1; mosi=0;
        wt_data=0; wt_oc=0; wt_valid=0;

        acts[0]=64'hede2ce184cdc6abc;
        acts[1]=64'h4671773b332d0939;
        acts[2]=64'haf97bd6064e5c17b;
        acts[3]=64'hec0a68ebd8fc3cf5;
        wts[0]=192'haf2fff95d5f02bbddf79ff570546b63e36dffc3e355f83f4;
        wts[1]=192'h1c38b2ae2030608f978f022c2884639d8b706f894b5ad437;

        $display("==============================================");
        $display("tb_top KWS Binary Conv2 End-to-End Co-Sim");
        $display("Venkata Krishna Kumar Vedantam ECE 510 S26");
        $display("Reference: golden.py independent seed=42");
        $display("C_IN=64 K=3 N_IN_BYTES=4000 matches M1");
        $display("==============================================");

        rst_n=0; repeat(10) @(posedge clk);
        rst_n=1; repeat(5)  @(posedge clk);

        $display("\n--- Step 1: Loading weights (OC 0 and 1) ---");
        for (j=0; j<2; j=j+1) begin
            @(posedge clk);
            wt_data=wts[j]; wt_oc=j[5:0]; wt_valid=1;
            @(posedge clk); wt_valid=0;
        end
        repeat(5) @(posedge clk);

        $display("\n--- Step 2: SPI write 4000 bytes ---");
        cs_n=0; #(SH);
        for (j=0; j<4; j=j+1)
            for (k=0; k<8; k=k+1)
                spi_send_byte(acts[j][k*8 +: 8]);
        for (i=0; i<3968; i=i+1) spi_send_byte(8'h00);
        cs_n=1;
        $display("SPI write done 4000 bytes");

        $display("\n--- Step 3: Waiting ~33500 cycles ---");
        repeat(33500) @(posedge clk);

        $display("\n--- Step 4: SPI read 10 bytes ---");
        cs_n=0; #(SH);
        for (j=0; j<10; j=j+1)
            spi_read_byte(miso_bytes[j]);
        cs_n=1;

        $display("\n--- Step 5: Verify against golden.py ---");
        $display("Expected byte[0]=0x%0h (OC=0 pos=0 result=-8)", EXP_BYTE0);
        $display("Expected byte[1]=0x%0h (OC=1 pos=0 result=14)", EXP_BYTE1);
        $display("Received byte[0]=0x%0h byte[1]=0x%0h",
            miso_bytes[0], miso_bytes[1]);

        if (miso_bytes[0]===EXP_BYTE0)
            $display("PASS OC=0 pos=0 MISO=0x%0h = -8", miso_bytes[0]);
        else begin
            $display("FAIL OC=0 pos=0 got=0x%0h exp=0x%0h",
                miso_bytes[0], EXP_BYTE0);
            errors=errors+1;
        end

        if (miso_bytes[1]===EXP_BYTE1)
            $display("PASS OC=1 pos=0 MISO=0x%0h = 14", miso_bytes[1]);
        else begin
            $display("FAIL OC=1 pos=0 got=0x%0h exp=0x%0h",
                miso_bytes[1], EXP_BYTE1);
            errors=errors+1;
        end

        $display("\n==============================================");
        $display("Errors : %0d", errors);
        if (errors==0) $display("RESULT: PASS");
        else           $display("RESULT: FAIL");
        $display("==============================================");
        #100; $finish;
    end

    initial begin #3_000_000_000; $display("TIMEOUT"); $finish; end

endmodule
