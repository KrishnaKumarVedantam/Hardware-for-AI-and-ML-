# Interface Selection — SPI
**ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam**
**File: project/m1/interface_selection.md**

---

## Selected interface

**SPI (Serial Peripheral Interface)**
Selected from the project specification interface table.

---

## Host platform

The assumed host platform is an **ARM Cortex-M class MCU** such as
STM32L4 or Nordic nRF52840. This is a low-power microcontroller
appropriate for always-on wearable and IoT edge devices. Cortex-M MCUs
natively support SPI as a hardware peripheral with no additional interface
IP required. This is the correct host class for a hearing aid, smartwatch,
or IoT voice device — the intended deployment target.

---

## Bandwidth requirement calculation

Formula: throughput x data width = required bandwidth

Data per inference transaction:

| Direction | Data | Elements | Bytes each | Total bytes |
|-----------|------|----------|------------|-------------|
| Host to chiplet (SPI TX) | MFCC feature vector | 500 | 1 (INT8) | 500 |
| Chiplet to host (SPI RX) | Class scores | 10 | 1 (INT8) | 10 |
| Total per inference | | | | **510 bytes** |

Target inference rate: 10 Hz (10 inferences per second)

Required bandwidth:
```
BW = data per inference x inference rate
BW = 510 bytes x 10 Hz
BW = 5,100 bytes/sec
BW = 40,800 bits/sec
BW = 0.041 Mbit/s
```

---

## Interface rated bandwidth vs required bandwidth

| Parameter | Value |
|-----------|-------|
| Required bandwidth | 0.041 Mbit/s |
| SPI rated bandwidth | 50 Mbit/s (at 50 MHz SCLK) |
| Utilization | 0.041 / 50 = **0.082%** |
| Margin | 1,220x headroom |

**The design is NOT interface-bound.**

SPI transfer time per inference:
```
Transfer time = 4,080 bits / 50,000,000 bits/sec = 0.082 ms
```

This is less than the 0.102 ms software baseline latency. The interface
does not create a new bottleneck. Even at 1,000 inferences/sec (100x the
target rate), SPI utilization would be only 8.2% — still well within spec.

The interface does not appear as a constraint on the roofline model. The
design is compute-bound at AI = 187.5 FLOPs/byte, far above both the M4
ridge point (33.3 FLOPs/byte) and any interface bandwidth ceiling.

---

## Why SPI over other options from the specification table

**I2C (Low complexity, up to 3.4 Mbit/s):**
Sufficient bandwidth (0.041 Mbit/s needed vs 3.4 Mbit/s available) but
has shared-bus overhead, clock-stretching complexity, and higher per-byte
latency than SPI. SPI is simpler to implement in SystemVerilog and has
lower transaction overhead. I2C would require strong justification per
project spec — not appropriate when SPI is simpler and sufficient.

**AXI4-Lite / AXI4-Stream (Medium complexity):**
Appropriate for FPGA SoC designs with an ARM AXI bus fabric. The target
host is an MCU-class device which does not have an AXI bus fabric. Using
AXI would require an AXI-to-SPI bridge adding unnecessary complexity
with no bandwidth benefit for this use case.

**PCIe Gen3/4 (High complexity):**
Vastly over-specified. PCIe targets GB/s data-center workloads. This
design requires KB/s. PCIe endpoint controller IP would consume more area
than the accelerator itself. Not appropriate for MCU-class host.

**UCIe (High complexity):**
Designed for multi-die chiplet interconnects at up to 100 GB/s. This is
an architectural study-level interface not appropriate for a student
chiplet connecting to an MCU host.

**Conclusion:** SPI is the correct interface. It matches the MCU host
platform, provides 1,220x bandwidth margin over the required 0.041 Mbit/s,
is the simplest interface to implement and verify in SystemVerilog, and
does not create any bottleneck at any realistic inference rate.
