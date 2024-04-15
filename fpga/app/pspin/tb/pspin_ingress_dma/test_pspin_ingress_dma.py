import logging
import pytest
import os
from dataclasses import dataclass
from functools import reduce
from itertools import product
from itertools import cycle
from math import ceil
from random import randbytes
import operator

import cocotb
from cocotb_test.simulator import run
from cocotb.clock import Clock, Timer
from cocotb.triggers import RisingEdge, Edge, First
from cocotb.regression import TestFactory
from cocotbext.axi import AxiStreamSource, AxiStreamBus, AxiStreamFrame
from cocotbext.axi import AxiBus, AxiRam

from common import *

tests_dir = os.path.dirname(__file__)
pspin_rtl = os.path.join(tests_dir, '..', '..', 'rtl')
axis_lib_rtl = os.path.join(tests_dir, '..', '..', 'lib', 'axis', 'rtl')
axi_lib_rtl = os.path.join(tests_dir, '..', '..', 'lib', 'axi', 'rtl')

class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger('cocotb.tb')
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 2, units='ns').start())

        self.src = AxiStreamSource(AxiStreamBus.from_prefix(dut, 's_axis_pspin_rx'),
                                   dut.clk, dut.rstn, reset_active_level=False)
        # 1MB test RAM
        self.axi_ram = AxiRam(AxiBus.from_prefix(dut, 'm_axi_pspin'),
                              dut.clk, dut.rstn, reset_active_level=False, size=2**20)

        self.dut.her_gen_ready.value = 1

    def set_idle_generator(self, generator=None):
        if generator:
            self.src.set_pause_generator(generator())
            self.axi_ram.write_if.b_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axi_ram.write_if.aw_channel.set_pause_generator(generator())
            self.axi_ram.write_if.w_channel.set_pause_generator(generator())

    async def cycle_reset(self):
        self.dut.rstn.setimmediatevalue(1)
        clk_edge = RisingEdge(self.dut.clk)
        await clk_edge
        await clk_edge
        self.dut.rstn.value = 0
        await clk_edge
        await clk_edge
        self.dut.rstn.value = 1
        await clk_edge
        await clk_edge

    pending = {}
    async def push_frame_nocheck(self, pkt, addr, idx):
        frame = AxiStreamFrame(pkt)
        # not setting tid, tdest

        assert addr % (self.dut.AXI_DATA_WIDTH.value // 8) == 0, 'unaligned'

        self.src.send_nowait(frame)
        await self.src.wait()
        await RisingEdge(self.dut.clk)
        # packet meta comes after packet data
        self.dut.write_desc_addr.value = addr
        self.dut.write_desc_len.value = len(pkt)
        self.dut.write_desc_tag.value = idx
        self.dut.write_desc_valid.value = 1
        await WithTimeout(Active(self.dut, self.dut.write_desc_ready))
        self.dut.write_desc_valid.value = 0

        self.pending[idx] = pkt, addr
        self.log.debug(f'Pending tags after push_frame_nocheck: {self.pending.keys()}')

    async def check_result(self, after=None):
        if after:
            self.log.debug('Joining previous check')
            await after.join()
            await RisingEdge(self.dut.clk)

        await WithTimeout(Active(self.dut, self.dut.her_gen_valid, self.dut.her_gen_ready, to_rising=False))
        self.log.debug('check_result handshake ok')
        self.log.debug(f'Pending tags before check_result: {self.pending.keys()}')
        tag = int(self.dut.her_gen_tag.value)

        assert tag in self.pending.keys()

        pkt, addr = self.pending.pop(tag)

        assert self.dut.her_gen_addr.value == addr
        assert self.dut.her_gen_len.value == len(pkt)

        assert self.axi_ram.read(addr, len(pkt)) == pkt

        self.log.debug('check_result finished')
        await RisingEdge(self.dut.clk)

    async def push_frame(self, pkt, addr, idx):
        await self.push_frame_nocheck(pkt, addr, idx)
        await self.check_result()

async def backpressure_completion(dut):
    pattern = cycle([0, 0, 0, 1])
    for p in pattern:
        dut.her_gen_ready.value = p
        await RisingEdge(dut.clk)

async def run_test_basic_dma(dut, stall=False, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    if stall:
        cocotb.start_soon(backpressure_completion(dut))

    await tb.push_frame(b'Hello, world!', 0x0000, 1)
    await tb.push_frame(randbytes(1300), 0x0040, 2)

async def run_test_pipelined(dut, stall=False, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    if stall:
        cocotb.start_soon(backpressure_completion(dut))

    task = None
    for i in range(10):
        pkt = randbytes(512)
        addr = round_align(i * len(pkt))
        tb.log.info(f'Pushing packet of length {len(pkt)} to {addr}, tag {i}')
        await tb.push_frame_nocheck(pkt, addr, i)
        # chain checks and wait on the last one
        task = cocotb.start_soon(tb.check_result(task))
    await task.join()

def cycle_pause():
    # 1 cycle ready in 4 cycles
    return cycle([1, 1, 1, 0])

if cocotb.SIM_NAME:
    for test in [run_test_basic_dma, run_test_pipelined]:
        factory = TestFactory(test)
        factory.add_option('idle_inserter', [None, cycle_pause])
        factory.add_option('backpressure_inserter', [None, cycle_pause])
        factory.add_option('stall', [True, False])
        factory.generate_tests()

# cocotb-test
'''
@pytest.mark.parametrize(
    ['matcher_len', 'buf_frames', 'data_width'],
    list(product([66, 2048], [0, 1, 2], [64, 512]))
)
def test_match_engine(request, matcher_len, buf_frames, data_width):
    dut = 'pspin_pkt_match'
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(pspin_rtl, f'{dut}.v'),
        os.path.join(axis_lib_rtl, f'axis_fifo.v'),
    ]

    parameters = {}
    parameters['AXIS_IF_DATA_WIDTH'] = data_width
    parameters['UMATCH_MATCHER_LEN'] = matcher_len
    parameters['UMATCH_BUF_FRAMES'] = buf_frames

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, 'sim_build',
        request.node.name.replace('[', '-').replace(']', ''))

    run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env
    )
'''
