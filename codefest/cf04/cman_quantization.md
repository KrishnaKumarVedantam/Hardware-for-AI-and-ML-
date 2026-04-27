# CMAN — Manual INT8 Symmetric Quantization
## ECE 410/510 — Codefest 4
## Author: Venkata Krishna Kumar Vedantam

---

## Weight Matrix W (FP32)

```
W = [  0.85, -1.20,  0.34,  2.10 ]
    [ -0.07,  0.91, -1.88,  0.12 ]
    [  1.55,  0.03, -0.44, -2.31 ]
    [ -0.18,  1.03,  0.77,  0.55 ]
```

---

## Task 1: Scale Factor

```
max|W| = 2.31  (element W[2][3] = -2.31)
S = max(|W|) / 127 = 2.31 / 127 = 0.018189
```

---

## Task 2: Quantize — W_q = round(W / S), clamped to [-128, 127]

W / S (before rounding):
```
[  46.73,  -65.97,   18.69,  115.45 ]
[  -3.85,   50.03, -103.36,    6.60 ]
[  85.22,    1.65,  -24.19, -127.00 ]
[  -9.90,   56.63,   42.33,   30.24 ]
```
No clamping required — all values within [-128, 127].

W_q (INT8):
```
[  47,  -66,   19,  115 ]
[  -4,   50, -103,    7 ]
[  85,    2,  -24, -127 ]
[ -10,   57,   42,   30 ]
```

---

## Task 3: Dequantize — W_deq = W_q x S

```
W_deq:
[  0.8549, -1.2005,  0.3456,  2.0917 ]
[ -0.0728,  0.9094, -1.8735,  0.1273 ]
[  1.5461,  0.0364, -0.4365, -2.3100 ]
[ -0.1819,  1.0368,  0.7639,  0.5457 ]
```

---

## Task 4: Error Analysis

Per-element absolute error |W - W_deq|:
```
[ 0.0049, 0.0005, 0.0056, 0.0083 ]
[ 0.0028, 0.0006, 0.0065, 0.0073 ]
[ 0.0039, 0.0064, 0.0035, 0.0000 ]
[ 0.0019, 0.0068, 0.0061, 0.0043 ]
```

- **Largest error:** W[0][3] = 2.10, error = 0.008268
- **MAE** = 0.069213 / 16 = **0.004326**

---

## Task 5: Bad Scale Experiment (S_bad = 0.01)

W / S_bad (before rounding):
```
[  85.0, -120.0,   34.0,  210.0* ]
[  -7.0,   91.0, -188.0*,  12.0  ]
[ 155.0*,   3.0,  -44.0, -231.0* ]
[ -18.0,  103.0,   77.0,   55.0  ]
```
\* = clamped to INT8 range [-128, 127]

W_q_bad (INT8, after clamping):
```
[  85, -120,   34,  127 ]
[  -7,   91, -128,   12 ]
[ 127,    3,  -44, -128 ]
[ -18,  103,   77,   55 ]
```

W_deq_bad = W_q_bad x 0.01:
```
[  0.85, -1.20,  0.34,  1.27 ]
[ -0.07,  0.91, -1.28,  0.12 ]
[  1.27,  0.03, -0.44, -1.28 ]
[ -0.18,  1.03,  0.77,  0.55 ]
```

Per-element absolute error |W - W_deq_bad|:
```
[ 0.00, 0.00, 0.00, 0.83 ]
[ 0.00, 0.00, 0.60, 0.00 ]
[ 0.28, 0.00, 0.00, 1.03 ]
[ 0.00, 0.00, 0.00, 0.00 ]
```

- **MAE_bad** = 2.74 / 16 = **0.1713**
- MAE increased from 0.004326 to 0.1713 — approximately **40x worse**

**One-sentence explanation:**
When S is too small, large-magnitude values in W exceed the INT8 range
after division and get clamped to +-127/128, permanently losing that
information and producing large dequantization errors in the output.
