import logging
import os
import itertools
from re import A
from tkinter import W
import cocotb, cocotb_test
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster

class TB:
    def __init__(self, dut):
        self.dut = dut
        self.log = logging.getLogger('cocotb.tb')
        self.log.setLevel(logging.DEBUG)

        self.dut.stdout_dout.value = 0
        self.dut.stdout_data_valid.value = 0

        cocotb.start_soon(Clock(dut.clk, 2, units='ns').start())

        self.axil_master = AxiLiteMaster(AxiLiteBus.from_prefix(dut, 's_axil'), dut.clk, dut.rst)

        self.ruleset_count = self.dut.UMATCH_RULESETS.value
        self.rule_count = self.dut.UMATCH_ENTRIES.value

        self.log.info(f'Ruleset count: {self.ruleset_count}')
        self.log.info(f'Rule count: {self.rule_count}')

    def set_idle_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.aw_channel.set_pause_generator(generator())
            self.axil_master.write_if.w_channel.set_pause_generator(generator())
            self.axil_master.read_if.ar_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.b_channel.set_pause_generator(generator())
            self.axil_master.read_if.r_channel.set_pause_generator(generator())

    async def cycle_reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)

async def run_test_regs(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    await tb.cycle_reset()
    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    tb.log.info('Testing cluster enable reg')
    assert tb.dut.cl_fetch_en_o.value == 0b00, 'cluster enable reset value mismatch'

    async def check_single(addr, val, name):
        await tb.axil_master.write_dword(addr, val)
        assert getattr(tb.dut, name).value == val, name + ' mismatch'
        await RisingEdge(dut.clk)

    await check_single(0x0000, 0b11, 'cl_fetch_en_o')
    await check_single(0x0000, 0b00, 'cl_fetch_en_o')

    tb.log.info('Testing reset reg')
    assert tb.dut.aux_rst_o.value == 0b1, 'aux rst reset value mismatch'
    await check_single(0x0004, 0b0, 'aux_rst_o')
    await check_single(0x0004, 0b1, 'aux_rst_o')
    await check_single(0x0004, 0b0, 'aux_rst_o')

    tb.log.info('Testing matching engine reg')
    await check_single(0x2000, 0x1, 'match_valid_o')
    mode_acc = 0
    for j in range(tb.ruleset_count):
        mode_acc += 1 << (j * (tb.dut.UMATCH_MODES.value.bit_length() - 1))
        await tb.axil_master.write_dword(0x2100 + j * 4, 1)
    assert tb.dut.match_mode_o.value == mode_acc

    acc = 0
    for j in range(tb.ruleset_count):
        for i in range(tb.rule_count):
            gid = j * tb.rule_count + i
            acc += (gid << (gid * tb.dut.UMATCH_WIDTH.value))
            await tb.axil_master.write_dword(0x2200 + gid * 4, gid)
            await tb.axil_master.write_dword(0x2300 + gid * 4, gid)
            await tb.axil_master.write_dword(0x2400 + gid * 4, gid)
            await tb.axil_master.write_dword(0x2500 + gid * 4, gid)

    assert tb.dut.match_idx_o.value == acc
    assert tb.dut.match_mask_o.value == acc
    assert tb.dut.match_start_o.value == acc
    assert tb.dut.match_end_o.value == acc

    tb.log.info('Testing HER generation reg')
    await check_single(0x3000, 0x1, 'her_gen_valid')
    acc, wide_acc = 0, 0
    for i in range(tb.dut.HER_NUM_HANDLER_CTX.value):
        acc += (i << (i * 32))
        wide_acc += ((i << 32) + i) << (i * 64)
        await tb.axil_master.write_dword(0x3100 + i * 4, 1) # enabled
        await tb.axil_master.write_dword(0x3200 + i * 4, i)
        await tb.axil_master.write_dword(0x3300 + i * 4, i)
        await tb.axil_master.write_dword(0x3400 + i * 4, i)
        await tb.axil_master.write_dword(0x3500 + i * 4, i)
        await tb.axil_master.write_dword(0x3600 + i * 4, i)
        await tb.axil_master.write_dword(0x3700 + i * 4, i)
        await tb.axil_master.write_dword(0x3800 + i * 4, i)
        await tb.axil_master.write_dword(0x3900 + i * 4, i)
        await tb.axil_master.write_dword(0x3a00 + i * 4, i)
        await tb.axil_master.write_dword(0x3b00 + i * 4, i)
        await tb.axil_master.write_dword(0x3c00 + i * 4, i)
        await tb.axil_master.write_dword(0x3d00 + i * 4, i)
        await tb.axil_master.write_dword(0x3e00 + i * 4, i)
        await tb.axil_master.write_dword(0x3f00 + i * 4, i)
        await tb.axil_master.write_dword(0x4000 + i * 4, i)
        await tb.axil_master.write_dword(0x4100 + i * 4, i)
        await tb.axil_master.write_dword(0x4200 + i * 4, i)
        await tb.axil_master.write_dword(0x4300 + i * 4, i)
        await tb.axil_master.write_dword(0x4400 + i * 4, i)

    for signal in ['handler_mem_addr', 'handler_mem_size',
                   'host_mem_size',
                   'hh_addr', 'hh_size',
                   'ph_addr', 'ph_size',
                   'th_addr', 'th_size',
                   'scratchpad_0_addr', 'scratchpad_0_size',
                   'scratchpad_1_addr', 'scratchpad_1_size',
                   'scratchpad_2_addr', 'scratchpad_2_size',
                   'scratchpad_3_addr', 'scratchpad_3_size',
                   ]:
        assert getattr(tb.dut, f'her_gen_{signal}').value == acc
    assert tb.dut.her_gen_host_mem_addr.value == wide_acc

    tb.log.info('Testing status reg readout')
    tb.dut.cl_eoc_i.value = 0b10
    tb.dut.cl_busy_i.value = 0b11
    tb.dut.mpq_full_i.value = 0xdeadbeef_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff_ffffffff
    tb.dut.alloc_dropped_pkts.value = 1145
    assert await tb.axil_master.read_dword(0x0100) == 0b10
    assert await tb.axil_master.read_dword(0x0104) == 0b11
    assert await tb.axil_master.read_dwords(0x0200, 8) == [0xffffffff] * 7 + [0xdeadbeef]
    assert await tb.axil_master.read_dword(0x2600) == 1145
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

async def run_test_stdout(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)
    await tb.cycle_reset()
    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_data = b'Hello, world!'

    async def fifo_driver(data, start_delay=30):
        for _ in range(start_delay):
            await RisingEdge(tb.dut.clk)
        for c in data:
            print(f'Dequeuing \'{chr(c)}\'')
            tb.dut.stdout_dout.value = c
            tb.dut.stdout_data_valid.value = 1
            await RisingEdge(tb.dut.clk)
            while tb.dut.stdout_rd_en.value != 1 or tb.dut.stdout_data_valid.value != 1:
                await RisingEdge(tb.dut.clk)
            tb.dut.stdout_data_valid.value = 0

    cocotb.start_soon(fifo_driver(test_data))
    data = [await tb.axil_master.read_dword(0x1000) for _ in range(20)]
    data = [chr(x) for x in data if x != 0xffffffff]
    data = ''.join(data)

    print('Data received:')
    print(data)
    
    assert data == test_data.decode()

def cycle_pause():
    return itertools.cycle([1, 1, 0, 0])

if cocotb.SIM_NAME:
    for test in [run_test_regs, run_test_stdout]:
        factory = TestFactory(test)
        factory.add_option('idle_inserter', [None, cycle_pause])
        factory.add_option('backpressure_inserter', [None, cycle_pause])
        factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
axi_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'lib', 'axi', 'rtl'))

@pytest.mark.parametrize('data_width', [32])
def test_pspin_ctrl_regs(request, data_width):
    dut = 'pspin_ctrl_regs'
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    axi_deps = ['axil_reg_if', 'axil_reg_if_rd', 'axil_reg_if_wr']

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.v"),
    ] + [os.path.join(axi_dir, f'{x}.v') for x in axi_deps]

    parameters = {}

    parameters['DATA_WIDTH'] = data_width
    parameters['KEEP_WIDTH'] = parameters['DATA_WIDTH'] // 8

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )