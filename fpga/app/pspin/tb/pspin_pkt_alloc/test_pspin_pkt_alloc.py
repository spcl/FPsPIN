import random
import logging
import os
import itertools
import cocotb, cocotb_test
import pytest
from cocotb.clock import Clock, Timer
from cocotb.triggers import RisingEdge, Edge, First, Join
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from common import *

class TB:
    def __init__(self, dut):
        self.dut = dut

        print(f'Buffer BUF_START {hex(int(self.dut.BUF_START))} BUF_SIZE {hex(int(self.dut.BUF_SIZE))}')

        self.log = logging.getLogger('cocotb.tb')
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 2, units='ns').start())

    async def cycle_reset(self):
        self.dut.write_ready_i.value = 1

        self.dut.rstn.setimmediatevalue(1)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rstn.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rstn.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

    async def enqueue_pkt(self, size, timeout=1000):
        self.dut.pkt_len_i.value = size
        self.dut.pkt_valid_i.value = 1
        tag = random.randint(0, 2**32-1)
        self.dut.pkt_tag_i.value = tag
        # make sure the beat had ready && valid and held for one cycle
        await RisingEdge(self.dut.clk)
        while self.dut.pkt_ready_o == 0 and timeout:
            await RisingEdge(self.dut.clk)
            timeout -= 1
        assert timeout > 0 or self.dut.pkt_ready_o.value == 1
        self.dut.pkt_valid_i.value = 0
        # do not advance clock such that we can allow lat=1 enqueue
        return tag

    async def dequeue_addr(self, timeout=1000):
        # either packet is successfully allocated, or dropped
        allocated = cocotb.start_soon(WithTimeout(Active(self.dut, self.dut.write_valid_o, self.dut.write_ready_i), timeout_ns=timeout))
        dropped = Edge(self.dut.dropped_pkts_o)
        result = await First(Join(allocated), dropped)
        if result is dropped:
            allocated.kill()
            return -1, 0, 0
        allocated.join()
        return self.dut.write_addr_o.value, self.dut.write_len_o.value, self.dut.write_tag_o.value

    async def do_alloc(self, size, timeout=1000):
        deq_task = cocotb.start_soon(self.dequeue_addr())
        expected_tag = await self.enqueue_pkt(size, timeout)
        addr, len, tag = await deq_task.join()
        # returned length should be packet length
        assert int(len) == size or not int(len)
        assert int(addr) + int(len) <= int(self.dut.BUF_START) + int(self.dut.BUF_SIZE)
        if len:
            # only check tag for successfully allocated packet
            assert expected_tag == tag
        return addr, len

    async def do_free(self, addr, size, timeout=100):
        self.dut.feedback_her_size_i.value = size
        self.dut.feedback_her_addr_i.value = addr
        self.dut.feedback_valid_i.value = 1
        await RisingEdge(self.dut.clk)
        while self.dut.feedback_ready_o == 0 and timeout:
            await RisingEdge(self.dut.clk)
            timeout -= 1
        assert timeout > 0 or self.dut.feedback_ready_o.value == 1
        self.dut.feedback_valid_i.value = 0

    async def stall_dma(self, cycles):
        self.dut.write_ready_i.value = 0
        for _ in range(cycles):
            await RisingEdge(self.dut.clk)
        self.dut.write_ready_i.value = 1


async def run_test_alloc(dut, data_in=None, idle_inserter=None, backpressure_inserter=None, max_size=1518):
    tb = TB(dut)
    await tb.cycle_reset()

    for i in range(256):
        if i % 8 == 0:
            cocotb.start_soon(tb.stall_dma(4))
        req_len = 64 * (i+1) # over-sized packets
        addr, length = await tb.do_alloc(req_len)
        if req_len > round_align(max_size) and length:
            assert False, f'should have dropped oversized packet {req_len}, got addr={int(addr):#x} len={int(length)}'

async def run_test_overflow(dut, data_in=None, idle_inserter=None, backpressure_inserter=None, max_size=1518):
    tb = TB(dut)
    await tb.cycle_reset()

    # we have 128K space
    allocated = 0
    for i in range(128):
        try:
            addr, length = await tb.do_alloc(max_size, timeout=10)
        except AssertionError:
            # print('Allocation timed out')
            pass
        else:
            if allocated + max_size > tb.dut.BUF_SIZE.value:
                assert False, f'allocated {allocated} but BUF_SIZE {tb.dut.BUF_SIZE.value}; should fail'
            allocated += length

async def run_test_free(dut, data_in=None, idle_inserter=None, backpressure_inserter=None, max_size=1518):
    tb = TB(dut)
    await tb.cycle_reset()

    async def run_size(s):
        allocated = []
        # repeated alloc & free
        for _ in range(10):
            for i in range(32):
                allocated.append(await tb.do_alloc(s))
            for addr, size in allocated:
                await tb.do_free(addr, size)
            allocated = []

    await run_size(max_size)
    await run_size(120)

if cocotb.SIM_NAME:
    for test in [run_test_alloc, run_test_overflow, run_test_free]:
        factory = TestFactory(test)
        factory.generate_tests()
