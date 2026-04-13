## Heilmeier Catechism — KWS Accelerator Chiplet
## ECE 510 Spring 2026 | Venkata Krishna Kumar Vedantam
## File: project/heilmeier.md

## Q1. What are you trying to do?

I am building a custom hardware chiplet that detects specific spoken wake
words such as "hey device" or "stop" directly on a low-power embedded
device, with no internet connection required. The chiplet runs a Binary
Neural Network (BNN) structured as a 1D Convolutional Neural Network
(1D-CNN). The computationally dominant kernel is the binary 1D convolution
layer Conv2 (64 input channels, 64 output channels, kernel size 3, sequence
length 500), which replaces floating-point multiply-accumulate with XOR and
popcount operations — the most hardware-efficient arithmetic in digital logic.
The chiplet takes a 500-element MFCC feature vector (50 audio frames x 10
mel-frequency cepstral coefficients) as input over an SPI interface and
classifies it into one of 10 keyword classes. Target power consumption is
under 1 mW, making it suitable for always-on deployment in hearing aids,
smartwatches, and IoT edge devices.

## Q2. How is it done today, and what are the limits?

Today, keyword spotting runs in software on a general-purpose processor.
Profiling the DS-CNN BNN model (Python 3.9, PyTorch 2.8.0, Apple Mac M4,
batch size 1) using cProfile over 10 inference runs identified torch.conv1d
as the function with the highest cumulative execution time. torch.conv1d was
called 20 times (2 conv layers x 10 runs) and dominated all other functions.
Benchmark measurements on Mac M4 (100 runs, wall-clock, torch.no_grad()):
MetricValueMedian inference latency0.102 msMin / Max latency0.100 ms / 0.119 msThroughput9,787 samples/secPeak memory usage0.0012 MBTotal FLOPs per inference12,481,280GFLOP/s achieved122.17
Of the 12,481,280 total FLOPs, 12,288,000 (98.4%) belong to the Conv2
binary convolution layer alone. Despite the M4 achieving 122.17 GFLOP/s,
this represents only 3.05% of the M4 hardware peak of 4,000 GFLOP/s
(Source: apple.com/mac/m4). The inefficiency occurs because the
general-purpose CPU has no native 1-bit multiply instruction and internally
promotes binary weights to FP32, wasting 32x of both compute capacity and
memory bandwidth.
Limits of current practice:

General-purpose MCU (STM32H7 at 480 MHz): same model takes 40-120 ms
per inference — 400-1200x slower than M4 — consuming 10-50 mW active
power. Too slow and too power-hungry for always-on use.
Cloud offload: introduces 100-500 ms round-trip latency, requires
constant internet, and sends raw audio off-device raising privacy
concerns.
General-purpose CPUs cannot natively exploit 1-bit weight structure,
leaving 96.95% of M4 compute capacity unused on this workload.


## Q3. What is your approach and why will it succeed?

Instead of running the BNN in software, the binary 1D Conv2 kernel which
accounts for 98.4% of all FLOPs is hardwired directly into a synthesizable
SystemVerilog chiplet.
Arithmetic intensity of the Conv2 kernel (1-bit packed weights, INT8
activations, no DRAM reuse assumed):
Formula : AI = FLOPs / Bytes
FLOPs   : 2 x 64 x 64 x 3 x 500 = 12,288,000
Bytes   : 1,536 (weights) + 32,000 (inputs) + 32,000 (outputs) = 65,536
AI      : 12,288,000 / 65,536 = 187.5 FLOPs/byte
On the Mac M4 roofline:

Peak compute : 4,000 GFLOP/s (Source: apple.com/mac/m4)
Peak BW      : 120 GB/s (Source: Apple M4 spec sheet)
Ridge point  : 4,000 / 120 = 33.3 FLOPs/byte
Conv2 AI     : 187.5 FLOPs/byte — 5.6x above ridge point — COMPUTE-BOUND

The hardware chiplet replaces all multiply-accumulate units with XOR gates
and popcount trees. XOR is a single-gate operation — the native operation
for 1-bit binary weights. This eliminates the 32x compute waste of the
general-purpose CPU. The design targets 400 GFLOP/s, a 3.3x improvement
over the measured 122.17 GFLOP/s software baseline.
The chiplet connects to a host MCU via SPI. Required bandwidth:
500 bytes x 10 inferences/sec = 0.041 Mbit/s vs SPI rated 50 Mbit/s,
giving 0.082% utilization. The design is not interface-bound.
This approach will succeed because the Conv2 kernel is regular and
statically shaped (no sparsity, no dynamic shapes), the arithmetic maps
directly to digital logic (XOR gate = 1-bit multiply), the roofline
confirms compute throughput is the correct bottleneck to address, and
commercial precedent exists in Syntiant NDP101/NDP120 chips which implement
the same class of binary convolution in production silicon.
