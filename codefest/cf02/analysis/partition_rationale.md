# HW/SW Partition Rationale
**ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam**
**File: codefest/cf02/analysis/partition_rationale.md**

---

## 1. Which kernel to accelerate in hardware

The hardware accelerator targets exclusively the **binary 1D Conv2 layer**
(torch.conv1d, 64 input channels, 64 output channels, kernel size 3,
sequence length 500).

Profiling on Apple Mac M4 using cProfile confirmed torch.conv1d as the
function with the highest cumulative execution time across 10 inference
runs. Analytical FLOPs counting shows Conv2 alone accounts for 12,288,000
out of 12,481,280 total FLOPs — exactly 98.4% of all compute. Conv1
accounts for 192,000 FLOPs (1.5%) and FC accounts for 1,280 FLOPs (0.01%).
Conv1 and FC are negligible and do not justify custom silicon.

Arithmetic intensity of Conv2 with 1-bit packed weights and INT8
activations, assuming no DRAM reuse:

```
Formula : AI = FLOPs / Bytes
FLOPs   : 2 x 64 x 64 x 3 x 500 = 12,288,000
Weights : 64 x 64 x 3 / 8 = 1,536 bytes (1-bit packed)
Inputs  : 64 x 500 x 1   = 32,000 bytes (INT8)
Outputs : 64 x 500 x 1   = 32,000 bytes (INT8)
Total B : 65,536 bytes
AI      : 12,288,000 / 65,536 = 187.5 FLOPs/byte
```

On the Mac M4 roofline (peak compute 4,000 GFLOP/s from apple.com/mac/m4,
peak bandwidth 120 GB/s, ridge point 33.3 FLOPs/byte), the Conv2 kernel
sits 5.6x above the ridge point — firmly compute-bound. This is the
roofline justification for hardware acceleration: the bottleneck is compute
throughput, not memory bandwidth, and dedicated XOR+popcount hardware
directly increases compute throughput.

---

## 2. What remains in software and why

The following pipeline stages remain in software on the host MCU:

**MFCC feature extraction (software on host MCU):**
Converts raw 16 kHz audio frames into the 50x10 MFCC feature matrix using
FFT, mel filterbank, and DCT operations. This is a signal processing stage
with irregular data dependencies, low arithmetic intensity, and small
absolute compute cost. It accounts for less than 1% of total pipeline
compute and is not a meaningful acceleration target. Running it in software
on the host MCU is correct.

**BatchNorm threshold (fused into Conv2 hardware):**
During training, BatchNorm normalizes Conv2 outputs. At inference, BatchNorm
is folded into a single integer threshold comparison per output channel —
this is already part of the hardware compute engine, not a software stage.

**Softmax and decision thresholding (software on host MCU):**
Applied to the 10-element FC output vector. This is 10 comparisons —
negligible compute. No justification for custom silicon.

**Application control (software on host MCU):**
Wake/idle signaling, debouncing, and power management are event-driven and
irregular. These do not have a fixed compute pattern and cannot be
accelerated by a fixed-function datapath.

These stages collectively represent less than 2% of total compute and are
either irregular, I/O-bound, or trivially small.

---

## 3. Compute-bound vs memory-bound analysis

**Current software on Mac M4:**
Conv2 at AI = 187.5 FLOPs/byte sits 5.6x above the M4 ridge point of
33.3 FLOPs/byte. The kernel is compute-bound in software. The M4 achieves
122.17 GFLOP/s out of 4,000 GFLOP/s peak — only 3.05% utilization. This
poor utilization occurs because the general-purpose CPU promotes binary
weights to FP32 internally, wasting 32x of both compute and memory
bandwidth.

**Hardware design (KWS chiplet):**
The hardware design does not change the arithmetic intensity of the Conv2
kernel — it remains at 187.5 FLOPs/byte because the same algorithm operates
on the same data. What changes is the achievable performance: dedicated XOR
gates and popcount trees deliver the full 12,288,000 operations per
inference using single-cycle binary operations instead of multi-cycle FP32
multiply-accumulate. The hardware design remains compute-bound, which is
correct — the kernel is naturally compute-bound and the hardware is
specifically designed to be fast at this exact computation.

Weight memory: 1-bit packed Conv2 weights = 1,536 bytes total. This fits
entirely in on-chip SRAM, eliminating DRAM weight access during inference
and making the effective arithmetic intensity even higher in practice.

**The hardware design does NOT change compute-bound to memory-bound.**
The kernel stays compute-bound. The hardware simply achieves much higher
utilization of available compute by using the correct arithmetic (XOR) for
the correct data type (1-bit binary weights).

---

## 4. Interface bandwidth required

The SPI interface must not make the accelerator interface-bound.

Data per inference:
```
Input  : 500 bytes (MFCC feature vector, 500 x INT8)
Output : 10 bytes  (10 class scores, INT8)
Total  : 510 bytes per inference
```

Required bandwidth at target 10 Hz inference rate:
```
BW = 510 bytes x 10 Hz = 5,100 bytes/sec = 0.041 Mbit/s
```

SPI rated bandwidth: 50 Mbit/s

Utilization:
```
0.041 Mbit/s / 50 Mbit/s = 0.082%
```

The accelerator uses 0.082% of SPI bandwidth. The interface does not appear
as a constraint on the roofline and does not make the design interface-bound.
The design remains compute-bound at AI = 187.5 FLOPs/byte, well above both
the M4 ridge point (33.3 FLOPs/byte) and any interface constraint.

The hypothetical hardware design point on the roofline targets 400 GFLOP/s
with an on-chip SRAM bandwidth of 6.4 GB/s (64-bit bus at 100 MHz). At
AI = 187.5 FLOPs/byte and 6.4 GB/s SRAM bandwidth, the peak achievable
performance would be 6.4 x 187.5 = 1,200 GFLOP/s — well above the 400
GFLOP/s target, confirming the chiplet design point is compute-bound on
the on-chip roofline as well.

---

## 5. Conclusion

The binary 1D Conv2 kernel is the correct and well-justified sole target
for hardware acceleration. It dominates runtime at 98.4% of FLOPs, is
strongly compute-bound (AI = 187.5 FLOPs/byte, 5.6x above M4 ridge point),
has a regular fixed structure ideal for RTL pipelining, and its 1,536-byte
1-bit packed weight representation fits entirely in on-chip SRAM. MFCC
extraction, softmax, and application control remain in software on the host
MCU. The SPI interface operates at 0.082% of rated bandwidth and is not a
bottleneck. Hardware acceleration of Conv2 is analytically justified by
both the FLOPs dominance and the roofline compute-bound position.
