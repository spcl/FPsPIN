import logging
import inspect
from typing import Optional
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
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory
from cocotbext.axi import AxiStreamSource, AxiStreamBus, AxiStreamFrame
from cocotbext.axi import AxiBus, AxiRam

from common import *

tests_dir = os.path.dirname(__file__)
pspin_rtl = os.path.join(tests_dir, '..', '..', 'rtl')

@dataclass(frozen=True)
class ExecutionContext:
    handler_mem_addr: int
    handler_mem_size: int
    host_mem_addr: int
    host_mem_size: int
    hh_addr: int
    hh_size: int
    ph_addr: int
    ph_size: int
    th_addr: int
    th_size: int
    scratchpad_0_addr: int
    scratchpad_0_size: int
    scratchpad_1_addr: int
    scratchpad_1_size: int
    scratchpad_2_addr: int
    scratchpad_2_size: int
    scratchpad_3_addr: int
    scratchpad_3_size: int

    @classmethod
    async def from_dut(cls, dut):
        fields = inspect.getfullargspec(cls.__init__)[0][1:]
        await WithTimeout(Active(dut, dut.her_valid, dut.her_ready, to_rising=False))
        ret = cls(**{k: getattr(dut, f'her_meta_{k}').value for k in fields})
        await RisingEdge(dut.clk) # return to normal edge
        return ret

class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger('cocotb.tb')
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 2, units='ns').start())

        self.msgid_width = self.dut.C_MSGID_WIDTH.value
        self.ctx_id_width = self.dut.CTX_ID_WIDTH.value
        self.num_ctxs = self.dut.NUM_HANDLER_CTX.value

        self.log.info(f'msgid_width = {self.msgid_width}')
        self.log.info(f'ctx_id_width = {self.ctx_id_width}')

        self.ctxs = {}

    async def cycle_reset(self):
        self.dut.rstn.setimmediatevalue(1)
        clk_edge = RisingEdge(self.dut.clk)
        await clk_edge
        await clk_edge
        self.dut.rstn.value = 0
        await clk_edge
        self.dut.her_ready.value = 0
        self.dut.gen_valid.value = 0
        await clk_edge
        self.dut.rstn.value = 1
        await clk_edge
        await clk_edge

    async def set_ctx(self, id, ctx: Optional[ExecutionContext]):
        self.dut.conf_valid.value = 0
        await RisingEdge(self.dut.clk)

        if ctx:
            self.ctxs[id] = ctx
        else:
            self.ctxs.pop(id)

        metas = {}
        enabled = 0
        for k in ctx.__dict__.keys():
            metas[k] = [(0).to_bytes(4, byteorder='little')] * self.num_ctxs

        for idx, ctx in self.ctxs.items():
            for k, v in ctx.__dict__.items():
                metas[k][idx] = v.to_bytes(4, byteorder='little')
                enabled |= (1 << idx)

        for k, v in metas.items():
            getattr(self.dut, f'conf_{k}').value = int.from_bytes(b''.join(v), byteorder='little')
        self.dut.conf_ctx_enabled.value = enabled
        self.dut.conf_valid.value = 1

    async def push_gen(self, addr, length, tag):
        self.dut.gen_addr.value = addr
        self.dut.gen_len.value = length
        self.dut.gen_tag.value = tag
        self.dut.gen_valid.value = 1
        await WithTimeout(Active(self.dut, self.dut.gen_ready))
        self.dut.gen_valid.value = 0
        self.log.debug(f'Pushed gen with tag {tag:#x}')
    
    async def pop_her(self, addr, length, tag, ctx, after=None):
        if after:
            self.log.debug('Joining previous task')
            await after.join()

        her_ctx = await ExecutionContext.from_dut(self.dut)
        self.log.debug(f'Popped HER with msgid {self.dut.her_msgid.value}')
        assert self.dut.her_msgid.value == self.unpack_tag(tag)[0]
        assert self.dut.her_is_eom.value == self.unpack_tag(tag)[1]
        assert self.dut.her_addr.value == addr
        assert self.dut.her_size.value == length
        assert self.dut.her_xfer_size.value == length
        assert her_ctx == ctx

    def pack_tag(self, msgid, is_eom, decode_ctx_id):
        def shift_mask(v, width, off):
            return (((1 << width) - 1) & v) << off
        return \
            shift_mask(msgid, self.msgid_width, 1 + self.ctx_id_width) | \
            shift_mask(is_eom, 1, self.ctx_id_width) | \
            shift_mask(decode_ctx_id, self.ctx_id_width, 0)

    def unpack_tag(self, tag):
        def extract(width, off):
            return (tag >> off) & ((1 << width) - 1)
        msgid = extract(self.msgid_width, 1 + self.ctx_id_width)
        is_eom = extract(1, self.ctx_id_width)
        ctx_id = extract(self.ctx_id_width, 0)
        self.log.debug(f'Tag {tag:#x} unpacked into {msgid}, {is_eom}, {ctx_id}')
        return msgid, is_eom, ctx_id

async def backpressure_her(dut):
    pattern = cycle([0, 0, 0, 1])
    for p in pattern:
        dut.her_ready.value = p
        await RisingEdge(dut.clk)

default_ctx = ExecutionContext(
    0xdead00, 0x200,
    0x0, 0x0,
    0xccee0000, 0x1000,
    0xccee1000, 0x1000,
    0xccee2000, 0x1000,
    0x0, 0x0,
    0x0, 0x0,
    0x0, 0x0,
    0x0, 0x0)

async def run_test_her_pipelined(dut, stall=False):
    tb = TB(dut)
    await tb.cycle_reset()

    if stall:
        cocotb.start_soon(backpressure_her(dut))

    # PsPIN not ready and default ctx not set
    assert dut.gen_ready.value == 0
    await tb.set_ctx(0, default_ctx)
    # PsPIN not ready
    assert dut.gen_ready.value == 0
    dut.her_ready.value = 1
    await WithTimeout(Active(dut, dut.gen_ready))

    task = None
    for idx in range(10):
        addr, length, tag = 0x18000 + idx * 0x1000, 0x5dc, tb.pack_tag(idx, 1, 0)
        task = cocotb.start_soon(tb.pop_her(addr, length, tag, default_ctx, after=task))
        await tb.push_gen(addr, length, tag)
    await task.join()

if cocotb.SIM_NAME:
    for test in [run_test_her_pipelined]:
        factory = TestFactory(test)
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
