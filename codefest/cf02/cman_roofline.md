## 1 — Hardware roofline parameters
     Given: peak compute = 10 TFLOPS = 10,000 GFLOP/s, peak DRAM bandwidth = 320 GB/s.
     Ridge point = 10,000 / 320 = 31.25 FLOP/byte.
     Any kernel with arithmetic intensity above 31.25 is compute-bound; below it is memory-bound.

## 2 — Kernel A: Dense GEMM (1024×1024 FP32)

FLOPs: For an N×N square matmul, FLOPs = 2N³ = 2 × 1024³ = 2 × 1,073,741,824 = 2,147,483,648 ≈ 2.147 GFLOP
Bytes transferred (no cache reuse, all three matrices from DRAM):

Matrix A: 1024 × 1024 × 4 bytes = 4,194,304 bytes
Matrix B: 1024 × 1024 × 4 bytes = 4,194,304 bytes
Matrix C (store): 1024 × 1024 × 4 bytes = 4,194,304 bytes
Total = 3 × 4,194,304 = 12,582,912 bytes ≈ 12.58 MB

Arithmetic intensity = 2,147,483,648 / 12,582,912 = 170.67 FLOP/byte
## 170.67 >> 31.25 ridge point → compute-bound
Attainable performance = min(peak compute, AI × bandwidth) = min(10,000, 170.67 × 320) = min(10,000, 54,614) = 10,000 GFLOP/s (hits the compute ceiling)

## 3 — Kernel B: Vector addition (N = 4,194,304 FP32)
FLOPs: One addition per element = 4,194,304 ≈ 0.004 GFLOP
Bytes transferred:

Vector A: 4,194,304 × 4 = 16,777,216 bytes
Vector B: 4,194,304 × 4 = 16,777,216 bytes
Vector C (store): 4,194,304 × 4 = 16,777,216 bytes
Total = 50,331,648 bytes ≈ 50.33 MB

Arithmetic intensity = 4,194,304 / 50,331,648 = 0.0833 FLOP/byte
## 0.0833 << 31.25 ridge point → memory-bound
Attainable performance = AI × bandwidth = 0.0833 × 320 = 26.67 GFLOP/s (nowhere near compute ceiling)


## Roofline Model

<img width="752" height="454" alt="Screenshot 2026-04-12 at 11 48 10 PM" src="https://github.com/user-attachments/assets/0979513a-e8e5-4e42-9049-002e876f86e3" />

## 4
## Kernel A — Dense GEMM:
(a) Compute-bound. AI = 170.67 FLOP/byte is 5.5× above the ridge point of 31.25. The hardware runs out of compute before it runs out of memory bandwidth.

(b) Attainable ceiling = 10,000 GFLOP/s (the full peak compute). You hit the flat roof.

(c) Best architectural improvement: increase compute throughput, not memory bandwidth. Options: use INT8 instead of FP32 (4× more ops per clock on the same silicon), widen the MAC array (more parallel multipliers), or increase clock frequency. Adding DRAM bandwidth is wasted here — you're not bottlenecked by it.

## Kernel B — Vector addition:
(a) Memory-bound. AI = 0.083 FLOP/byte is 375× below the ridge point. For every byte fetched from DRAM, you do essentially zero arithmetic. The hardware spends almost all its time waiting for data.

(b) Attainable ceiling = 0.083 × 320 = 26.67 GFLOP/s — only 0.27% of peak compute is reachable. The compute units are idle nearly the entire time.

(c) Best architectural improvement: raise arithmetic intensity, not raw compute. The two ways to do this are: (1) operator fusion — instead of writing C = A + B to DRAM and then reading it back for the next operation, fuse the addition with whatever comes next so each element is touched only once; (2) larger DRAM bandwidth (e.g. HBM3 instead of GDDR6) — since you're bandwidth-limited, more bandwidth directly raises attainable performance. Adding more MAC units does nothing.





