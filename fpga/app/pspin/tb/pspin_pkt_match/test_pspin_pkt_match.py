import logging
import pytest
import os
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
from cocotbext.axi import AxiStreamSource, AxiStreamSink, AxiStreamBus, AxiStreamFrame

# we only use the raw parser
from scapy.utils import rdpcap

from common import *

tests_dir = os.path.dirname(__file__)
pspin_rtl = os.path.join(tests_dir, '..', '..', 'rtl')
axis_lib_rtl = os.path.join(tests_dir, '..', '..', 'lib', 'axis', 'rtl')
# pcap_file = os.path.join(tests_dir, 'sample.pcap')
pcap_file = os.path.join(tests_dir, 'slmp.pcap')

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

class TB:
    def __init__(self, dut):
        self.dut = dut
        self.match_width = self.dut.UMATCH_WIDTH.value
        self.match_count = self.dut.UMATCH_ENTRIES.value
        self.match_modes = self.dut.UMATCH_MODES.value
        self.ruleset_count = self.dut.UMATCH_RULESETS.value

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
        self.matched_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, 'm_axis_pspin_rx'),
                                          dut.clk, dut.rstn, reset_active_level=False)
        # self.matched_sink.log.setLevel(logging.WARNING)

        self.rulesets = [([], MODE_OR) for _ in range(4)]
        for i in range(self.ruleset_count):
            self.all_bypass(i)

    def set_idle_generator(self, generator=None):
        if generator:
            self.log.info('Setting idle generator')
            self.pkt_src.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.log.info('Setting back pressure generator')
            self.unmatched_sink.set_pause_generator(generator())
            self.matched_sink.set_pause_generator(generator())

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
            MatchRule(3, 0xffff0000, 0x0800 << 16, 0x0800 << 16), # IPv4
            MatchRule(5, 0xff, 0x06, 0x06), # proto == TCP
            MatchRule(9, 0xffff0000, dport << 16, dport << 16), # dport
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
    def slmp(self, idx):
        assert self.match_width == 32, 'only support 32-bit match atm'
        self.rulesets[idx] = [
            MatchRule(3, 0xffff0000, 0x0800 << 16, 0x0800 << 16), # IPv4
            MatchRule(5, 0xff, 0x11, 0x11), # proto == UDP
            MatchRule(9, 0xffff0000, 0x24720000, 0x24720000), # dport == 9330 (SLMP)
            MatchRule(10, 0x8000, 0x8000, 0x8000) # SLMP EOM
        ], MODE_OR

    # match packet with ruleset
    def match(self, pkt: bytes):
        self.log.debug(f'Current rulesets:')
        for ru, mo in self.rulesets:
            self.log.debug(f'\t{ru}, mode {mo}')

        if len(pkt) < 48:
            # no SLMP header present
            slmp_msg_id = 0
        else:
            # vectors from Verilog interpreted as little endian
            slmp_msg_id = int.from_bytes(pkt[44:48], byteorder='little')
            self.log.debug(f'SLMP message ID: {slmp_msg_id:#x}')

        match_bytes = self.match_width // 8
        def match_ruleset(idx):
            def match_single(ru: MatchRule):
                r = pkt[ru.idx*match_bytes:ru.idx*match_bytes+match_bytes]
                # big endian
                i = reduce(lambda acc, v: (acc << 8) + v, r, 0)
                im = i & ru.mask
                self.log.debug(f'i={i:#x}\tim={im:#x}\tru.start={ru.start:#x}\tru.end={ru.end:#x}')
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
                return idx, eom, slmp_msg_id
        
        return None, eom, slmp_msg_id

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

    async def push_pkt(self, pkt, id):
        frame = AxiStreamFrame(pkt)
        # not setting tid, tdest

        self.dut.packet_meta_ready.value = 1

        await self.pkt_src.send(frame)
        if (match_result := self.match(pkt))[0] is not None:
            matched_idx, eom, slmp_id = match_result
            self.log.info(f'Packet #{id} matches with ctx id {matched_idx}, eom={eom}')
            sink = self.matched_sink
            ret = True
        else:
            matched_idx, eom = 0, match_result[1]
            self.log.info(f'Packet #{id} does not match')
            sink = self.unmatched_sink
            ret = False
        out: AxiStreamFrame = await WithTimeout(sink.recv())

        await RisingEdge(self.dut.clk)

        if ret:
            assert self.dut.packet_meta_valid.value == 1

            beat_size = self.dut.AXIS_IF_DATA_WIDTH.value // 8
            round_up_len = beat_size * ceil(len(pkt) / beat_size)
            assert self.dut.packet_meta_size.value == round_up_len

            rulesetid_bits = self.ruleset_count.bit_length() - 1
            self.log.debug(f'Tag components: slmp_id={slmp_id:#x}, eom={eom}, matched_idx={matched_idx}')
            tag = matched_idx + (eom << rulesetid_bits) + (slmp_id << (rulesetid_bits + 1))
            assert self.dut.packet_meta_tag.value == tag
        else:
            assert self.dut.packet_meta_valid.value == 0

        assert frame == out, f'mismatched frame:\n{frame}\nvs received:\n{out}'
        return ret, matched_idx

