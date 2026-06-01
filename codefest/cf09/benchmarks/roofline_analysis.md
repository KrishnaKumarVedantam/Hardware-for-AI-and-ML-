# Roofline Analysis — KWS Accelerator Chiplet
**ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam**
**File: codefest/cf09/benchmarks/roofline_analysis.md**

---

## Projected path — dominant uncertainty analysis

The accelerator throughput was computed using 290,180 simulation cycles at
19.7 MHz (synthesis worst path = 50.75 ns), giving 0.834 GFLOP/s projected at
AI = 187.5 FLOPs/byte on the SKY130 roofline. The design lands 144x slower than
the SW baseline, deep in the compute-bound region but far below the 6.4 GOPS
SKY130 ceiling.

The dominant uncertainty is the clock frequency. Synthesis timing repair ran
1,276 iterations and failed to close timing — the 50.75 ns critical path through
the XOR+popcount adder tree limits the chip to 19.7 MHz instead of 100 MHz. To
convert this projection to a measurement, the adder tree must be pipelined across
4 stages to reduce the critical path below 10 ns, OpenRAM SRAM macros must
replace the 32,000-FF act_buf to complete routing, and a full GDSII tape-out or
FPGA emulation must be achieved.
