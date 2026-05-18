## scope assessment

My project scope is building a binary convolution accelerator chiplet 
for keyword spotting using XOR+popcount in SystemVerilog — the CF07 
fallback synthesis (crossbar_mac.sv) closed timing with positive slack 
(0.000889 ns) and zero violations, confirming OpenLane 2 works on my machine, 
but the actual project compute_core.sv at full scale (C_IN=64, L=500) has not 
been synthesized yet — M3 will attempt this and measure timing, area, and power on the 
real design.
