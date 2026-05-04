# M2 — KWS Hardware Accelerator
**ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam**

---

## How to reproduce M2 simulation

### Requirements

```bash
# Simulator: Icarus Verilog 12 (iverilog)
# Ubuntu/Debian:
sudo apt install iverilog

# Mac:
brew install icarus-verilog

# Verify:
iverilog -V   # should show version 12.0
```

No Python required to run the simulations. Python (numpy) is required
only to regenerate golden reference values (optional).

---

## Run compute_core simulation

```bash
cd project/m2/

# Compile
iverilog -g2012 -o sim_cc rtl/compute_core.sv tb/tb_compute_core.sv

# Run
vvp sim_cc

# Expected output:
# Tests passed : 5 / 5
# Total errors : 0
# RESULT: PASS
```

---

## Run interface simulation

```bash
cd project/m2/

# Compile
iverilog -g2012 -o sim_iface rtl/interface.sv tb/tb_interface.sv

# Run
vvp sim_iface

# Expected output:
# Tests passed : 4 / 4
# Total errors : 0
# RESULT: PASS
```

---

## Regenerate golden reference (optional)

```bash
pip install numpy
python3 golden_reference.py
# Verifies all 5 test vectors independently
# Saves .npy files for cross-referencing
```

---

## File descriptions

| File | Description |
|------|-------------|
| `rtl/compute_core.sv` | Binary Conv2 XOR+popcount engine (top module: `compute_core`) |
| `rtl/interface.sv` | SPI slave Mode 0 (top module: `spi_slave`) |
| `tb/tb_compute_core.sv` | 5-test compute core testbench, PASS/FAIL printed |
| `tb/tb_interface.sv` | 4-test SPI interface testbench, PASS/FAIL printed |
| `sim/compute_core_run.log` | Simulation transcript showing PASS |
| `sim/interface_run.log` | Simulation transcript showing PASS |
| `sim/waveform.png` | Annotated waveform: T1 all-agree test |
| `precision.md` | Numerical format justification + error analysis |

---

## Design parameters

### compute_core

| Parameter | Value | Description |
|-----------|-------|-------------|
| C_IN | 4 | Input channels (full design: 64) |
| C_OUT | 4 | Output channels (full design: 64) |
| K | 3 | Kernel size |
| L | 8 | Sequence length (full design: 500) |
| PAD | 1 | Zero padding each side |
| OBITS | 8 | Accumulator width (signed) |

*Note: Parameters reduced from full design (C_IN=64, C_OUT=64, L=500) for
testbench simulation speed. The arithmetic is identical — only scale differs.*

### interface (SPI slave)

| Parameter | Value | Description |
|-----------|-------|-------------|
| N_IN_BYTES | 4 | Receive bytes (full design: 500) |
| N_OUT_BYTES | 2 | Transmit bytes (full design: 10) |
| CPOL | 0 | SPI clock polarity: idle LOW |
| CPHA | 0 | SPI clock phase: sample on rising |
| Bit order | MSB first | Standard SPI convention |

---

## Deviation from M1 plan

No deviations from M1 design decisions. Interface remains SPI (selected in M1).
Kernel remains Binary Conv2. Precision remains 1-bit weights + INT8 activations.
Parameters are scaled down for testbench speed (C_IN=4, L=8 instead of 64/500)
but the arithmetic is identical.

**Note on interface.sv module name:** The file is named `interface.sv` as
required by the spec. However `interface` is a reserved keyword in
SystemVerilog (IEEE 1800-2012) — no conforming SV tool accepts it as a
module name. The top module is therefore named `spi_slave`. The file
interface.sv contains the complete SPI slave implementation matching the
M1 interface selection. The testbench compiles and runs with:
```bash
iverilog -g2012 -o sim_iface rtl/interface.sv tb/tb_interface.sv
```

---

## Simulator and version

- Simulator: **Icarus Verilog 12.0 (stable)**
- Copyright: Copyright (c) 2000-2021 Stephen Williams
- SystemVerilog mode: `-g2012` flag required
- VCD waveform viewer: GTKWave (optional, for waveform inspection)

```bash
gtkwave tb_compute_core.vcd &
gtkwave tb_interface.vcd &
```
