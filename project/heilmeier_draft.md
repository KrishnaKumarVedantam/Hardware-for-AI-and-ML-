## Heilmeier Catechism — KWS Accelerator 

## Q1. What are you trying to do?
I am building a tiny custom chip that listens to a microphone and instantly recognizes specific spoken words — like "hey device" or "stop" — without sending any audio to the cloud. The chip does this by running a small neural network directly in hardware, using almost no power, so it can run 24/7 on a battery-powered device like a smartwatch or hearing aid.

## Q2. How is it done today, and what are the limits?
Today, wake-word detection either runs on a general-purpose microcontroller (which wastes energy running software designed for many tasks, not just this one), or relies on sending audio to a remote server (which creates privacy concerns, requires internet, and adds latency). The core limits are: microcontrollers burn too much power for always-on use, cloud solutions break when offline, and off-the-shelf chips are not optimized for the binary neural network math that makes tiny KWS models possible.

## Q3. What is new in your approach and why do you think it will be successful?
Instead of running the KWS neural network in software on a CPU, I am hardwiring the binary/ternary convolution + threshold operations directly into a custom SystemVerilog chiplet. Because the math is just XOR, popcount, and compare — no floating point — the hardware is extremely small and fast. The chip connects to a host MCU via a standard SPI interface. This approach will succeed because the kernel is completely fixed and small, the arithmetic is hardware-friendly, and the scope maps cleanly onto the M1–M4 milestones.
