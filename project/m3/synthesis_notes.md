# Synthesis Notes — KWS Accelerator Chiplet
**Venkata Krishna Kumar Vedantam | ECE 510 Spring 2026**
**Design: top.sv | Tool: OpenLane 2.3.10 | PDK: SKY130 130nm**
**Parameters: C_IN=64, C_OUT=64, K=3, L=500, N_IN_BYTES=4000**

## Overview

This document describes the complete synthesis attempt for the KWS
hardware accelerator chiplet targeting the SkyWater 130nm open-source
PDK using OpenLane 2.3.10. The design integrates a Binary Conv2
XOR+popcount compute core (compute_core.sv) with a SPI slave interface
(interface.sv) through a glue FSM in top.sv. The dominant kernel from
M1 profiling — C_IN=64, C_OUT=64, K=3, L=500 — is used throughout.

## What Was Attempted

### Attempt 1 — Full Design N_IN_BYTES=4000

The first synthesis attempt used the full design with N_IN_BYTES=4000,
matching the M1 dominant kernel exactly (500 positions × 8 bytes = 4000
bytes). OpenLane 2.3.10 was run via Docker on an Apple M4 Mac using the
ghcr.io/efabless/openlane2:2.3.10 image.

**Error encountered:** OpenLane was killed by SIGKILL (OOM) at Stage 6
(Yosys Synthesis) after running for approximately 9 minutes.

**Root cause:** The SPI slave interface (interface.sv) declares rx_data
as a flat 32,000-bit register (`reg [31999:0] rx_data`). The SKY130
standard cell library (`sky130_fd_sc_hd`) contains no BRAM or on-chip
SRAM primitives in its synthesis library. Yosys therefore maps all
32,000 bits to individual flip-flops (32,000 DFF cells). During the ABC
technology mapping pass, optimizing 32,000+ cells simultaneously
exhausted the available RAM (7.57 GB Docker limit on Mac). This is a
fundamental constraint of the SKY130 standard cell flow — SRAM requires
separately instantiated OpenRAM macros, not standard cell synthesis.

**Specific error:**
```
[ERROR] The flow has encountered an unexpected error:
        Synthesis: Interrupted (SIGKILL)
```

In the N_IN_BYTES=64 attempt, post-CTS timing repair reported:
```
[WARNING] [RSZ-0062] Unable to repair all setup violations.
```
After 1,276 iterations, worst negative slack remained at -20.56 ns.
The timing repair converged but could not close timing because the
fundamental critical path of 43 ns exceeds the 10 ns clock budget.

### Attempt 2 — Scope Adjustment N_IN_BYTES=64

To obtain real synthesis results for the compute core — which is the
novel contribution of this project — N_IN_BYTES was reduced from 4000
to 64 (8 positions × 8 bytes) for synthesis only. The compute_core.sv
parameters remain unchanged at C_IN=64, K=3, L=500. The XOR+popcount
adder tree, FSM logic, and weight memory are identical to the full
design. Only the SPI input buffer size was reduced.

**Verilator lint:** Passed with 3 warnings (unused parameters L,
BYTES_PER_POS, C_OUT — all correctly unused in RTL). No errors.

**Yosys synthesis (Stage 6):** Completed successfully.

```
Total cells:    160,471
Flip-flops:      45,119 (dfxtp_2: 43,149 + dfrtp_2: 1,966 + dfstp_2: 4)
Logic gates:    115,352
Chip area:    2,196,806.912 µm² (pre-PnR Yosys estimate)
Sequential:      44.13% of area (969,558 µm²)
Combinational:   55.87% of area
```

**Pre-PnR Static Timing Analysis (Stage 12):** Completed.

```
Worst negative slack (setup): -33.14 ns
Total negative slack:         -194.3 ns
Endpoints with violations:    34
Critical path delay:          43.14 ns
Clock period:                 10.00 ns
```

**Placement (Stages 13-33):** Completed after adjusting die area to
5000×5000 µm and PL_TARGET_DENSITY_PCT=15 to accommodate 160K cells
with high-fanout nets.

