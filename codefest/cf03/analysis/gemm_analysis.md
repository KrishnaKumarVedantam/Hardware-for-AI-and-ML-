# GEMM Analysis: Naive vs. Tiled CUDA Kernels
# ECE 410/510 — Codefest 3 | 1024×1024 FP32 Matrix Multiply on NVIDIA T4 GPU

## Profiling Summary

| Metric                  | Naive Kernel        | Tiled Kernel (T=8)  |
|-------------------------|---------------------|---------------------|
| Execution Time          | 5.5808 ms           | 6.7163 ms           |
| Achieved GFLOP/s        | 384.80              | 319.74              |
| DRAM Throughput         | 7.23% (~23 GB/s)    | 5.94% (~19 GB/s)    |
| SM Throughput           | 62.48% of peak      | 55.19% of peak      |
| Arithmetic Intensity    | 0.25 FLOP/byte      | 2.0 FLOP/byte       |
| Roofline Position       | Memory-bound        | Memory-bound        |
| T4 Ridge Point          | 25.31 FLOP/byte     | 25.31 FLOP/byte     |

---

## (a) Why the Naive Kernel is Memory-Bound

The naive CUDA kernel assigns exactly one thread to compute one output
element C[i][j]. Each thread independently iterates over all K=1024
elements, loading every value of a row of A and a column of B directly
from global DRAM on every single access. There is zero data reuse across
threads — if two threads in the same row need the same element of B,
they each fetch it separately from DRAM, wasting bandwidth.

This access pattern gives an arithmetic intensity of just 0.25 FLOP/byte,
calculated as:

  AI = (2 * N^3 FLOPs) / (2 * N^3 * 4 bytes) = 0.25 FLOP/byte

The T4 GPU ridge point sits at 25.31 FLOP/byte (8100 GFLOP/s ÷ 320 GB/s).
At 0.25 FLOP/byte the naive kernel is 100x below the ridge, placing it
firmly on the memory-bound slope of the roofline.

Nsight Compute confirmed this: DRAM throughput was only 7.23% of the T4's
320 GB/s peak, meaning the kernel used just ~23 GB/s. Interestingly, SM
throughput was 62.48%, higher than expected for a purely memory-bound
kernel. This is because the T4's large L2 cache (~4MB) absorbed many
repeated accesses to B, partially masking the DRAM bottleneck. However,
the kernel still sits far below the roofline ceiling, confirming it cannot
exploit the full compute potential of the GPU.

---

## (b) How Tiling Reduces DRAM Traffic

The tiled kernel partitions A and B into 8×8 sub-blocks and loads each
tile once into on-chip shared memory (SRAM), which is orders of magnitude
faster than global DRAM (~19 TB/s shared memory bandwidth vs 320 GB/s DRAM).
All 64 threads within a block then reuse the same shared memory tile to
compute their partial dot products before loading the next tile.

Each element of A and B is therefore fetched from DRAM only N/T = 1024/8
= 128 times instead of N = 1024 times in the naive case. This reduces
total DRAM traffic by exactly a factor of T=8, which is reflected in the
arithmetic intensity calculation:

  Tiled AI = (2 * N^3) / (2 * N^2 * (N/T) * 4) = T/4 = 2.0 FLOP/byte

The tiled kernel's AI of 2.0 FLOP/byte is 8x higher than naive's 0.25
FLOP/byte, exactly matching the theoretical prediction. On the roofline
plot, the tiled kernel visibly shifts rightward from naive — from 0.25
toward 2.0 FLOP/byte — confirming that tiling successfully reduced DRAM
traffic. However, at AI=2.0 it remains well to the left of the ridge
point at 25.31 FLOP/byte, meaning the tiled kernel is still
memory-bound despite the improvement.

---

## (c) Expected vs. Achieved Improvement and Remaining Bottleneck

With T=8 tiling reducing DRAM traffic by 8x, we expected the tiled kernel
to be meaningfully faster than naive. The theoretical roofline prediction
for tiled is:

  Expected perf = min(2.0 * 320, 8100) = min(640, 8100) = 640 GFLOP/s

However, our measured results told a different story:

  Naive : 384.80 GFLOP/s  (5.5808 ms)
  Tiled : 319.74 GFLOP/s  (6.7163 ms)

The tiled kernel was actually 17% slower than naive. Nsight Compute
revealed the root cause — SM utilization dropped from 62.48% (naive)
to 55.19% (tiled), while DRAM utilization also dropped from 7.23% to
5.94%. Both metrics going down simultaneously points to one culprit:
low thread occupancy.

With a tile size of T=8, each thread block contains only 8×8 = 64 threads.
The T4 GPU is designed to run 1024 threads per SM simultaneously to hide
memory latency through warp switching — when one warp stalls waiting for
data, another warp executes. With only 64 threads per block, there are not
enough warps in flight for the GPU to effectively hide latency. The SMs
spend significant time stalled, waiting for shared memory loads and
__syncthreads() barriers to complete, rather than doing useful computation.

Additionally, the __syncthreads() barrier required after every tile load
introduces synchronization overhead that compounds the occupancy problem.
With only 2 warps per block (64 threads / 32 threads per warp), the
scheduler has almost no flexibility.

The fix is straightforward: increasing tile size to T=16 (256 threads/block)
or T=32 (1024 threads/block) would dramatically improve occupancy, give
the warp scheduler more flexibility, and push both DRAM and SM utilization
toward their respective peaks — moving the tiled kernel rightward and
upward on the roofline toward the compute-bound ridge at 25.31 FLOP/byte.
