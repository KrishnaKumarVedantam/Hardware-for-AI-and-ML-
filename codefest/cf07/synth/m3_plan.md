# M3 Plan — CF07
**Venkata Krishna Kumar Vedantam | ECE 510 Spring 2026**

## Synthesis target for M3

This CF07 synthesis used the CF06 fallback (crossbar_mac.sv, Option B)
because the project compute_core.sv uses scaled parameters (C_IN=4, L=8)
that do not match the M1 dominant kernel (C_IN=64, L=500). I will attempt
synthesis on the actual project compute_core.sv by May 22

## What I expect to be different

The project core at C_IN=64 will be significantly larger. The XOR+popcount
tree scales with C_IN×K = 192 bits instead of the crossbar's 16 inputs.
I expect the critical path to be dominated by the popcount adder tree
rather than the NOR4/XNOR2 chain seen here. Area will increase
substantially — I estimate 10-20× the 9008.64 µm² seen here.

## What I learned from this fallback

The 441 lint warnings from integer types in synthesizable blocks are a
real issue I will fix in compute_core.sv before M3 synthesis. The fanout
violation on the clock net (fanout 89) tells me I need to check clock
buffering in the project core. The 5-iteration DRC cleanup in routing
tells me the floorplan size matters — I will give OpenLane adequate
die area for the larger design.
