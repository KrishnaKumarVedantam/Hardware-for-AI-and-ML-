# M4 Hardware Benchmark vs M1 Software Baseline

## Method
- SW baseline: from project/m1/sw_baseline.md (measured, 100 runs, median)
- HW cycles: measured from VCD (rx_done=41,225,000ps to cc_done=51,405,000ps = 1,018 cycles)
- HW time: 1,018 cycles / 30.3 MHz = 0.0336 ms (N_POS=8, synthesized scope)
- HW full inference extrapolated: 32,504 cycles / 30.3 MHz = 1.0727 ms (N_POS=500)
- HW energy: 24.6 mW (OpenSTA) × 1.0727 ms = 26.39 µJ

## Results

| Metric | SW Baseline (M1) | HW M4 (N_POS=8) | HW M4 (N_POS=500 extrap.) |
|--------|-----------------|-----------------|--------------------------|
| Inference time | 0.102 ms | 0.0336 ms | 1.0727 ms |
| Throughput | 9,787 samples/sec | 29,762 samples/sec | 932 samples/sec |
| Clock | N/A | 30.3 MHz | 30.3 MHz |
| Cycles | N/A | 1,018 | 32,504 |
| Power | ~15,000 mW | 24.6 mW | 24.6 mW |
| Energy/inference | ~1,530 µJ | 0.827 µJ | 26.39 µJ |

## Speedup (honest, fair comparison)
- N_POS=8 HW vs full SW: 0.0336 ms vs 0.102 ms = **3.04x** (UNFAIR — different scope)
- N_POS=500 extrapolated vs SW: 1.0727 ms vs 0.102 ms = **0.095x (HW is 10.5x SLOWER)**
- Prof says: "If your accelerator is slower, say so and explain why."

## Why HW is slower (throughput)
1. Clock: 30.3 MHz vs M4 Pro effective ~GHz
2. Sequential G_LOAD: 500 cycles overhead per inference
3. Synthesis scope: N_POS=8 verified; N_POS=500 needs 2 more SRAM macros
4. SPI interface: 4000 bytes at 5 Mbps = 6.4 ms/frame dominates real deployment

## Energy efficiency (HW wins decisively)
- SW energy: 15,000 mW × 0.102 ms = 1,530 µJ
- HW energy: 24.6 mW × 1.0727 ms = 26.39 µJ
- **HW is 58x more energy efficient**
- Target: always-on edge KWS (battery-powered), not throughput maximization
