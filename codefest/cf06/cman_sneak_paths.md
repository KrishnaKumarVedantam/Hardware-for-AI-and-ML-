# CMAN — Sneak Paths in a Resistive Crossbar

**Circuit:** 2×2 crossbar, rows = voltage inputs, columns = current outputs.

| Cell | Resistance | State |
|------|-----------|-------|
| R[0][0] | 1 kΩ | ON  |
| R[0][1] | 2 kΩ | OFF |
| R[1][0] | 2 kΩ | OFF |
| R[1][1] | 1 kΩ | ON  |

---

## Task 1 — Ideal Read

**Conditions:** V_row0 = 1 V, col 0 clamped to 0 V (virtual ground), row 1 = 0 V, col 1 = 0 V.

With every node except row 0 pinned to ground, the circuit reduces to a single resistor between 1 V and 0 V:

```
I_col0 = V_row0 / R[0][0] = 1 V / 1 kΩ = 1.0 mA
```

> **I_col0 (ideal) = 1.0 mA**

---

## Task 2 — Sneak Path Read

**Conditions:** V_row0 = 1 V, col 0 = 0 V, **row 1 and col 1 are floating.**

Because row 1 and col 1 are undriven, they settle at some intermediate voltage determined by the resistor network. Call these unknowns **V_r** (= V_row1) and **V_c** (= V_col1).

### Setting up KCL

The rule: all currents *into* a floating node must equal all currents *out* of it (no current can pile up at a floating node).

**KCL at V_col1:**

Current arriving from row 0 through R[0][1] must equal current leaving toward row 1 through R[1][1]:

```
(1 - V_c) / 2k  =  (V_c - V_r) / 1k
```

Multiply both sides by 2k:

```
1 - V_c  =  2(V_c - V_r)
1 - V_c  =  2·V_c - 2·V_r
2·V_r    =  3·V_c - 1          ... (eq. A)
```

**KCL at V_row1:**

Current arriving from col 1 through R[1][1] must equal current leaving to col 0 through R[1][0]:

```
(V_c - V_r) / 1k  =  (V_r - 0) / 2k
```

Multiply both sides by 2k:

```
2(V_c - V_r)  =  V_r
2·V_c - 2·V_r =  V_r
2·V_c         =  3·V_r
V_r           =  (2/3)·V_c     ... (eq. B)
```

### Solving

Substitute (B) into (A):

```
2·(2/3)·V_c  =  3·V_c - 1
(4/3)·V_c    =  3·V_c - 1
1            =  3·V_c - (4/3)·V_c
1            =  (5/3)·V_c
V_c          =  3/5 = 0.6 V
V_r          =  (2/3) × 0.6 = 0.4 V
```

> **V_col1 = 0.6 V, V_row1 = 0.4 V**

### Computing I_col0

Two independent current streams flow into col 0 (held at 0 V):

| Path | From → To | Calculation | Current |
|------|-----------|-------------|---------|
| Direct | row 0 → R[0][0] → col 0 | (1 − 0) / 1 kΩ | 1.0 mA |
| Sneak  | row 1 → R[1][0] → col 0 | (0.4 − 0) / 2 kΩ | 0.2 mA |
| **Total** | | | **1.2 mA** |

> **I_col0 (actual) = 1.2 mA — 20% error over the ideal 1.0 mA**

The sneak path: `row 0 → R[0][1] → V_col1 → R[1][1] → V_row1 → R[1][0] → col 0`

---

## Task 3 — Why Sneak Paths Corrupt MVM

When row 1 and col 1 are left floating, the four resistors form a closed loop that acts as an unintended voltage divider. Part of the current sourced by row 0 takes the long way around — through the two OFF-state cells — and still ends up in col 0, even though it carries no information about R[0][0].

From the crossbar's perspective, col 0 cannot distinguish between current that flowed through the intended weight and current that leaked through neighboring cells. The sensed dot product is therefore wrong.

This gets significantly worse as arrays scale up: in an N×N crossbar, each unselected row and column adds more parallel sneak paths, and the cumulative leakage grows roughly with N. Without countermeasures — such as per-cell selector transistors (1T1R), active clamping of unselected rows and columns, or post-readout digital correction — the analog MVM accuracy degrades to the point where the array is unusable for neural network inference at even moderate sizes.
