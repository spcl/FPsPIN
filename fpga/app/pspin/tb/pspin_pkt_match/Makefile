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

DUT      = pspin_pkt_match
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_fifo.v

# module parameters
export PARAM_UMATCH_MATCHER_LEN ?= 66
export PARAM_UMATCH_MTU ?= 1500
export PARAM_UMATCH_BUF_FRAMES ?= 3
export PARAM_AXIS_IF_DATA_WIDTH ?= 512
export PARAM_AXIS_IF_KEEP_WIDTH ?= $(shell expr $(PARAM_AXIS_IF_DATA_WIDTH) / 8)
export PARAM_AXIS_IF_RX_ID_WIDTH ?= 1
export PARAM_AXIS_IF_RX_DEST_WIDTH ?= 8
export PARAM_AXIS_IF_RX_USER_WIDTH ?= 97

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).UMATCH_MATCHER_LEN=$(PARAM_UMATCH_MATCHER_LEN)
	COMPILE_ARGS += -P $(TOPLEVEL).UMATCH_MTU=$(PARAM_UMATCH_MTU)
	COMPILE_ARGS += -P $(TOPLEVEL).UMATCH_BUF_FRAMES=$(PARAM_UMATCH_BUF_FRAMES)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_DATA_WIDTH=$(PARAM_AXIS_IF_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_KEEP_WIDTH=$(PARAM_AXIS_IF_KEEP_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_RX_ID_WIDTH=$(PARAM_AXIS_IF_RX_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_RX_DEST_WIDTH=$(PARAM_AXIS_IF_RX_DEST_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_RX_USER_WIDTH=$(PARAM_AXIS_IF_RX_USER_WIDTH)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GUMATCH_MATCHER_LEN=$(PARAM_UMATCH_MATCHER_LEN)
	COMPILE_ARGS += -GUMATCH_MTU=$(PARAM_UMATCH_MTU)
	COMPILE_ARGS += -GUMATCH_BUF_FRAMES=$(PARAM_UMATCH_BUF_FRAMES)
	COMPILE_ARGS += -GAXIS_IF_DATA_WIDTH=$(PARAM_AXIS_IF_DATA_WIDTH)
	COMPILE_ARGS += -GAXIS_IF_KEEP_WIDTH=$(PARAM_AXIS_IF_KEEP_WIDTH)
	COMPILE_ARGS += -GAXIS_IF_RX_ID_WIDTH=$(PARAM_AXIS_IF_RX_ID_WIDTH)
	COMPILE_ARGS += -GAXIS_IF_RX_DEST_WIDTH=$(PARAM_AXIS_IF_RX_DEST_WIDTH)
	COMPILE_ARGS += -GAXIS_IF_RX_USER_WIDTH=$(PARAM_AXIS_IF_RX_USER_WIDTH)

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
