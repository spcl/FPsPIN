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
from cocotb.triggers import RisingEdge, Edge, First, with_timeout
from cocotb.regression import TestFactory
from cocotb.utils import hexdiffs
from cocotbext.axi import AxiStreamSource, AxiStreamBus, AxiStreamFrame
from cocotbext.axi import AxiBus, AxiMaster
from cocotbext.axi.stream import define_stream
from cocotbext.axi.constants import AxiResp

from dma_psdp_ram import PsdpRamRead, PsdpRamWrite, PsdpRamReadBus, PsdpRamWriteBus

from common import *

tests_dir = os.path.dirname(__file__)

DescBus, DescTransaction, DescSource, DescSink, DescMonitor = \
    define_stream("Desc",
                  signals=[
                      "dma_addr", "ram_sel", "ram_addr", "len", "tag", "valid", "ready"]
                  )

DescStatusBus, DescStatusTransaction, DescStatusSource, DescStatusSink, DescStatusMonitor = \
    define_stream("DescStatus",
                  signals=[
                      "tag", "error", "valid"]
                  )

class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger('cocotb.tb')
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 2, units='ns').start())
        
        # AXI master
        self.axi_master = AxiMaster(AxiBus.from_prefix(dut, 's_axi'), dut.clk, dut.rstn, reset_active_level=False)
        self.axi_align = self.axi_master.write_if.width // 8

        # read datapath
        self.rd_desc_sink = DescSink(DescBus.from_prefix(
            dut, 'm_axis_read_desc'), dut.clk, dut.rstn, reset_active_level=False)
        self.rd_desc_status_source = DescStatusSource(DescStatusBus.from_prefix(
            dut, 's_axis_read_desc_status'), dut.clk, dut.rstn, reset_active_level=False)
        self.ram_rd = PsdpRamRead(PsdpRamReadBus.from_prefix(dut, 'ram'), dut.clk, dut.rstn, reset_active_level=False)

        # write datapath
        self.wr_desc_sink = DescSink(DescBus.from_prefix(
            dut, 'm_axis_write_desc'), dut.clk, dut.rstn, reset_active_level=False)
        self.wr_desc_status_source = DescStatusSource(DescStatusBus.from_prefix(
            dut, 's_axis_write_desc_status'), dut.clk, dut.rstn, reset_active_level=False)
        self.ram_wr = PsdpRamWrite(PsdpRamWriteBus.from_prefix(dut, 'ram'), dut.clk, dut.rstn, reset_active_level=False)

    def set_idle_generator(self, generator=None):
        if generator:
            self.rd_desc_status_source.set_pause_generator(generator())
            self.axi_master.write_if.aw_channel.set_pause_generator(generator())
            self.axi_master.write_if.w_channel.set_pause_generator(generator())
            self.axi_master.read_if.ar_channel.set_pause_generator(generator())
            self.ram_rd.set_pause_generator(generator())
            self.ram_wr.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axi_master.read_if.r_channel.set_pause_generator(generator())
            self.axi_master.write_if.b_channel.set_pause_generator(generator())

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

addr = 0xdeadbeef00
length = 256
data = randbytes(length)

async def setup_tb(dut, idle_inserter, backpressure_inserter):
    tb = TB(dut)
    await tb.cycle_reset()

    clk_edge = RisingEdge(tb.dut.clk)
    await clk_edge
    await clk_edge

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    return tb

async def run_test_dma_read(dut, is_narrow=False, idle_inserter=None, backpressure_inserter=None):
    tb = await setup_tb(dut, idle_inserter, backpressure_inserter)
    clk_edge = RisingEdge(tb.dut.clk)
    # test dummy addr and long-enough length

    ram_base_addr = 0
    tb.ram_rd.write(ram_base_addr, data)
    tb.log.info('Dumping DMA read RAM:')
    tb.ram_rd.hexdump(0, length, '')

    for i in range(5):
        size = None
        if is_narrow:
            size = 0b010 # 4-byte bursts

        read_op = tb.axi_master.init_read(addr, length, size=size)
        desc = await tb.rd_desc_sink.recv()
        assert int(desc.dma_addr) == addr
        assert int(desc.len) >= length # should always read same or more than AXI request
        tb.log.info(f'Received DMA descriptor {desc}')

        await clk_edge
        await clk_edge

        # send finish
        resp = DescStatusTransaction(tag=desc.tag, error=0)
        tb.log.info(f'Sending DMA completion {resp}')
        await tb.rd_desc_status_source.send(resp)

        await with_timeout(read_op.wait(), 1000, 'ns')
        assert read_op.data.resp == AxiResp.OKAY
        if read_op.data.data != data:
            print('Data mismatch: read vs expected')
            print(hexdiffs(read_op.data.data, data))
            assert False

# TODO: test unaligned

