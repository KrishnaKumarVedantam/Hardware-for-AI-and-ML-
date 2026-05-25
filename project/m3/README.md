# M3 — KWS Hardware Accelerator Chiplet
**Venkata Krishna Kumar Vedantam | ECE 510 Spring 2026**

## Project Summary

Binary Conv2 XOR+popcount hardware accelerator chiplet for keyword
spotting. Dominant kernel from M1 profiling: C_IN=64, C_OUT=64, K=3,
L=500. SPI slave interface connects host ARM Cortex-M to compute core.

## File Catalog

### RTL (project/m3/rtl/)

| File | Description |
|------|-------------|
| `compute_core.sv` | XOR+popcount Binary Conv2 compute core. C_IN=64, K=3, L=500. Generate-based adder tree. Synthesizable SystemVerilog. |
| `interface.sv` | SPI Mode 0 slave interface. N_IN_BYTES=4000 (simulation), N_IN_BYTES=64 (synthesis scope). 3-FF synchronizer for CDC. Flat packed ports for Yosys compatibility. |
| `top.sv` | Integrates compute_core and spi_slave. Glue FSM: G_IDLE→G_LOAD→G_COMPUTE→G_PACK. N_IN_BYTES=4000 (simulation), N_IN_BYTES=64 (synthesis scope). |

### Testbench (project/m3/tb/)

| File | Description |
|------|-------------|
| `tb_top.sv` | End-to-end co-simulation testbench. Drives SPI pins only — no direct compute_core access. Sends 4000 bytes (C_IN=64, L=500). Verifies MISO against golden.py (seed=42). Prints PASS or FAIL. |

### Simulation (project/m3/sim/)

| File | Description |
|------|-------------|
| `cosim_run.log` | Actual simulation output. RESULT: PASS. MISO byte[0]=0xF8 (OC=0, result=-8), byte[1]=0x0E (OC=1, result=14). Matches golden.py exactly. |
| `cosim_waveform.vcd` | Full VCD waveform dump. 88MB. Three regions: SPI write (4000 bytes), compute (33500 cycles), SPI read (10 bytes). |
| `cosim_waveform.png` | Waveform with three annotated regions: host write transaction (4000-byte SPI), internal compute (33500 cycles), host read of result (10-byte SPI). |

### Synthesis (project/m3/synth/)

| File | Description |
|------|-------------|
| `config.json` | OpenLane 2.3.10 configuration. CLOCK_PERIOD=10.0ns, DIE_AREA=5000×5000µm, PDK=sky130A, STD_CELL_LIBRARY=sky130_fd_sc_hd. |
| `openlane_run.log` | Full OpenLane stdout/stderr. Documents all stages attempted, errors, and warnings. |
| `area_report.txt` | Yosys synthesis statistics. 160,471 cells, 2,196,806 µm² chip area, cell type breakdown. Pre-PnR. |
| `timing_report.txt` | OpenSTA pre-PnR timing report. Worst slack -33.14ns. Critical path: _275662_ → inv_2 (fanout 1696) → adder tree → _231557_. |
| `power_report.txt` | OpenSTA pre-PnR power estimate. Total 286.1mW (Sequential 191.9mW, Combinational 94.3mW). Nominal corner tt_025C_1v80. |
| `critical_path.md` | Critical path analysis. Start/end registers, logic stages, root cause (fanout 1696 on inv_2), M4 fix. |

### Documentation (project/m3/)

| File | Description |
|------|-------------|
| `synthesis_notes.md` | 500+ words. Two synthesis attempts documented. Root cause of OOM and routing failure. What was changed. Revised scope and M4 fix plan. |
| `README.md` | This file. |

## How to Reproduce Co-Simulation

**Simulator:** Icarus Verilog 12.0

```bash
cd project/m3
iverilog -g2012 -o sim/cosim \
    tb/tb_top.sv rtl/top.sv rtl/interface.sv rtl/compute_core.sv
vvp sim/cosim 2>&1 | tee sim/cosim_run.log
```

Expected output: `RESULT: PASS`

## How to Reproduce Synthesis

**Tool:** OpenLane 2.3.10 via Docker

```bash
cd project/m3/synth
docker run --rm \
  -v /path/to/kws_project:/work \
  -e PDK_ROOT=/root/.volare \
  ghcr.io/efabless/openlane2:2.3.10 \
  sh -c "cd /work/project/m3/synth && openlane config.json" \
  2>&1 | tee openlane_run.log
```

Note: Synthesis uses N_IN_BYTES=64 (scope adjustment). See
synthesis_notes.md for full explanation of scope and failure modes.

## Synthesis Result Summary

Yosys synthesis completed (Stage 6). Pre-PnR STA completed (Stage 12).
Placement completed (Stage 33). Clock tree synthesis completed (Stage 34).
Post-CTS timing repair did not converge — WNS -20.56ns after 1276
iterations. Routing not reached. See synthesis_notes.md for root cause
and M4 fix plan.

```
Cells:        160,471
Area:       2,196,806 µm²
WNS:           -33.14 ns (pre-PnR)
Power:         286.1 mW (pre-PnR estimate)
Critical path: 43.14 ns (inv_2 fanout 1696 → adder tree)
```
