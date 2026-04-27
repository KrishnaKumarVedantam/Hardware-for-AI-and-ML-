# Hardware-for-AI-and-ML-

## Project 

## "KWS Accelerator"


# KWS Hardware Accelerator Chiplet
## ECE 510 — Hardware for AI/ML | Portland State University | Spring 2026
## Author: Venkata Krishna Kumar Vedantam

---

## What is this project?
A custom ASIC chiplet in SystemVerilog that accelerates Keyword Spotting (KWS)
inference — detecting wake words like "hey device" on a low-power edge device
(hearing aid, smartwatch, IoT) under 1mW, no cloud, no general-purpose CPU
doing inference.

---

## Algorithm
Binary Neural Network (BNN) structured as a 1D-CNN.
- Weights compressed to 1-bit (+1 or -1)
- Replaces FP32 multiply-accumulate with XOR + popcount
- Input: 500 MFCC values (50 frames x 10 mel coefficients)
- Output: 10 keyword class scores

---

## Full Pipeline
Microphone → ADC + Framing (16kHz, 25ms windows)
→ MFCC Extraction (SW on host MCU)
→ Feature Buffer (500 x INT8)
→ SPI TX (500 bytes)
→ CHIPLET:
  - On-chip SRAM
  - Binary Conv1 (XOR+popcount)
  - BatchNorm+Thresh
  - Binary Conv2 ★DOMINANT (XOR+popcount)
  - BatchNorm+Thresh
  - Global AvgPool
  - FC+Softmax
→ SPI RX (10 bytes)
→ Host MCU Decision
→ Wake/Idle signal

---

## Network Architecture

| Layer | Config | FLOPs | % |
|-------|--------|-------|---|
| Conv1 | C_in=1, C_out=64, K=3, L=500 | 192,000 | 1.5% |
| Conv2 | C_in=64, C_out=64, K=3, L=500 | 12,288,000 | 98.4% DOMINANT |
| FC | 64 → 10 classes | 1,280 | 0.01% |
| **Total** | | **12,481,280** | |

---

## Profiling Results (Mac M4, PyTorch 2.8.0)

| Metric | Value |
|--------|-------|
| Median inference latency | 0.102 ms |
| Throughput | 9,787 samples/sec |
| GFLOP/s achieved | 122.17 |
| Peak memory | 0.0012 MB |
| Dominant function | torch.conv1d (Conv2, 98.4% FLOPs) |

---

## Arithmetic Intensity & Roofline Analysis

| Metric | Value |
|--------|-------|
| Conv2 FLOPs | 12,288,000 |
| Total bytes | 65,536 |
| Arithmetic Intensity | 187.5 FLOPs/byte |
| M4 Peak Compute | 4,000 GFLOP/s |
| M4 Peak Bandwidth | 120 GB/s |
| Ridge Point | 33.3 FLOPs/byte |
| Kernel Position | 5.6x above ridge — COMPUTE-BOUND |
| SW achieved | 122.17 GFLOP/s |
| HW target | 400 GFLOP/s (3.3x over SW) |

---

## Interface: SPI

- Host: ARM Cortex-M MCU (STM32L4 or Nordic nRF52840)
- Data per inference: 500 bytes TX + 10 bytes RX = 510 bytes
- Required BW: 510 x 10Hz = 0.041 Mbit/s
- SPI rated: 50 Mbit/s
- SPI utilization: 0.082% — NOT interface-bound
- Conv2 AI = 187.5 FLOPs/byte (5.6x above ridge) — COMPUTE-BOUND
- SPI is sufficient; AXI complexity is unnecessary for this throughput

---

## Precision: 1-bit Weights + INT8 Activations

- Weights: 1-bit packed (+1/-1), total 1,560 bytes — fits on-chip SRAM
- Activations: INT8 (8-bit signed)
- Eliminates FP32 multiply — replaced by XOR + popcount
- Enables HW target of 400 GFLOP/s (3.3x over SW baseline)

---

## HW/SW Partition

| Hardware (chiplet) | Software (host MCU) |
|-------------------|---------------------|
| Binary Conv2 (dominant, 98.4%) | MFCC extraction |
| Binary Conv1 | ADC framing |
| BatchNorm+Thresh | Decision thresholding |
| FC+Softmax | Application control |
| FSM controller | |

---

## Weight Memory

| Layer | Size |
|-------|------|
| Conv1 weights (1-bit packed) | 24 bytes |
| Conv2 weights (1-bit packed) | 1,536 bytes |
| Total on-chip | 1,560 bytes |

---

## HDL Files (SystemVerilog)

| File | Description |
|------|-------------|
| project/hdl/binary_conv.sv | XOR + popcount 1D convolution engine |
| project/hdl/tb_binary_conv.py | cocotb testbench stub |
| project/hdl/Makefile | Simulation build system |

---

## Milestones

| Milestone | Due | Status |
|-----------|-----|--------|
| M1 | Apr 12 | COMPLETE |
| M2 | May 3 | IN PROGRESS |
| M3 | May 24 | Not started |
| M4 | Jun 7 | Not started |

---

## Tools
- HDL: SystemVerilog
- Simulation: cocotb + Icarus Verilog
- Synthesis: OpenLane 2 (RTL to GDSII)
- Interface: SPI
- Host: ARM Cortex-M
