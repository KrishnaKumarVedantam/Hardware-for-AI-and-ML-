# Benchmark Results — KWS Accelerator Chiplet
**ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam**
**File: codefest/cf09/benchmarks/benchmark_results.md**
**Date: May 31, 2026**

---

## Task 6 — Software Baseline (re-run May 31, 2026)

Platform: Apple MacBook Pro, Apple M4, macOS, Python 3.9, PyTorch 2.8.0
Script: `profiling/benchmark.py` — 100 runs, 10 warmup, time.perf_counter()

| Metric | Value | Source |
|--------|-------|--------|
| Median latency | **0.102 ms** | benchmark.py measured |
| Min latency | 0.099 ms | benchmark.py measured |
| Max latency | 0.121 ms | benchmark.py measured |
| Throughput | **9,760 samples/sec** | 1000 / 0.102 ms |
| GFLOP/s achieved | **121.82 GFLOP/s** | 12,481,280 FLOPs / 0.102ms / 1e6 |
| Peak memory | **0.0012 MB** | tracemalloc |
| Total FLOPs | 12,481,280 | analytically derived |

---

## Task 7 — Hardware Accelerator (projected)

**Simulation path used:** M3 testbench `tb_top.sv` ran with Icarus Verilog 12.0
and produced RESULT: PASS. Cycle count taken from simulation end time.
Clock frequency taken from synthesis timing report (max achievable clock).
All numbers labeled **[projected]** per prof spec.

### Projection assumptions (documented explicitly)

| Assumption | Value | Source |
|------------|-------|--------|
| Clock frequency | 19.7 MHz | timing_report.txt: worst path 50.75ns → 1/50.75ns |
| Total cycles per inference | 290,180 | cosim_run.log: $finish at 2,901,805,000 ps, clk=10ns |
| Useful FLOPs | 12,288,000 | Conv2 dominant kernel: 2×64×64×3×500 |
| SPI bandwidth | 0.308 MB/s | interface.sv: 8 sys_clk per SPI bit at 19.7 MHz |
| Power estimate | ~95 mW | pre-PnR 286.1 mW / 3 (post-route estimate) |
| Total cells | 160,471 | area_report.txt |
| Chip area | 2,196,806 µm² | area_report.txt |
| WNS (pre-PnR) | -41.09 ns | timing_report.txt |

### Projected hardware results

| Metric | Value | Label |
|--------|-------|-------|
| Inference time | **14.73 ms** | [projected] |
| Throughput | **67.9 samples/sec** | [projected] |
| GFLOP/s | **0.834 GFLOP/s** | [projected] |
| Memory bandwidth | **0.308 MB/s** | [projected] |
| Energy per inference | **~1,405 µJ** | [projected] |

---

## Task 8 — Speedup and Energy Comparison

| Metric | SW Baseline | HW Accelerator | Ratio |
|--------|-------------|----------------|-------|
| Latency (ms) | 0.102 | 14.73 [projected] | 144x slower |
| Throughput (samples/sec) | 9,760 | 67.9 [projected] | 0.007x |
| GFLOP/s | 121.82 | 0.834 [projected] | 0.007x |
| Peak memory (MB) | 0.0012 | N/A (on-chip) | — |
| Energy per inference | N/A | ~1,405 µJ [projected] | — |

**Speedup = SW throughput / HW throughput = 9,760 / 67.9 = 0.007x**

**The hardware accelerator is 144x slower than the software baseline.**

### Why HW is slower — explained

This result is expected given the current implementation state:

1. **Timing not closed:** Synthesis worst path is 50.75 ns, limiting clock
   to 19.7 MHz instead of the target 100 MHz. This alone causes a 5x slowdown.

2. **SPI interface bottleneck:** Loading 4,000 bytes over SPI at 19.7 MHz
   with 8 system clocks per bit = 256,000 cycles just for data loading.
   SPI bandwidth is only 0.308 MB/s vs 120 GB/s Mac M4 memory bandwidth.

3. **Non-pipelined compute:** FSM processes one position per cycle sequentially.
   500 positions × 500 cycle overhead = 250,000 compute cycles.

4. **Comparison is unfair:** SW baseline runs on Apple M4 with 4,000 GFLOP/s
   peak compute and native SIMD. HW chiplet targets SKY130 130nm at 100 MHz.
   The correct comparison is HW vs ARM Cortex-M MCU, not vs M4 CPU.

### After M4 fixes (projected target per synthesis_notes.md)

| Fix | Effect |
|-----|--------|
| OpenRAM SRAM replaces 32K FFs | OOM fixed, N_IN_BYTES=4000 restored |
| Pipelined adder tree (4 stages) | Critical path 50.75ns → four ~10ns stages |
| Clock lowered to 40 MHz (25ns) | Timing closes at 40 MHz [projected] |
| Projected throughput (SPI kept) | 156 samples/sec, 1.92 GFLOP/s [projected] |

Note: HW remains slower than SW baseline (9,760 samples/sec) in the batch
benchmark because SPI loads 4,000 bytes serially in 6.4 ms at 40 MHz.
In real-time streaming deployment (16 kHz audio, 8 bytes per frame every
10 ms), SPI at 5 Mbps is 625x faster than the audio rate — the interface
is not a bottleneck for real KWS use. The batch benchmark comparison against
Mac M4 (4,000 GFLOP/s) is intentionally unfair; the correct deployment
target is an ARM Cortex-M MCU where the chiplet would be ~16x faster.