def load_packets(limit=None):
    if hasattr(load_packets, 'pkts'):
        return load_packets.pkts[:limit]
    else:
        load_packets.pkts = list(map(bytes, rdpcap(pcap_file)))
        return load_packets(limit)

async def run_test_rule(dut, rule_conf, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    limit, rule, expected_count = rule_conf

    pkts = load_packets(limit)
    count = 0

    rule(tb, 1)
    await tb.set_rule()
    for idx, p in enumerate(pkts):
        count += (await tb.push_pkt(p, idx))[0]
    assert count == expected_count, 'wrong number of packets matched'

async def run_test_switch_rule(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    pkts = load_packets(10)
    expected_count, count = 10, 0

    tb.all_bypass(2)
    await tb.set_rule()
    for idx, p in enumerate(pkts):
        count += (await tb.push_pkt(p, idx))[0]

    tb.all_match(2)
    await tb.set_rule()
    for p in pkts:
        idx += 1
        count += (await tb.push_pkt(p, idx))[0]
    assert count == expected_count, 'wrong number of packets matched'

async def run_test_simultaneous_rule(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    pkts = load_packets(10)
    expected_count, count = 10, 0

    # the TCP rule takes precedence
    expected_tcps, tcps = [2, 4, 5, 7, 10], []
    tb.tcp_dportnum(1, 22)
    tb.all_match(2)
    await tb.set_rule()
    for idx, p in enumerate(pkts):
        dc, matched_tag = await tb.push_pkt(p, idx)
        count += dc
        if matched_tag == 1:
            tcps.append(idx + 1)

    assert count == expected_count, 'wrong number of packets matched'
    assert tcps == expected_tcps, 'tcp packets idx mismatch'

# TODO: test packet alloc back pressure

def cycle_pause():
    # 1 cycle ready in 4 cycles
    return cycle([1, 1, 1, 0])

if cocotb.SIM_NAME:
    factory = TestFactory(run_test_rule)
    factory.add_option('rule_conf', [
        # (10, TB.all_bypass, 0),
        # (10, TB.all_match, 10),
        # (None, lambda tb, idx: TB.tcp_dportnum(tb, idx, 22), 42),
        # (None, TB.tcp_or_udp, 69),
        (None, TB.slmp, 39),
    ])
    factory.add_option('idle_inserter', [None, cycle_pause])
    factory.add_option('backpressure_inserter', [None, cycle_pause])
    factory.generate_tests()

    # factory = TestFactory(run_test_switch_rule)
    # factory.generate_tests()

    # factory = TestFactory(run_test_simultaneous_rule)
    # factory.generate_tests()

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
