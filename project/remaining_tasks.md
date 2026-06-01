# Remaining Tasks Before M4
**ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam**
**File: project/remaining_tasks.md**

---

The following three tasks are the highest-priority changes required before M4
submission. Each names the specific file, signal, or component and the exact
change required.

---

## Task 1 — Replace act_buf flip-flops with OpenRAM SRAM macros

**File:** `project/m4/rtl/compute_core.sv`

**Current:** `reg [63:0] act_buf [0:499]` declares 500 × 64 = 32,000
flip-flops for the activation buffer. This caused SIGKILL OOM in Yosys
synthesis (Attempt 1, N_IN_BYTES=4000) because SKY130 standard cell library
has no BRAM primitive, mapping all 32,000 bits to individual DFFs.

**Change:** Replace with 4× `sky130_sram_1kbyte_1rw1r_32x256_8` OpenRAM
macros (4 × 8,192 bits = 32,768 bits total). Add `EXTRA_LEFS` and
`EXTRA_GDS_FILES` entries in `config.json` pointing to the OpenRAM macro
LEF and GDS files. Update `compute_core.sv` to use the SRAM read/write
interface (address, data_in, data_out, wen, ren ports) replacing the
direct array indexing.

**Expected effect:** Eliminates 32,000 FFs from synthesis, reduces
sequential area from 969,558 µm² by approximately 50%, allows routing
to complete, and removes the primary cause of timing failure.

---

## Task 2 — Pipeline the XOR+popcount adder tree across 4 stages

**File:** `project/m4/rtl/compute_core.sv`

**Current:** The `gen_ic` generate block computes the full XOR+popcount
reduction tree combinationally in one clock cycle. This creates the
50.75 ns critical path through `_115353_` (inv_2, fanout 1,696) that
limits the design to 19.7 MHz and causes WNS = -41.09 ns.

**Change:** Split the adder tree into 4 pipeline stages with registered
intermediate sums between each stage:
- Stage 1: 192 XOR results → 96 partial sums (register boundary)
- Stage 2: 96 → 48 partial sums (register boundary)
- Stage 3: 48 → 24 partial sums (register boundary)
- Stage 4: 24 → final popcount result

Update the FSM in `top.sv` to account for 4-cycle pipeline latency before
reading `result_buf`. Update `golden.py` to match the 4-cycle output delay.
Lower `CLOCK_PERIOD` in `config.json` from 10.0 to 10.0 ns (100 MHz) and
verify timing closure.

**Expected effect:** Breaks 50.75 ns path into four ~12 ns stages,
closing timing at 100 MHz and improving projected throughput from
67.9 samples/sec to approximately 345 samples/sec.

---

## Task 3 — Replace SPI interface with AXI4-Stream interface

**File:** `project/m4/rtl/interface.sv`, `project/m4/rtl/top.sv`

**Current:** `interface.sv` implements SPI Mode 0 slave with N_IN_BYTES=4000.
At 19.7 MHz system clock with 8 system clocks per SPI bit, effective input
bandwidth is 0.308 MB/s. Loading 4,000 bytes takes 256,000 system clock
cycles — 88% of total inference cycles (290,180 total). SPI is the dominant
bottleneck for measured throughput.

**Change:** Replace the SPI slave with an AXI4-Stream slave interface
(s_axis_tdata 32-bit wide, s_axis_tvalid, s_axis_tready, s_axis_tlast).
At 100 MHz with 32-bit bus width, effective bandwidth = 100 MHz × 4 bytes
= 400 MB/s — a 1,300× improvement over SPI. Update `top.sv` G_LOAD state
to accept streaming data rather than SPI byte-by-byte loading. Update
`tb_top.sv` to drive AXI4-Stream instead of SPI signals.

**Expected effect:** Reduces data loading from 256,000 cycles to
1,000 cycles (4,000 bytes / 4 bytes per cycle), making compute the
dominant phase and enabling the projected 400 GFLOP/s target.

