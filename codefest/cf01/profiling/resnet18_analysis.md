ResNet-18 Profiling Analysis
Top 5 MAC-Intensive Layers

| Layer Name | MACs | Parameters
|-------| :----| :----|
| Conv2d (1-1)| 118,013,952 | 9,408 |
| Conv2d (3-1) | 115,605,504  | 36,864 |
| Conv2d (3-4) | 115,605,504 | 36,864|
| Conv2d (3-7) | 115,605,504 |36,864|
| Conv2d (3-10) | 115,605,504 |  36,864 |


Conv2d (1-1) is the stem 7×7 convolution (3→64 channels, 224×224 input, stride 2) and is uniquely the single most MAC-intensive layer. The remaining entries are 3×3 convolutions in layer1 operating on 56×56 feature maps with 64 channels.

Arithmetic Intensity of the Most MAC-Intensive Layer
Layer: Conv2d (1-1) — stem convolution
Configuration:

Input:  [1, 3, 224, 224]
Output: [1, 64, 112, 112]
Kernel: 7×7, stride 2, no bias
Parameters: 9,408  (= 64 × 3 × 7 × 7)
MACs: 118,013,952


Arithmetic Intensity Calculation
Arithmetic intensity (AI) is defined as:
AI = Total FLOPs / Total Bytes transferred from DRAM
For FP32, each value occupies 4 bytes. We assume no data reuse — every weight and activation is loaded fresh from DRAM.

1. Total FLOPs
torchinfo counts MACs (multiply-accumulate = 1 multiply + 1 add = 2 FLOPs):
FLOPs = 2 × MACs = 2 × 118,013,952 = 236,027,904 FLOPs

2. Total Bytes Loaded from DRAM

Weights:
Weight elements = 64 × 3 × 7 × 7 = 9,408
Weight bytes    = 9,408 × 4       = 37,632 bytes

Input activations:
Input elements = 1 × 3 × 224 × 224 = 150,528
Input bytes    = 150,528 × 4        = 602,112 bytes

Output activations (written to DRAM):
Output elements = 1 × 64 × 112 × 112 = 802,816
Output bytes    = 802,816 × 4         = 3,211,264 bytes

Total bytes:
Total bytes = 37,632 + 602,112 + 3,211,264 = 3,851,008 bytes

3. Arithmetic Intensity
AI = 236,027,904 FLOPs / 3,851,008 bytes
AI ≈ 61.3 FLOPs/byte

Interpretation
An arithmetic intensity of ~61.3 FLOPs/byte under the pessimistic no-reuse assumption places this layer below the ridge point of modern GPUs (e.g., ~208 FLOPs/byte for FP32 on an A100), meaning it would be memory-bandwidth limited in this scenario. In practice, spatial reuse across the 7×7 receptive field would push the effective AI considerably higher.
Configuration:

Input:  [1, 64, 56, 56]
Output: [1, 64, 56, 56]
Kernel: 3×3, stride 1, padding 1, no bias
Parameters: 36,864  (= 64 × 64 × 3 × 3)
MACs: 115,605,504


Arithmetic Intensity Calculation
Arithmetic intensity (AI) is defined as:
AI = Total FLOPs / Total Bytes transferred from DRAM
For FP32, each value occupies 4 bytes. We assume no data reuse — every weight and activation is loaded fresh from DRAM.

1. Total FLOPs
torchinfo counts MACs (multiply-accumulate = 1 multiply + 1 add = 2 FLOPs):
FLOPs = 2 × MACs = 2 × 115,605,504 = 231,211,008 FLOPs

2. Total Bytes Loaded from DRAM

Weights:
Weight elements = 64 × 64 × 3 × 3 = 36,864
Weight bytes    = 36,864 × 4       = 147,456 bytes

Input activations:
Input elements = 1 × 64 × 56 × 56 = 200,704
Input bytes    = 200,704 × 4       = 802,816 bytes

Output activations (written to DRAM):
Output elements = 1 × 64 × 56 × 56 = 200,704
Output bytes    = 200,704 × 4       = 802,816 bytes

Total bytes:
Total bytes = 147,456 + 802,816 + 802,816 = 1,753,088 bytes

3. Arithmetic Intensity
AI = 231,211,008 FLOPs / 1,753,088 bytes
AI ≈ 131.9 FLOPs/byte

Interpretation
An arithmetic intensity of ~131.9 FLOPs/byte under the pessimistic no-reuse assumption places this layer near or below the ridge point of modern GPUs (e.g., ~208 FLOPs/byte for FP32 on an A100). In practice, the 3×3 sliding-window convolution enables significant input activation reuse across output positions, pushing the real AI higher and making this layer more compute-bound than the DRAM-only model suggests.
