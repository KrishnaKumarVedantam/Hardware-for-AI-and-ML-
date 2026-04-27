import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

@cocotb.test()
async def test_binary_conv_reset(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Apply reset
    dut.rst.value = 1
    dut.valid_in.value = 0

    # Initialize all activations and weights to 0
    for i in range(64 * 3):
        dut.act[i].value = 0
        dut.weights[i].value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Check reset cleared output
    await FallingEdge(dut.clk)
    assert dut.result.value.to_signed() == 0, f"Expected 0 after reset, got {dut.result.value.to_signed()}"
    cocotb.log.info(f"Reset check: result=0 PASS")

    # Release reset, apply one representative input
    # All weights=1, all act MSB=1 (negative activations)
    # XOR(1,1) = 0 for all -> popcount=0 -> result = K*C_IN - 0 = 3*64 = 192
    dut.rst.value = 0
    for i in range(64 * 3):
        dut.weights[i].value = 1
        dut.act[i].value = -1  # MSB=1 (negative)

    dut.valid_in.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)

    got = dut.result.value.to_signed()
    cocotb.log.info(f"Representative input test: result={got} (expect 192)")
    cocotb.log.info("Simulation harness working!")
