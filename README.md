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
  - Binary Conv2 DOMINANT (XOR+popcount)
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
| FC | 64 to 10 classes | 1,280 | 0.01% |
| Total | | 12,481,280 | |

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

## Arithmetic Intensity and Roofline Analysis

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

## HDL Compute Core: binary_conv.sv

binary_conv.sv implements the Binary 1D Convolution engine for the dominant
Conv2 kernel (98.4% of total FLOPs). It replaces traditional FP32
multiply-accumulate with XOR + popcount, exploiting 1-bit weight compression
of the Binary Neural Network. For each output channel it XORs each 1-bit
weight with the MSB of each INT8 activation, computes popcount of the XOR
results, and computes result = K x C_IN - 2 x popcount, registering the
result on the rising clock edge with synchronous reset.
Parameters: DATA_WIDTH=8, KERNEL_SIZE=3, C_IN=64, C_OUT=64.

---

## Interface Choice: SPI

The SPI interface was selected based on the M1 arithmetic intensity analysis
which showed Conv2 at 187.5 FLOPs/byte — 5.6x above the ridge point of
33.3 FLOPs/byte — placing the kernel firmly in the compute-bound regime.
Since the design is compute-bound and not memory-bound, interface bandwidth
is not the bottleneck. At 10 inferences per second, only 510 bytes per
inference are transferred, requiring just 0.041 Mbit/s — a fraction of
SPI's 50 Mbit/s rating at only 0.082% utilization. AXI would add unnecessary
complexity with no performance benefit given this extremely low bandwidth
requirement. SPI Mode 0 (CPOL=0, CPHA=0) slave interfaces directly with
the host ARM Cortex-M MCU (STM32L4 or Nordic nRF52840).

---

## Precision Choice: 1-bit Weights + INT8 Activations

Weights are 1-bit packed (+1/-1) with total memory of only 1,560 bytes
fitting entirely on-chip SRAM. Activations are INT8 (8-bit signed integers).
This eliminates all floating point multiplications replacing them with
XOR + popcount which maps directly and efficiently to digital logic.
This precision choice enables the HW target of 400 GFLOP/s which is
3.3x over the SW baseline of 122.17 GFLOP/s on Apple M4.

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

## Tools
- HDL: SystemVerilog
- Simulation: cocotb + Icarus Verilog
- Synthesis: OpenLane 2 (RTL to GDSII)
- Interface: SPI
- Host: ARM Cortex-M
