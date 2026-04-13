# Arithmetic Intensity Calculation
**ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam**
**File: codefest/cf02/analysis/ai_calculation.md**

---

## 1. Dominant kernel identification

**"The dominant kernel is the binary 1D Conv2 layer (torch.conv1d),
accounting for 98.4% of total FLOPs (12,288,000 out of 12,481,280
FLOPs per inference)."**

From cProfile profiling on Apple Mac M4 (Python 3.9, PyTorch 2.8.0,
batch size 1, 10 inference runs):

- torch.conv1d was called 20 times (2 conv layers x 10 runs)
- torch.conv1d had the highest cumulative execution time of all functions
- Conv2 has 64x more FLOPs than Conv1 (64 input channels vs 1 input channel)
- Conv2 = 12,288,000 FLOPs = 98.4% of all 12,481,280 total FLOPs

Conv2 is the acceleration target. Conv1 (1.5%) and FC (0.01%) are negligible.

---

## 2. FLOPs calculation (derived from algorithm, not profiler)

### Formula for 1D convolution

```
FLOPs = 2 x C_in x C_out x K x L_out
```

Where:
- C_in  = number of input channels
- C_out = number of output channels (filters)
- K     = kernel size
- L_out = output sequence length (= input length with padding=1)
- Factor 2 = one multiply + one add per MAC operation

### Conv1 (C_in=1, C_out=64, K=3, L=500) — NOT the dominant kernel

```
FLOPs = 2 x 1 x 64 x 3 x 500

Step 1:  1 x 64  =     64
Step 2: 64 x  3  =    192
Step 3: 192 x 500 = 96,000
Step 4: 96,000 x 2 = 192,000
```

**Conv1 FLOPs = 192,000 (1.5% of total — NOT the dominant kernel)**

### Conv2 — DOMINANT KERNEL (C_in=64, C_out=64, K=3, L=500)

```
FLOPs = 2 x 64 x 64 x 3 x 500

Step 1:  64 x  64 =  4,096
Step 2: 4,096 x 3 = 12,288
Step 3: 12,288 x 500 = 6,144,000
Step 4: 6,144,000 x 2 = 12,288,000
```

**Conv2 FLOPs = 12,288,000 (98.4% of total — THIS IS THE DOMINANT KERNEL)**

### FC layer (inputs=64, outputs=10)

```
FLOPs = 2 x 64 x 10 = 1,280
```

**FC FLOPs = 1,280 (0.01% of total — negligible)**

### Total FLOPs verification

```
Conv1  =    192,000  (1.5%)
Conv2  = 12,288,000  (98.4%)  <- dominant kernel
FC     =      1,280  (0.01%)
Total  = 12,481,280
```

Verification: benchmark.py reported Total FLOPs = 12,481,280. Matches
analytically derived value exactly.

---

## 3. Bytes transferred — DRAM, no reuse assumed

All operands assumed loaded fresh from DRAM per inference. No cache reuse,
no weight reuse across output positions. This is the pessimistic case for
arithmetic intensity (lower bound on AI).

Precision: weights = 1-bit packed. Activations = INT8 (1 byte each).

### Weight bytes

**Conv2 weights (1-bit packed) — dominant kernel:**
```
Weight elements = C_out x C_in x K = 64 x 64 x 3 = 12,288 elements
Bits            = 12,288 x 1-bit   = 12,288 bits
Bytes           = 12,288 / 8       = 1,536 bytes
```

**Conv1 weights (1-bit packed):**
```
Weight elements = 64 x 1 x 3 = 192 elements
Bytes           = 192 / 8    = 24 bytes
```

**FC weights (INT8):**
```
Weight elements = 10 x 64 = 640 elements
Bytes           = 640 x 1  = 640 bytes
```

**Total weight bytes = 1,536 + 24 + 640 = 2,200 bytes**

### Input activation bytes (INT8)

```
Input to Conv1  = C_in1  x L = 1  x 500 =    500 bytes
Input to Conv2  = C_out1 x L = 64 x 500 = 32,000 bytes
Input to FC     = pooled      = 64 x 1  =     64 bytes
Total inputs    =               32,564 bytes
```

### Output activation bytes (INT8)

