import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge

@cocotb.test()
async def test_mac_basic(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Initialize and reset
    dut.rst.value = 1
    dut.a.value = 0
    dut.b.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Release reset, set inputs
    dut.rst.value = 0
    dut.a.value = 3
    dut.b.value = 4

    # Cycle 1: expect 12
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    got = dut.out.value.to_signed()
    assert got == 12, f"Cycle 1: Expected 12, got {got}"
    cocotb.log.info(f"Cycle 1: out={got} PASS")

    # Cycle 2: expect 24
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    got = dut.out.value.to_signed()
    assert got == 24, f"Cycle 2: Expected 24, got {got}"
    cocotb.log.info(f"Cycle 2: out={got} PASS")

    # Cycle 3: expect 36
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    got = dut.out.value.to_signed()
    assert got == 36, f"Cycle 3: Expected 36, got {got}"
    cocotb.log.info(f"Cycle 3: out={got} PASS")

    # Assert reset BEFORE rising edge
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    got = dut.out.value.to_signed()
    assert got == 0, f"Reset: Expected 0, got {got}"
    cocotb.log.info(f"After rst: out=0 PASS")

    # Release reset, apply a=-5 b=2 BEFORE rising edge
    dut.rst.value = 0
    dut.a.value = -5
    dut.b.value = 2

    # Cycle 4: expect -10
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    got = dut.out.value.to_signed()
    assert got == -10, f"Cycle 4: Expected -10, got {got}"
    cocotb.log.info(f"Cycle 4: out={got} PASS")

    # Cycle 5: expect -20
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    got = dut.out.value.to_signed()
    assert got == -20, f"Cycle 5: Expected -20, got {got}"
    cocotb.log.info(f"Cycle 5: out={got} PASS")

    cocotb.log.info("ALL TESTS PASSED!")

@cocotb.test()
async def test_mac_overflow(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Reset first
    dut.rst.value = 1
    dut.a.value = 0
    dut.b.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Use a=127, b=127 -> product=16129 per cycle
    # 2^31 - 1 = 2147483647
    # cycles to overflow = 2147483647 / 16129 = ~133,143 cycles
    # Instead use a=127, b=127 for 133144 cycles to force overflow
    dut.rst.value = 0
    dut.a.value = 127
    dut.b.value = 127

    # Run enough cycles to overflow
    for _ in range(133144):
        await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    got = dut.out.value.to_signed()
    cocotb.log.info(f"Overflow test: out={got}")

    # Check if wrapped (negative) or saturated (max positive)
    if got < 0:
        cocotb.log.info("BEHAVIOR: Accumulator WRAPS AROUND (2s complement overflow)")
    else:
        cocotb.log.info("BEHAVIOR: Accumulator SATURATES at max positive value")

    cocotb.log.info("test_mac_overflow DONE!")
