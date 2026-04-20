# Matrix Multiplication DRAM Traffic Analysis
**N = 32, FP32 (4 bytes/element), Tile size T = 8  DRAM Bandwidth = 320 GB/s, 
Compute = 10 TFLOPS
**

---

## 1. Naive Matrix Multiplication (ijk order)

### Element Accesses

| Matrix | Access Count | Reason |
|--------|-------------|--------|
| A | N³ = 32³ = 32,768 | Each A[i][k] accessed N times (once per j) |
| B | N³ = 32³ = 32,768 | Each B[k][j] accessed N times (once per i) |
| C (writes) | N² = 1,024 | Each output element written once |

### DRAM Traffic

| Matrix | Bytes |
|--------|-------|
| A | 32,768 × 4 = 131,072 bytes |
| B | 32,768 × 4 = 131,072 bytes |
| C | 1,024 × 4 = 4,096 bytes |
| **Total T_naive** | **266,240 bytes ≈ 260 KB** |

> Every access assumed to hit DRAM (no cache reuse).

---

## 2. Tiled Matrix Multiplication (T = 8)

### Tile Dimensions

- Tiles per dimension: N/T = 32/8 = 4
- Output tiles: (N/T)² = 16
- K-steps per output tile: N/T = 4
- **Total tile loads per matrix = 16 × 4 = 64 tiles**
- Elements per tile: T² = 64
- Bytes per tile: 64 × 4 = 256 bytes

### DRAM Traffic

| Matrix | Bytes |
|--------|-------|
| A | 64 × 256 = 16,384 bytes |
| B | 64 × 256 = 16,384 bytes |
| C (writes) | 1,024 × 4 = 4,096 bytes |
| **Total T_tiled** | **36,864 bytes ≈ 36 KB** |

##  Ideal Case — Perfect On-Chip Reuse (Lower Bound)

With sufficient shared memory, each element of A, B, C is loaded/stored exactly once:

| Matrix | Bytes |
|--------|-------|
| A | N² × 4 = 1,024 × 4 = 4,096 bytes |
| B | N² × 4 = 1,024 × 4 = 4,096 bytes |
| C (writes) | N² × 4 = 1,024 × 4 = 4,096 bytes |
| **Total T_ideal** | **12,288 bytes = 12 KB** |

$$T\_{\text{ideal}} = 3N^2 \times 4 = 3 \times 1{,}024 \times 4 = 12{,}288 \text{ bytes}$$

> This is the **theoretical minimum DRAM traffic** — no element is ever fetched twice.
> Real tiled implementations (e.g. CUDA shared memory) approach this as tile size T → N.

---

## 3. Traffic Reduction Ratio

$$\text{Ratio} = \frac{T\_{\text{naive}}}{T\_{\text{tiled}}} = \frac{266{,}240}{36{,}864} \approx 7.22 \approx T = 8$$

**Why the ratio equals T:**
Tiling allows each loaded tile element to be reused T times within the tile computation before eviction, reducing DRAM fetches by a factor of T compared to the naive case where every access goes to DRAM.

---

## 4. Performance Analysis

### Total FLOPs

$$\text{Work} = 2N^3 = 2 \times 32^3 = 65{,}536 \text{ FLOPs}$$

### Ridge Point (Roofline Model)

$$I_{\text{ridge}} = \frac{\text{Compute}}{\text{Bandwidth}} = \frac{10 \times 10^{12}}{320 \times 10^9} = 31.25 \text{ FLOPs/byte}$$

### Arithmetic Intensity

| Case | FLOPs/byte |
|------|-----------|
| Naive | 65,536 / 266,240 ≈ **0.246** |
| Tiled | 65,536 / 36,864 ≈ **1.778** |

Both are far below the ridge point of 31.25 → **both are memory-bound**.

### Execution Time

| | Formula | Time |
|--|---------|------|
| **Compute time** | 65,536 / (10 × 10¹²) | **6.55 × 10⁻⁹ s (6.55 ns)** |
| **T_mem naive** | 266,240 / (320 × 10⁹) | **8.32 × 10⁻⁷ s (832 ns)** |
| **T_mem tiled** | 36,864 / (320 × 10⁹) | **1.15 × 10⁻⁷ s (115 ns)** |

### Final Bottleneck Summary

| Case | Execution Time | Bottleneck |
|------|---------------|------------|
| Naive | **832 ns** | 🔴 Memory-bound (832 ns ≫ 6.55 ns) |
| Tiled | **115 ns** | 🔴 Memory-bound (115 ns ≫ 6.55 ns) |

> Tiling gives **~7.2× speedup** purely from reduced DRAM traffic.  
> Even after tiling, N=32 is too small to overcome memory bottleneck at these compute/bandwidth ratios.