```
Output of Conv1 = C_out1 x L = 64 x 500 = 32,000 bytes
Output of Conv2 = C_out2 x L = 64 x 500 = 32,000 bytes
Output of FC    =              10 x 1   =     10 bytes
Total outputs   =               64,010 bytes
```

### Total bytes transferred from DRAM

```
Weights  =  2,200 bytes
Inputs   = 32,564 bytes
Outputs  = 64,010 bytes
Total    = 98,774 bytes
```

Summary table:

| Operand | Precision | Bytes |
|---------|-----------|-------|
| Conv1 weights | 1-bit packed | 24 |
| Conv2 weights | 1-bit packed | 1,536 |
| FC weights | INT8 | 640 |
| Input activations (all layers) | INT8 | 32,564 |
| Output activations (all layers) | INT8 | 64,010 |
| **Total DRAM bytes** | | **98,774** |

---

## 4. Arithmetic intensity value

### Full model arithmetic intensity

```
AI (full model) = Total FLOPs / Total Bytes
AI (full model) = 12,481,280 / 98,774
AI (full model) = 126.4 FLOPs/byte
```

### Conv2 dominant kernel arithmetic intensity (acceleration target)

For Conv2 specifically, using only Conv2 operands:

```
Conv2 FLOPs         = 12,288,000
Conv2 weight bytes  =  1,536  (1-bit packed)
Conv2 input bytes   = 32,000  (64 x 500 INT8)
Conv2 output bytes  = 32,000  (64 x 500 INT8)
Conv2 total bytes   = 65,536

AI (Conv2) = 12,288,000 / 65,536 = 187.5 FLOPs/byte
```

**Arithmetic intensity = 187.5 FLOPs/byte**
(Conv2 dominant kernel, 1-bit packed weights, INT8 activations, no DRAM reuse)

---

## 5. Roofline position — compute-bound or memory-bound?

**Platform: Apple Mac M4**

| Parameter | Value | Source |
|-----------|-------|--------|
| Peak compute | 4,000 GFLOP/s | apple.com/mac/m4 spec sheet |
| Peak memory bandwidth | 120 GB/s | Apple M4 spec sheet |
| Ridge point | 4,000 / 120 = **33.3 FLOPs/byte** | Calculated |

**Position of Conv2 kernel:**

```
Conv2 AI    = 187.5 FLOPs/byte
Ridge point =  33.3 FLOPs/byte

Ratio = 187.5 / 33.3 = 5.6x above the ridge point
```

**The Conv2 kernel is COMPUTE-BOUND — it sits 5.6x to the right of the
ridge point on the roofline.**

This means:
- Adding more memory bandwidth will NOT improve performance
- Adding more compute units (XOR+popcount array) WILL improve performance
- Custom hardware acceleration of Conv2 is analytically justified

**Why SW achieved only 122.17 GFLOP/s vs 4,000 GFLOP/s peak:**
The CPU achieved 122.17 / 4,000 = 3.05% of hardware peak. This is because
the general-purpose CPU has no native 1-bit multiply instruction and
internally promotes binary weights to FP32, wasting 32x of compute
capacity. The gap between 122.17 GFLOP/s (measured) and 4,000 GFLOP/s
(hardware peak) is the motivation for building the chiplet. The hardware
design point targets 400 GFLOP/s using dedicated XOR+popcount units.

---

## 6. Summary

| Metric | Value |
|--------|-------|
| **Dominant kernel** | **Binary Conv2 (torch.conv1d)** |
| Dominant kernel share of FLOPs | 98.4% (12,288,000 / 12,481,280) |
| Total model FLOPs | 12,481,280 |
| Conv2 weight bytes (1-bit packed) | 1,536 |
| Conv2 input bytes (INT8) | 32,000 |
| Conv2 output bytes (INT8) | 32,000 |
| Conv2 total DRAM bytes | 65,536 |
| **Arithmetic intensity (Conv2)** | **187.5 FLOPs/byte** |
| Platform ridge point (Mac M4) | 33.3 FLOPs/byte |
| Kernel position on roofline | Compute-bound (5.6x above ridge) |
| SW achieved (Mac M4) | 122.17 GFLOP/s (3.05% of peak) |
| HW target (KWS chiplet) | 400 GFLOP/s |
| M4 hardware peak (spec) | 4,000 GFLOP/s |
