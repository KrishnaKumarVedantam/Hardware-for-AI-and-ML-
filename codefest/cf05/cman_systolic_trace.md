# CMAN — Systolic Array Trace (Weight-Stationary)

**Given:** `A = [[1,2],[3,4]]`, `B = [[5,6],[7,8]]`, expected `C = A×B = [[19,22],[43,50]]`

---

## Task 1 — PE Diagram with Preloaded Weights

```
  col-0 of A (no stagger)      col-1 of A (1-cycle stagger)
        |                              |
        v                              v
  +-----------+              +-----------+
  |  PE[0][0] |  psum ─────> |  PE[0][1] |   Row 0
  |  weight=5 |              |  weight=6 |
  +-----------+              +-----------+
        | psum ↓                    | psum ↓
  +-----------+              +-----------+
  |  PE[1][0] |  psum ─────> |  PE[1][1] |   Row 1
  |  weight=7 |              |  weight=8 |
  +-----------+              +-----------+
        ↓                           ↓
     C[*][0]                     C[*][1]
```

| PE | Preloaded Weight |
|----|-----------------|
| PE[0][0] | B[0][0] = 5 |
| PE[0][1] | B[0][1] = 6 |
| PE[1][0] | B[1][0] = 7 |
| PE[1][1] | B[1][1] = 8 |

---

## Task 2 — Cycle-by-Cycle Trace

> Total cycles = 3N − 2 = **4** for N = 2

| Cycle | Input row-0 | Input row-1 | PE[0][0] psum | PE[0][1] psum | PE[1][0] psum | PE[1][1] psum | C output |
|-------|-------------|-------------|---------------|---------------|---------------|---------------|----------|
| 1 | A[0][0] = 1 | — | 0 + 1×5 = **5** | 0 + 1×6 = **6** | 0 | 0 | — |
| 2 | A[1][0] = 3 | A[0][1] = 2 | 0 + 3×5 = **15** | 0 + 3×6 = **18** | 5 + 2×7 = **19** | 6 + 2×8 = **22** | C[0][0]=19, C[0][1]=22 |
| 3 | — | A[1][1] = 4 | reset → 0 | reset → 0 | 15 + 4×7 = **43** | 18 + 4×8 = **50** | C[1][0]=43, C[1][1]=50 |
| 4 | — | — | drain | drain | drain | drain | all outputs valid |

**Verification:**

| Output | Computation | Result |
|--------|-------------|--------|
| C[0][0] | 1×5 + 2×7 = 5 + 14 | **19** ✓ |
| C[0][1] | 1×6 + 2×8 = 6 + 16 | **22** ✓ |
| C[1][0] | 3×5 + 4×7 = 15 + 28 | **43** ✓ |
| C[1][1] | 3×6 + 4×8 = 18 + 32 | **50** ✓ |

---

## Task 3 — Counts

### (a) Total MAC Operations

| Cycle | Active PEs | MACs |
|-------|-----------|------|
| 1 | PE[0][0], PE[0][1] | 2 |
| 2 | all 4 PEs | 4 |
| 3 | PE[1][0], PE[1][1] | 2 |
| **Total** | | **8 = N³ = 2³** |

### (b) Input Reuse

- Each **A** value passes through N = 2 PEs → reused **2 times**
- Each **B** weight is multiplied by N = 2 different A values → reused **2 times**

### (c) Off-Chip Memory Accesses

| Operand | Elements | Access type | Accesses |
|---------|----------|-------------|----------|
| A | 4 | 1 read each | 4 |
| B | 4 | 1 pre-load each | 4 |
| C | 4 | 1 write each | 4 |
| **Total** | | | **12** |

No element is fetched from off-chip memory more than once.

---

## Task 4 — Output-Stationary Comparison

In output-stationary dataflow, each PE holds one **partial sum of C** fixed throughout the computation, while both A activations and B weights stream in from memory every cycle.
