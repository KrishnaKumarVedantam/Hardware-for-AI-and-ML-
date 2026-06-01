# Remaining Tasks Before M4
**ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam**
**File: project/remaining_tasks.md**

---

The following three tasks are the highest-priority changes required before M4
submission, derived directly from the documented M4 fix plan in
`project/m3/synthesis_notes.md`. Each names the specific file, signal, or
component and the exact change required.

---

## Task 1 — Replace act_buf flip-flops with OpenRAM SRAM macros

**File:** `project/m4/rtl/compute_core.sv` and `project/m4/synth/config.json`

**Current:** `reg [63:0] act_buf [0:499]` in `compute_core.sv` declares
500 × 64 = 32,000 flip-flops for the activation buffer. SKY130 standard cell
library has no BRAM primitive, so Yosys maps all 32,000 bits to individual DFFs.
This caused SIGKILL OOM at Stage 6 (Yosys) when N_IN_BYTES=4000, forcing the
scope adjustment to N_IN_BYTES=64 in M3.

**Change:** Replace `act_buf` with 4×
`sky130_sram_1kbyte_1rw1r_32x256_8` OpenRAM macros (4 × 8,192 bits =
32,768 bits total). Add `EXTRA_LEFS` and `EXTRA_GDS_FILES` entries in
`config.json` pointing to the OpenRAM macro LEF and GDS files. Update
`compute_core.sv` to use the SRAM read/write interface (address, data_in,
data_out, wen, ren ports) replacing direct array indexing of `act_buf`.
Restore N_IN_BYTES=4000 in `interface.sv` and `top.sv` since the OOM cause
is eliminated.

**Expected effect:** Eliminates 32,000 FFs, reduces sequential area from
969,558 µm² by approximately 50%, allows Yosys to complete synthesis with
N_IN_BYTES=4000, and enables routing to proceed past Stage 6.

---

## Task 2 — Pipeline the XOR+popcount adder tree across 4 stages

**File:** `project/m4/rtl/compute_core.sv` and `project/m4/rtl/top.sv`

**Current:** The `gen_ic` generate block in `compute_core.sv` computes the
full XOR+popcount reduction tree combinationally in one clock cycle. This
creates the 50.750618 ns critical path through `_115353_` (inv_2, fanout
1,696) identified in `timing_report.txt`, giving WNS = -41.09 ns and
limiting the design to 19.7 MHz.

**Change:** Split the adder tree into 4 pipeline stages with registered
intermediate sums between each stage, each stage targeting ~10 ns:
- Stage 1: 192 XOR results → 96 partial sums (register boundary)
- Stage 2: 96 → 48 partial sums (register boundary)
- Stage 3: 48 → 24 partial sums (register boundary)
- Stage 4: 24 → final popcount result

Update the FSM in `top.sv` to account for the 4-cycle pipeline latency
before reading `result_buf`. Update `golden.py` to match the 4-cycle
output delay.

**Expected effect:** Breaks the 50.75 ns combinational path into four
~10 ns stages, closing timing at 40 MHz (25 ns clock period) as
demonstrated by OpenSpike SNN accelerator published on SKY130.

---

## Task 3 — Lower clock target to 40 MHz and re-run full OpenLane synthesis

**File:** `project/m4/synth/config.json`

**Current:** `config.json` sets `CLOCK_PERIOD: 10.0` (100 MHz target).
The design cannot close timing at 100 MHz — worst negative slack is
-41.09 ns from `timing_report.txt`. Post-CTS timing repair ran 1,276
iterations and failed to converge. Routing was never reached.

**Change:** Change `CLOCK_PERIOD` in `config.json` from `10.0` to
`25.0` (40 MHz, matching OpenSpike SNN accelerator tapeout on SKY130).
Re-run full OpenLane 2.3.10 flow with both fixes from Task 1 and Task 2
applied, with N_IN_BYTES=4000 restored, targeting a complete run through
routing and GDSII generation.

**Expected effect:** At 40 MHz with a pipelined adder tree (~10 ns per
stage) and OpenRAM SRAM replacing the high-fanout FF array, timing
should close. Successful routing would produce `area_report.txt`,
`timing_report.txt`, and `power_report.txt` from post-PnR — replacing
the current pre-PnR estimates — and convert the M3 projected numbers
to measured values.