async def run_test_dma_read_error(dut, idle_inserter=None, backpressure_inserter=None):
    tb = await setup_tb(dut, idle_inserter, backpressure_inserter)

    for i in range(5):
        read_op = tb.axi_master.init_read(addr, length)
        desc = await tb.rd_desc_sink.recv()
        assert int(desc.dma_addr) == addr
        assert int(desc.len) >= length # should always read same or more than AXI request
        tb.log.info(f'Received DMA descriptor {desc}')

        # send error finish
        resp = DescStatusTransaction(tag=desc.tag, error=1)
        tb.log.info(f'Sending error DMA completion {resp}')
        await tb.rd_desc_status_source.send(resp)

        await with_timeout(read_op.wait(), 1000, 'ns')
        assert read_op.data.resp == AxiResp.SLVERR

async def test_write_single(tb, addr, data):
    length = len(data)

    write_op = tb.axi_master.init_write(addr, data, None)

    # round down addr to cover start of transaction
    ram_addr = addr % tb.axi_align
    
    # wait for write DMA req
    # could be in multiple bursts
    remaining_len = length
    next_addr = addr
    ram_data = b''
    while remaining_len > 0:
        desc = await WithTimeout(tb.wr_desc_sink.recv())
        desc_addr = int(desc.dma_addr)
        desc_ram_addr = int(desc.ram_addr)
        len_burst = int(desc.len)
        tb.log.info(f'Received DMA descriptor {desc}, desc_addr={desc_addr:#x}, ram_addr={desc_ram_addr:#x}')

        assert desc_addr == next_addr
        assert desc_ram_addr == ram_addr

        # later bursts start at start of RAM
        ram_data += tb.ram_wr.read(ram_addr, len_burst)
        remaining_len -= len_burst
        next_addr += len_burst
        ram_addr = 0

        # send finish
        resp = DescStatusTransaction(tag=desc.tag, error=0)
        tb.log.info(f'Sending DMA completion {resp}')
        await tb.wr_desc_status_source.send(resp)

    assert remaining_len == 0

    # we will have trailing data in ram_data
    if ram_data[:length] != data:
        print('Data mismatch: written vs expected')
        print(hexdiffs(ram_data, data))
        assert False

    # wait for AXI transaction to finish
    await with_timeout(write_op.wait(), 1000, 'ns')
    assert write_op.data.resp == AxiResp.OKAY


async def run_test_dma_write(dut, idle_inserter=None, backpressure_inserter=None):
    tb = await setup_tb(dut, idle_inserter, backpressure_inserter)
    clk_edge = RisingEdge(tb.dut.clk)
    
    for i in range(5):
        await test_write_single(tb, addr, data)

async def run_test_dma_write_unaligned(dut, idle_inserter=None, backpressure_inserter=None):
    tb = await setup_tb(dut, idle_inserter, backpressure_inserter)
    clk_edge = RisingEdge(tb.dut.clk)
    
    # 4-byte word align
    unaligned_offsets = [x * 4 for x in range(1, 16)]
    lengths = [x * 4 for x in range(1, 65)]
    for off, length in product(unaligned_offsets, lengths):
        tb.log.info(f'Testing unaligned: offset={off} length={length}')
        data = randbytes(length)
        await test_write_single(tb, addr + off, data)

async def run_test_dma_write_error(dut, idle_inserter=None, backpressure_inserter=None):
    tb = await setup_tb(dut, idle_inserter, backpressure_inserter)

    for i in range(5):
        addr = 0xdeadbeef00
        length = 256

        write_op = tb.axi_master.init_write(addr, data)
        desc = await WithTimeout(tb.wr_desc_sink.recv())
        assert int(desc.dma_addr) == addr
        assert int(desc.len) == length
        tb.log.info(f'Received DMA descriptor {desc}')

        # send error finish
        resp = DescStatusTransaction(tag=desc.tag, error=1)
        tb.log.info(f'Sending error DMA completion {resp}')
        await tb.wr_desc_status_source.send(resp)

        await with_timeout(write_op.wait(), 1000, 'ns')
        assert write_op.data.resp == AxiResp.SLVERR

def cycle_pause():
    # 1 cycle ready in 4 cycles
    return cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:
    factory = TestFactory(run_test_dma_read)
    factory.add_option('idle_inserter', [None, cycle_pause])
    factory.add_option('backpressure_inserter', [None, cycle_pause])
    factory.add_option('is_narrow', [False])
    factory.generate_tests()

    for t in [run_test_dma_read_error, run_test_dma_write, run_test_dma_write_error, run_test_dma_write_unaligned]:
        factory = TestFactory(t)
        factory.add_option('idle_inserter', [None, cycle_pause])
        factory.add_option('backpressure_inserter', [None, cycle_pause])
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
