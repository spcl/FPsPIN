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

DUT      = pspin_ctrl_regs
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_reg_if.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_reg_if_wr.v
VERILOG_SOURCES += ../../lib/axi/rtl/axil_reg_if_rd.v

# module parameters
export PARAM_DATA_WIDTH ?= 32
export PARAM_ADDR_WIDTH ?= 16
export PARAM_STRB_WIDTH ?= $(shell expr $(PARAM_DATA_WIDTH) / 8 )
export PARAM_NUM_CLUSTERS ?= 2
export PARAM_NUM_MPQ ?= 16
export PARAM_UMATCH_WIDTH ?= 32
export PARAM_UMATCH_ENTRIES ?= 4
export PARAM_UMATCH_MODES ?= 2
export PARAM_HER_NUM_HANDLER_CTX ?= 4

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).DATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).ADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).STRB_WIDTH=$(PARAM_STRB_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).NUM_CLUSTERS=$(PARAM_NUM_CLUSTERS)
	COMPILE_ARGS += -P $(TOPLEVEL).NUM_MPQ=$(PARAM_NUM_MPQ)
	COMPILE_ARGS += -P $(TOPLEVEL).UMATCH_WIDTH=$(PARAM_UMATCH_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).UMATCH_ENTRIES=$(PARAM_UMATCH_ENTRIES)
	COMPILE_ARGS += -P $(TOPLEVEL).UMATCH_MODES=$(PARAM_UMATCH_MODES)
	COMPILE_ARGS += -P $(TOPLEVEL).HER_NUM_HANDLER_CTX=$(PARAM_HER_NUM_HANDLER_CTX)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GDATA_WIDTH=$(PARAM_DATA_WIDTH)
	COMPILE_ARGS += -GADDR_WIDTH=$(PARAM_ADDR_WIDTH)
	COMPILE_ARGS += -GSTRB_WIDTH=$(PARAM_STRB_WIDTH)
	COMPILE_ARGS += -GNUM_CLUSTERS=$(PARAM_NUM_CLUSTERS)
	COMPILE_ARGS += -GNUM_MPQ=$(PARAM_NUM_MPQ)
	COMPILE_ARGS += -GUMATCH_WIDTH=$(PARAM_UMATCH_WIDTH)
	COMPILE_ARGS += -GUMATCH_ENTRIES=$(PARAM_UMATCH_ENTRIES)
	COMPILE_ARGS += -GUMATCH_MODES=$(PARAM_UMATCH_MODES)
	COMPILE_ARGS += -GHER_NUM_HANDLER_CTX=$(PARAM_HER_NUM_HANDLER_CTX)

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
