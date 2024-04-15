import logging
import pytest
import os
import inspect
from typing import Optional
from dataclasses import dataclass
from functools import reduce
from itertools import product
from itertools import cycle
from math import ceil
import operator

import cocotb
from cocotb_test.simulator import run
from cocotb.clock import Clock, Timer
from cocotb.triggers import RisingEdge, Edge, First
from cocotb.regression import TestFactory
from cocotb.utils import get_sim_time
from cocotbext.axi import AxiStreamSource, AxiStreamSink, AxiStreamBus, AxiStreamFrame
from cocotbext.axi import AxiBus, AxiRam

# we only use the raw parser
from scapy.utils import rdpcap

from common import *

tests_dir = os.path.dirname(__file__)
pspin_rtl = os.path.join(tests_dir, '..', '..', 'rtl')
axis_lib_rtl = os.path.join(tests_dir, '..', '..', 'lib', 'axis', 'rtl')
pcap_file = os.path.join(tests_dir, 'sample.pcap')

@dataclass(frozen=True)
class MatchRule:
    idx: int
    mask: int
    start: int
    end: int

    @classmethod
    def empty(cls): # always true
        return cls(0, 0, 0, 0)

    @classmethod
    def false(cls): # always false
        return cls(0, 0, 1, 0)

MODE_AND = 0
MODE_OR = 1

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
        await RisingEdge(dut.clk)
        return ret

