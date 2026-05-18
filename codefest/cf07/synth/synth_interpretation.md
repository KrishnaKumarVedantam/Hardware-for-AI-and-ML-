# Synthesis Interpretation — crossbar_mac (CF06 fallback)
**ECE 410/510 — Codefest 7 | OpenLane v2.3.10 | Sky130 HD | Run: RUN_2026-05-18_05-19-39**

## (a) Clock Period and Worst-Case Slack

Target clock period: 10.0 ns (100 MHz). In the nominal corner
(nom_tt_025C_1v80), worst-case setup slack is +5.195 ns — the critical
path completes in ~4.8 ns, well within budget. In the tightest corner
(nom_ss_100C_1v60), setup slack tightens to +0.103 ns, still meeting
timing. Worst-case hold slack is +0.192 ns. Zero setup violations, zero
hold violations across all corners. The design meets timing comfortably
at 100 MHz.

## (b) Critical Path

Source register: _1655_ (`sky130_fd_sc_hd__dfxtp_2`, `r_in0[0]`).
Sink register: _1654_ (`sky130_fd_sc_hd__dfxtp_2`).
Data arrival: 2.839 ns. Required: 10.496 ns. Slack: +7.657 ns.
Dominant cells: `nor4_2` (weight sign logic) → `a31oi_2` (partial sum)
→ `xnor2_2` × 4 (adder carry chain) → `a211o_2`, `a221o_2` (sum tree).
The path runs through the combinational adder tree accumulating four
weighted inputs per output column — the expected bottleneck for a
binary-weight MAC.

## (c) Cell Area and Top Contributors

Total standard cell area: 9,008.64 µm², 1,291 instances.
Die: 24,598.3 µm². Core utilization: 46.3%.
Top three by instance count:

1. 780 multi-input combinational cells — MAC adder tree
2. 115 timing repair buffers — inserted by OpenLane for fanout/slew
3. 89 sequential cells — weight reg (16 FF), input reg (32 FF), output reg (44 FF)

## (d) Warnings and Violations

441 lint warnings — Yosys flagging unused bits in the 1-bit weight array.
No functional impact. 6 max fanout violations — high-fanout weight nets
driving multiple MAC cells; non-critical at 100 MHz. 3 max slew violations
(ss corner only) — marginal drive strength at extreme
process/voltage/temperature; no fix needed for this target. No SDC file —
generic fallback used; a proper SDC should be written for M3.
DRC: 0, LVS: 0, Antenna: 0 — layout is clean.
