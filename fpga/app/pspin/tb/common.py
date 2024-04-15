import cocotb
from cocotb.clock import Clock, Timer
from cocotb.triggers import FallingEdge, RisingEdge, First
from cocotb.utils import get_sim_time
from functools import reduce
from operator import and_

def round_align(number, multiple=64):
    return multiple * round(number / multiple)

async def Active(dut, *signals, to_falling=True, to_rising=True):
    if to_falling:
        await FallingEdge(dut.clk)
    while not reduce(and_, map(lambda a: a.value, signals), True):
        await FallingEdge(dut.clk)
    if to_rising:
        await RisingEdge(dut.clk)

async def WithTimeout(action, timeout_ns=10000):
    # timeout
    timer = Timer(timeout_ns, 'ns')
    task = cocotb.start_soon(action)
    result = await First(task, timer)
    if result is timer:
        assert False, 'Timeout waiting for action'
    return result
