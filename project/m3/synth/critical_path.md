# Critical Path Analysis — KWS Accelerator Chiplet
**Venkata Krishna Kumar Vedantam | ECE 510 Spring 2026**
**Design: top.sv | Tool: OpenLane 2.3.10 | PDK: SKY130 130nm**

## Critical Path Summary

The critical path runs from flip-flop `_275662_` (rising edge-triggered,
`sky130_fd_sc_hd__dfrtp_2`) through the XOR+popcount adder tree to
flip-flop `_231557_` (rising edge-triggered, `sky130_fd_sc_hd__dfxtp_2`).

**Start register:** `_275662_` — carries signal `u_cc.gen_ic[0].gen_k[1].p_in[8]`,
a partial sum register inside the generate-based adder tree of compute_core.
This flip-flop output drives 1,833 downstream gates simultaneously (fanout 1833),
creating a 9.18 ns delay at the register output before the first logic stage.

**End register:** `_231557_` — accumulator endpoint in the popcount reduction tree.

**Total path delay:** 43.14 ns against a 10 ns clock period, giving a setup
slack of -33.14 ns (violation).

## Logic Stages on Critical Path

The path traverses the following logic stages after the start register:

1. `sky130_fd_sc_hd__inv_2` — fanout 1696, load 2.496 pF, delay 28.22 ns.
   This single inverter drives 1,696 downstream gates simultaneously — the
   root cause of the timing violation. The XOR+popcount tree for C_IN=64,
   K=3 creates 192 parallel inputs that all fan out from shared partial sum
   registers, creating massive capacitive loading.

2. `sky130_fd_sc_hd__and3_2` — fanout 137, delay 0.68 ns.

3. `sky130_fd_sc_hd__o211a_2` — fanout 191, delay 1.23 ns.

4. `sky130_fd_sc_hd__a221o_2` — fanout 1, delay 0.64 ns.

5. `sky130_fd_sc_hd__or4_2` chain (5 gates) — total delay 3.22 ns.
   These OR4 gates implement the final stages of the Brent-Kung adder tree
   carrying partial popcount sums toward the final accumulator.

6. `sky130_fd_sc_hd__a31o_2` — delay 0.27 ns.

7. `sky130_fd_sc_hd__a21o_2` — delay 0.20 ns.

8. `sky130_fd_sc_hd__and3_2` — delay 0.18 ns (endpoint fanin).

## Root Cause and M4 Fix

The 28.22 ns delay on the single inverter (fanout 1696) is the dominant
bottleneck. This occurs because the act_buf (500 positions × 64 bits =
32,000 flip-flops) drives the XOR tree combinationally, creating enormous
fanout on shared nodes. The fix for M4 is a 4-stage pipelined adder tree
that splits this 43 ns path into four stages of approximately 10 ns each,
combined with OpenRAM SRAM macros replacing the 32,000-FF act_buf to
eliminate the fanout problem at the source.