class TB:
    def __init__(self, dut):
        self.dut = dut
        self.match_width = self.dut.UMATCH_WIDTH.value
        self.match_count = self.dut.UMATCH_ENTRIES.value
        self.match_modes = self.dut.UMATCH_MODES.value
        self.ruleset_count = self.dut.NUM_HANDLER_CTX.value

        self.pkt_buf_base = self.dut.BUF_START.value

        self.log = logging.getLogger('cocotb.tb')
        self.log.setLevel(logging.DEBUG)

        self.log.info(f'Rule Width: {self.match_width}; Rule Count: {self.match_count}')

        cocotb.start_soon(Clock(dut.clk, 2, units='ns').start())

        self.pkt_src = AxiStreamSource(AxiStreamBus.from_prefix(dut, 's_axis_nic_rx'),
                                       dut.clk, dut.rstn, reset_active_level=False)
        # self.pkt_src.log.setLevel(logging.WARNING)
        self.unmatched_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, 'm_axis_nic_rx'),
                                            dut.clk, dut.rstn, reset_active_level=False)
        # self.unmatched_sink.log.setLevel(logging.WARNING)
        self.axi_ram = AxiRam(AxiBus.from_prefix(dut, 'm_axi_pspin_ni'),
                              dut.clk, dut.rstn, reset_active_level=False, size=2**20)

        self.rulesets = [([], MODE_OR) for _ in range(4)]
        for i in range(self.ruleset_count):
            self.all_bypass(i)
        self.ctxs = {}

        self.dut.her_ready.value = 1

    def set_idle_generator(self, generator=None):
        if generator:
            self.log.info('Setting idle generator')
            self.axi_ram.write_if.b_channel.set_pause_generator(generator())
            self.pkt_src.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.log.info('Setting back pressure generator')
            self.unmatched_sink.set_pause_generator(generator())
            self.axi_ram.write_if.aw_channel.set_pause_generator(generator())
            self.axi_ram.write_if.w_channel.set_pause_generator(generator())

    # ruleset generation - last rule is the EOM condition
    def all_match(self, idx, always_eom=True):
        if always_eom:
            eom_rule = MatchRule.empty()
        else: # never eom
            eom_rule = MatchRule.false()
        self.rulesets[idx] = [
            MatchRule.empty(),
            MatchRule.empty(),
            MatchRule.empty(),
            eom_rule,
        ], MODE_AND
    def all_bypass(self, idx):
        self.rulesets[idx] = [
            MatchRule.false(),
            MatchRule.false(),
            MatchRule.false(),
            MatchRule.false(),
        ], MODE_AND
    def tcp_dportnum(self, idx, dport):
        assert self.match_width == 32, 'only support 32-bit match atm'
        self.rulesets[idx] = [
            MatchRule(5, 0xff, 0x06, 0x06), # proto == TCP
            MatchRule(9, 0xffff0000, dport << 16, dport << 16), # dport
            MatchRule.empty(),
            MatchRule(11, 0x10, 0x10, 0x10) # TCP.ACK set
        ], MODE_AND
    def tcp_or_udp(self, idx):
        assert self.match_width == 32, 'only support 32-bit match atm'
        self.rulesets[idx] = [
            MatchRule(5, 0xff, 0x06, 0x06), # proto == TCP
            MatchRule(5, 0xff, 0x11, 0x11), # proto == UDP
            MatchRule.false(),
            MatchRule.false(), # never eom
        ], MODE_OR

    # match packet with ruleset
    def match(self, pkt: bytes):
        self.log.debug(f'Current rulesets:')
        for ru, mo in self.rulesets:
            self.log.debug(f'\t{ru}, mode {mo}')

        match_bytes = self.match_width // 8
        def match_ruleset(idx):
            def match_single(ru: MatchRule):
                r = pkt[ru.idx*match_bytes:ru.idx*match_bytes+match_bytes]
                # big endian
                i = reduce(lambda acc, v: (acc << 8) + v, r, 0)
                im = i & ru.mask
                # self.log.debug(f'i={i:#x}\tim={im:#x}\tru.start={ru.start:#x}\tru.end={ru.end:#x}')
                return ru.start <= im and im <= ru.end
            results = map(match_single, self.rulesets[idx][0][:-1])

            is_eom = match_single(self.rulesets[idx][0][-1])
            if self.rulesets[idx][1] == MODE_AND:
                return reduce(operator.and_, results, True), is_eom
            elif self.rulesets[idx][1] == MODE_OR:
                return reduce(operator.or_, results, False), is_eom
            else:
                raise ValueError(f'unknown matching mode {self.mode}')
        for idx in range(self.ruleset_count - 1):
            matched, eom = match_ruleset(idx)
            if matched:
                return idx, eom
        
        return None, eom

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

    async def set_rule(self):
        self.dut.match_valid.value = 0
        # deassert valid to clear matching rule for at least one cycle
        await RisingEdge(self.dut.clk)

        concat_idx, concat_mask, concat_start, concat_end = b'', b'', b'', b''
        concat_mode = 0
        for rs_idx, (rus, mo) in enumerate(self.rulesets):
            assert len(rus) <= self.match_count, 'too many rules supplied'
            assert mo >= 0 and mo < self.match_modes, 'unrecognised mode %d' % mo

            self.log.info(f'Setting rule #{rs_idx} {rus}, mode {mo}')

            assert self.match_count == len(rus), 'rule set not completely filled'
            for ru in rus:
                concat_idx += ru.idx.to_bytes(self.match_width // 8, byteorder='little')
                concat_mask += ru.mask.to_bytes(self.match_width // 8, byteorder='big')
                concat_start += ru.start.to_bytes(self.match_width // 8, byteorder='big')
                concat_end += ru.end.to_bytes(self.match_width // 8, byteorder='big')

            concat_mode += mo << (rs_idx * (self.dut.UMATCH_MODES.value.bit_length() - 1))

        self.dut.match_idx.value = int.from_bytes(concat_idx, byteorder='little')
        self.dut.match_mask.value = int.from_bytes(concat_mask, byteorder='little')
        self.dut.match_start.value = int.from_bytes(concat_start, byteorder='little')
        self.dut.match_end.value = int.from_bytes(concat_end, byteorder='little')
        self.dut.match_mode.value = concat_mode

        self.dut.match_valid.value = 1
        # hold at least one cycle after setting matching rule
        await RisingEdge(self.dut.clk)

    async def set_ctx(self, idx, ctx: Optional[ExecutionContext]):
        self.dut.her_gen_valid.value = 0
        await RisingEdge(self.dut.clk)

        if ctx:
            self.ctxs[idx] = ctx
        else:
            self.ctxs.pop(idx)

        metas = {}
        enabled = 0
        for k in ctx.__dict__.keys():
            metas[k] = [(0).to_bytes(4, byteorder='little')] * self.ruleset_count

        for idx, ctx in self.ctxs.items():
            for k, v in ctx.__dict__.items():
                metas[k][idx] = v.to_bytes(4, byteorder='little')
                enabled |= (1 << idx)

        for k, v in metas.items():
            getattr(self.dut, f'her_gen_{k}').value = int.from_bytes(b''.join(v), byteorder='little')
        self.dut.her_gen_enabled.value = enabled
        self.dut.her_gen_valid.value = 1

    async def pop_her(self, pkt, idx, ctx, eom):
        self.log.debug('Popping HER')
        her_ctx = await ExecutionContext.from_dut(self.dut)
        assert self.dut.her_is_eom.value == eom
        assert her_ctx == ctx

        addr, size, xfer_size, msgid = \
            self.dut.her_addr.value, \
            self.dut.her_size.value, \
            self.dut.her_xfer_size.value, \
            self.dut.her_msgid.value

        self.log.debug(f'Popped HER with msgid {self.dut.her_msgid.value}')
        self.log.info(f'Addr = {int(addr):#x}, size = {int(size)}, xfer_size = {int(xfer_size)}, msgid = {int(msgid)}')
        assert idx == msgid, f'packet #{idx} missing'

        assert size == len(pkt)
        assert self.axi_ram.read(addr, len(pkt)) == pkt

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
        return msgid, is_eom, ctx_id

    async def check_pkt(self, pkt, idx, after=None, prev_task_cb=None):
        if after:
            # self.log.debug('Joining previous task')
            val = await after.join()
            if prev_task_cb:
                prev_task_cb(val)
            await RisingEdge(self.dut.clk)

        frame = AxiStreamFrame(pkt)
        if (match_result := self.match(pkt))[0] is not None:
            matched_idx, eom = match_result
            self.log.info(f'Packet #{idx} matches with ctx id {matched_idx}, eom={eom}')

            await self.pop_her(pkt, idx, self.ctxs[matched_idx], eom)
            self.log.debug('Matched packet check finished')
            return True, matched_idx
        else:
            matched_idx, eom = 0, match_result[1]
            self.log.info(f'Packet #{idx} does not match')
            fr = await self.unmatched_sink.recv()
            assert fr == frame, f'mismatched unmatched frame: \n{frame}\nvs received:\n{fr}'

            self.log.debug('Unmatched packet check finished')
            return False, matched_idx

    async def push_pkt(self, pkt, idx):
        frame = AxiStreamFrame(pkt)
        self.log.debug(f'Pushing packet len={len(pkt)}')
        # not setting tid, tdest

        await self.pkt_src.send(frame)
        return await self.check_pkt(pkt, idx)

    async def do_free(self, addr, size):
        self.dut.feedback_her_size.value = size
        self.dut.feedback_her_addr.value = addr
        self.dut.feedback_valid.value = 1
        await RisingEdge(self.dut.clk)
        await WithTimeout(Active(self.dut.feedback_ready))
        await RisingEdge(self.dut.clk)
        self.dut.feedback_valid.value = 0

def load_packets(limit=None):
    if hasattr(load_packets, 'pkts'):
        return load_packets.pkts[:limit]
    else:
        load_packets.pkts = list(map(bytes, rdpcap(pcap_file)))
        return load_packets(limit)

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

async def setup_tb(dut, rule_conf, stall, idle_inserter, backpressure_inserter):
    tb = TB(dut)
    await tb.cycle_reset()

    tb.log.info(f'Setting up test: {rule_conf}, stall={stall}, idle={idle_inserter is not None}, backpressure={backpressure_inserter is not None}')

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    if stall:
        cocotb.start_soon(backpressure_her(dut))

    limit, rule, expected_count = rule_conf

    pkts = load_packets(limit)

    idx = 1
    rule(tb, idx)
    await tb.set_rule()
    await tb.set_ctx(0, default_ctx)   # default ctx has to be set for HER gen to be ready
    await tb.set_ctx(idx, default_ctx)

    return tb, pkts, expected_count


async def run_test_simple(dut, rule_conf, stall=False, idle_inserter=None, backpressure_inserter=None):
    tb, pkts, expected_count = await setup_tb(dut, rule_conf, stall, idle_inserter, backpressure_inserter)

    count = 0
    for idx, p in enumerate(pkts):
        matched, idx = await tb.push_pkt(p, idx + 1)
        count += matched

    assert count == expected_count, 'wrong number of packets matched'

async def run_test_pipelined(dut, rule_conf, stall=False, idle_inserter=None, backpressure_inserter=None):
    tb, pkts, expected_count = await setup_tb(dut, rule_conf, stall, idle_inserter, backpressure_inserter)

    count = 0
    idx = 0
    def proc_result(val):
        nonlocal idx, count
        matched, i = val
        count += matched
        idx = i
    task = None
    for idx, p in enumerate(pkts):
        frame = AxiStreamFrame(p)
        tb.log.debug(f'Pushing packet len={len(p)}')
        await tb.pkt_src.send(frame)

        task = cocotb.start_soon(
            tb.check_pkt(p, idx + 1, after=task,
                         prev_task_cb=proc_result))
    proc_result(await task.join())

    assert count == expected_count, 'wrong number of packets matched'

def cycle_pause():
    # 1 cycle ready in 4 cycles
    return cycle([1, 1, 1, 0])

if cocotb.SIM_NAME:
    for t in [run_test_simple, run_test_pipelined]:
        factory = TestFactory(t)
        factory.add_option('rule_conf', [
            (10, TB.all_bypass, 0),
            (10, TB.all_match, 10),
            (None, lambda tb, idx: TB.tcp_dportnum(tb, idx, 22), 42),
            (None, TB.tcp_or_udp, 69)
        ])
        factory.add_option('stall', [False, True])
        factory.add_option('idle_inserter', [None, cycle_pause])
        factory.add_option('backpressure_inserter', [None, cycle_pause])
        factory.generate_tests()

# cocotb-test
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