**Clock Tree Synthesis (Stage 34):** Completed.

**Post-CTS Timing Repair (Stage 36):** Running — WNS improved from
-27.95 ns to -20.56 ns after 1,276 iterations. Unable to close timing
due to the fundamental 43 ns critical path through the adder tree.

**Routing:** Not reached — timing repair did not converge.

## What The Numbers Mean

### Area

The 2,196,806 µm² chip area breaks down as follows:

- **act_buf (500 × 64 bits):** 32,000 FFs × ~15 µm² = ~480,000 µm² (21.8%)
- **wt_mem (64 OC × 192 bits):** 12,288 FFs × ~15 µm² = ~184,320 µm² (8.4%)
- **XOR+popcount logic:** ~44,726 MUX2 + ~50,890 AND/OR gates = majority
  of remaining area
- **FSM + output logic:** ~1,000 cells

The weight memory (1,536 bytes, 1-bit packed) correctly matches the M1
calculation. The activation buffer dominates area consumption.

### Timing — Critical Path

The critical path runs from partial sum register `_275662_` through a
single `sky130_fd_sc_hd__inv_2` gate with fanout 1,696, taking 28.22 ns
on that one gate alone. This fanout is caused by the act_buf driving
1,696 downstream XOR gates simultaneously. The full path through the
Brent-Kung adder tree totals 43.14 ns, giving a setup slack of -33.14 ns
at 100 MHz.

### Power

Pre-PnR power estimate at nominal corner (tt_025C_1v80):
```
Sequential:    191.9 mW (67.1%)
Combinational:  94.3 mW (33.0%)
Total:         286.1 mW
```

Note: Pre-PnR power estimates are typically 2-3× higher than post-route
estimates due to absence of actual wire capacitances. Post-route power
for this design would likely be in the 100-150 mW range.

## What I Changed

1. Removed `/*verilator*/` comments from all RTL files — OpenLane
   Verilator treated these as unknown pragmas and failed.

2. Fixed `BLKANDNBLK` errors — moved array reset loops from `always`
   blocks to `initial` blocks, separating blocking and non-blocking
   assignments.

3. Changed flat port declarations — Yosys Verilog-2005 frontend does not
   support unpacked array ports. Changed `rx_data [7:0] rx_data [0:N-1]`
   to flat `rx_data [N*8-1:0]` throughout.

4. Fixed width truncation — changed `$signed(9'd192) - $signed(...)` to
   `9'($signed(10'd192) - $signed(...))` to explicitly truncate the
   10-bit subtraction result to 9 bits.

5. Adjusted die area and density — multiple iterations from 800×800 µm
   to 3000×3000 µm to 5000×5000 µm to accommodate 160K cells.

6. Reduced N_IN_BYTES from 4000 to 64 — to avoid OOM in Yosys caused by
   32,000-FF flat register with no BRAM available in SKY130 standard
   cells.

## Revised Scope and M4 Fix

The synthesis failure has a clear technical root cause and a known
engineering solution:

**Root cause:** SKY130 standard cell library has no BRAM. The 4000-byte
SPI input buffer requires OpenRAM SRAM macros — a separate flow
requiring `EXTRA_LEFS` and `EXTRA_GDS_FILES` configuration, not standard
cell synthesis.

**M4 fix:** Replace act_buf (32,000 FFs) with 4× `sky130_sram_1kbyte_1rw1r_32x256_8`
OpenRAM macros (4 × 8,192 bits = 32,768 bits). Pipeline the XOR+popcount
adder tree across 4 stages (~10 ns each) to fix the 43 ns critical path.
Lower clock target to 40 MHz (25 ns period) matching OpenSpike SNN
accelerator (published, taped out on SKY130). This has been demonstrated
to work by others on SKY130 with similar adder tree designs.

The compute core (C_IN=64, K=3, L=500) is architecturally correct and
verified by simulation against golden.py (independent Python reference,
seed=42). The synthesis numbers — 160K cells, 2.19M µm² area, 43 ns
critical path through the adder tree — are real and informative.
