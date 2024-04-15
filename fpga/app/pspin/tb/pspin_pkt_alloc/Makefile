# Copyright (c) 2020 Alex Forencich
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

TOPLEVEL_LANG = verilog

SIM ?= icarus
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ns

DUT      = pspin_pkt_alloc
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_fifo.v

# module parameters
export PARAM_LEN_WIDTH ?= 20
export PARAM_TAG_WIDTH ?= 32
export PARAM_ADDR_WIDTH ?= 32
export PARAM_MSGID_WIDTH ?= 10
export PARAM_BUF_START ?= $(shell printf "%d" 0x1c400000)
# smaller packet buffer for easier simulation
export PARAM_BUF_SIZE ?= $(shell expr 128 \* 1024)
export PARAM_PKT_MEM_ALIGNMENT ?= 64
export PARAM_SLOT0_SIZE ?= 1536
export PARAM_SLOT0_COUNT ?= 64
export PARAM_SLOT1_SIZE ?= 256
export PARAM_SLOT1_COUNT ?= 128

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).LEN_WIDTH=$(PARAM_LEN_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).TAG_WIDTH=$(PARAM_TAG_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).ADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).INFLIGHT_WIDTH=$(PARAM_INFLIGHT_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).MSGID_WIDTH=$(PARAM_MSGID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).BUF_START=$(PARAM_BUF_START)
	COMPILE_ARGS += -P $(TOPLEVEL).BUF_SIZE=$(PARAM_BUF_SIZE)
	COMPILE_ARGS += -P $(TOPLEVEL).PKT_MEM_ALIGNMENT=$(PARAM_PKT_MEM_ALIGNMENT)
	COMPILE_ARGS += -P $(TOPLEVEL).SLOT0_SIZE=$(PARAM_SLOT0_SIZE)
	COMPILE_ARGS += -P $(TOPLEVEL).SLOT0_COUNT=$(PARAM_SLOT0_COUNT)
	COMPILE_ARGS += -P $(TOPLEVEL).SLOT1_SIZE=$(PARAM_SLOT1_SIZE)
	COMPILE_ARGS += -P $(TOPLEVEL).SLOT1_COUNT=$(PARAM_SLOT1_COUNT)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GLEN_WIDTH=$(PARAM_LEN_WIDTH)
	COMPILE_ARGS += -GTAG_WIDTH=$(PARAM_TAG_WIDTH)
	COMPILE_ARGS += -GADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	COMPILE_ARGS += -GINFLIGHT_WIDTH=$(PARAM_INFLIGHT_WIDTH)
	COMPILE_ARGS += -GMSGID_WIDTH=$(PARAM_MSGID_WIDTH)
	COMPILE_ARGS += -GBUF_START=$(PARAM_BUF_START)
	COMPILE_ARGS += -GBUF_SIZE=$(PARAM_BUF_SIZE)
	COMPILE_ARGS += -GPKT_MEM_ALIGNMENT=$(PARAM_PKT_MEM_ALIGNMENT)
	COMPILE_ARGS += -GSLOT0_SIZE=$(PARAM_SLOT0_SIZE)
	COMPILE_ARGS += -GSLOT0_COUNT=$(PARAM_SLOT0_COUNT)
	COMPILE_ARGS += -GSLOT1_SIZE=$(PARAM_SLOT1_SIZE)
	COMPILE_ARGS += -GSLOT1_COUNT=$(PARAM_SLOT1_COUNT)

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

iverilog_dump.v:
	echo 'module iverilog_dump();' > $@
	echo 'initial begin' >> $@
	echo '    $$dumpfile("$(TOPLEVEL).fst");' >> $@
	echo '    $$dumpvars(0, $(TOPLEVEL));' >> $@
	echo 'end' >> $@
	echo 'endmodule' >> $@

clean::
	@rm -rf iverilog_dump.v
	@rm -rf dump.fst $(TOPLEVEL).fst
