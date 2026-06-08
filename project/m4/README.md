# M4 Deliverables — KWS Hardware Accelerator
ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam

## M3 to M4 Changes
- REMOVED: reg [63:0] act_buf [0:499] (32,000 FFs, timing root cause WNS=-33.14ns pre-PnR)
- ADDED: 2x sky130_sram_1kbyte_1rw1r_32x256_8 SRAM macros
- ADDED: win_buf[0:2] sliding window (fanout=1 per bit)
- ADDED: PRE_FETCH0/1/2 states for SRAM read latency
- N_POS=8 (synthesis scope; full L=500 needs 2 more SRAMs)
- Timing: WNS=-33.14ns (M3, pre-PnR Stage 12 STA) -> WNS=0.00ns at 30.3MHz (M4)
- Cells: 160,471 (M3) -> 39,187 (M4, 75.6% reduction)

## File Catalog

### rtl/
- compute_core.sv  BNN Conv2 engine, SRAM act_buf, sliding window [Section 4]
- top.sv           Top module, integrates compute_core + spi_slave [Section 4]
- interface.sv     SPI slave, rx_done, weight loading protocol [Section 5]
- sram_model.sv    Behavioral SRAM model for simulation only [Section 6]

### tb/
- tb_top.sv        End-to-end cosim, SPI protocol, golden.py reference [Section 6]

### sim/
- final_run.log        iverilog output, RESULT: PASS [Section 6]
- final_waveform.png   Annotated waveform from VCD [Section 6]
- cosim_waveform.vcd   Full VCD dump [Section 6]

### synth/
- config.json          OpenLane 2 config, CLOCK_PERIOD=33.0, SRAM macros [Section 7]
- openlane_run.log     Yosys 0.38 synthesis log [Section 7, Section 9]
- timing_report.txt    OpenSTA: WNS=0.00, slack=+1.093ns at 30.3MHz [Section 7]
- area_report.txt      Yosys stat: 39,187 cells, 508,711 um2 std cells [Section 7]
- power_report.txt     OpenSTA: 24.6 mW total at TT 1.8V 25C [Section 7]
- netlist_clean.v      Post-synthesis netlist, SRAM blackboxed [Section 7]

### bench/
- benchmark.md         Throughput, speedup, energy vs M1 baseline [Section 8]
- benchmark_data.csv   Raw numbers behind benchmark summary [Section 8]
- roofline_final.png   Roofline: SW point + measured HW M4 point [Section 2]

### report/
- design_justification.pdf   9-section design report [all sections]
- figures/                   Figures referenced in report

## Simulation Reproduction
cd project/m4
iverilog -g2012 -o sim/cosim tb/tb_top.sv rtl/top.sv rtl/interface.sv rtl/compute_core.sv rtl/sram_model.sv
vvp sim/cosim 2>&1 | tee sim/final_run.log

## Synthesis Note
OpenLane 2 pyosys flag unavailable in pip/conda builds. Direct yosys 0.38 + OpenSTA used instead. See Section 9 of report.
