# Software Baseline Benchmark
**ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam**
**File: project/m1/sw_baseline.md**

---

## Platform and configuration

| Parameter | Value |
|-----------|-------|
| Hardware | Apple MacBook Pro, Apple M4 chip |
| OS | macOS (Apple Silicon native) |
| Python version | 3.9 |
| PyTorch version | 2.8.0 |
| Batch size | 1 (single inference — always-on scenario) |
| Input shape | (1, 1, 500) — 1 sample, 1 channel, 500 values |
| Input description | 50 MFCC frames x 10 mel coefficients = 500 INT8 values |
| Timing runs | 100 (median reported, 10 warmup runs discarded) |
| Timing method | time.perf_counter(), torch.no_grad() enabled |
| Profiler | cProfile (Python standard library) |



## Execution time

| Metric | Value |
|--------|-------|
| Median latency | **0.102 ms** |
| Min latency | 0.100 ms |
| Max latency | 0.119 ms |

Median taken over 100 runs after 10 warmup runs using time.perf_counter()
with torch.no_grad() enabled. Wall-clock time measured from model input
to output tensor.

---

## Throughput

| Metric | Value |
|--------|-------|
| Throughput | **9,787 samples/sec** |
| GFLOP/s achieved | **122.17 GFLOP/s** |
| Total FLOPs per inference | 12,481,280 |

Calculation:
```
Throughput = 1000 ms / 0.102 ms = 9,787.1 samples/sec
GFLOP/s    = 12,481,280 FLOPs / 0.000102 s / 1,000,000,000 = 122.17
```

FLOPs breakdown per inference (analytically derived):
```
Conv1 (1->64,   k=3, L=500): 2 x  1 x 64 x 3 x 500 =    192,000
Conv2 (64->64,  k=3, L=500): 2 x 64 x 64 x 3 x 500 = 12,288,000
FC    (64->10)              : 2 x 64 x 10            =      1,280
Total                        =                          12,481,280
```

Conv2 alone = 12,288,000 / 12,481,280 = **98.4% of total FLOPs**

---

## Memory usage

| Metric | Value |
|--------|-------|
| Peak memory (tracemalloc) | **0.0012 MB** |
| Binary weights (1-bit packed, Conv2) | 1,536 bytes |
| Binary weights (1-bit packed, Conv1) | 24 bytes |
| Total binary weight memory | 1,560 bytes |

---

## M4 comparison point for Milestone 4

This is the official M4 reference. At M4 the hardware accelerator
throughput and latency will be compared against:

- Software baseline latency   : **0.102 ms**
- Software baseline throughput: **9,787 samples/sec**
- Software baseline GFLOP/s   : **122.17**
- Hardware target GFLOP/s     : 400 (projected, 3.3x improvement)

Note: On a real deployment target MCU (STM32H7 at 480 MHz), the same FP32
model would take approximately 40-120 ms per inference. The hardware
accelerator improvement over the MCU baseline would be 400-1200x, far
exceeding the 3.3x improvement over the M4 benchmark.
