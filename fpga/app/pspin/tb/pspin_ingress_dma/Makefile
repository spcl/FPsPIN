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

DUT      = pspin_ingress_dma
TOPLEVEL = $(DUT)
MODULE   = test_$(DUT)
VERILOG_SOURCES += ../../rtl/$(DUT).v
VERILOG_SOURCES += ../../lib/axis/rtl/axis_fifo.v
VERILOG_SOURCES += ../../lib/axi/rtl/axi_dma_wr.v

# module parameters
export PARAM_AXIS_IF_DATA_WIDTH ?= 512
export PARAM_AXIS_IF_KEEP_WIDTH ?= $(shell expr $(PARAM_AXIS_IF_DATA_WIDTH) / 8)
export PARAM_AXIS_IF_RX_ID_WIDTH ?= 1
export PARAM_AXIS_IF_RX_DEST_WIDTH ?= 8
export PARAM_AXIS_IF_RX_USER_WIDTH ?= 16
export PARAM_AXI_DATA_WIDTH ?= 512
export PARAM_AXI_ADDR_WIDTH ?= 32
export PARAM_AXI_STRB_WIDTH ?= $(shell expr $(PARAM_AXI_DATA_WIDTH) / 8)
export PARAM_AXI_ID_WIDTH ?= 8
export PARAM_LEN_WIDTH ?= 20
export PARAM_TAG_WIDTH ?= 8
export PARAM_INGRESS_DMA_MTU ?= 1500

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_DATA_WIDTH=$(PARAM_AXIS_IF_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_KEEP_WIDTH=$(PARAM_AXIS_IF_KEEP_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_RX_ID_WIDTH=$(PARAM_AXIS_IF_RX_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_RX_DEST_WIDTH=$(PARAM_AXIS_IF_RX_DEST_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXIS_IF_RX_USER_WIDTH=$(PARAM_AXIS_IF_RX_USER_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_STRB_WIDTH=$(PARAM_AXI_STRB_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).AXI_ID_WIDTH=$(PARAM_AXI_ID_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).LEN_WIDTH=$(PARAM_LEN_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).TAG_WIDTH=$(PARAM_TAG_WIDTH)
	COMPILE_ARGS += -P $(TOPLEVEL).INGRESS_DMA_MTU=$(PARAM_INGRESS_DMA_MTU)

	ifeq ($(WAVES), 1)
		VERILOG_SOURCES += iverilog_dump.v
		COMPILE_ARGS += -s iverilog_dump
	endif
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += -GAXIS_IF_DATA_WIDTH=$(PARAM_AXIS_IF_DATA_WIDTH)
	COMPILE_ARGS += -GAXIS_IF_KEEP_WIDTH=$(PARAM_AXIS_IF_KEEP_WIDTH)
	COMPILE_ARGS += -GAXIS_IF_RX_ID_WIDTH=$(PARAM_AXIS_IF_RX_ID_WIDTH)
	COMPILE_ARGS += -GAXIS_IF_RX_DEST_WIDTH=$(PARAM_AXIS_IF_RX_DEST_WIDTH)
	COMPILE_ARGS += -GAXIS_IF_RX_USER_WIDTH=$(PARAM_AXIS_IF_RX_USER_WIDTH)
	COMPILE_ARGS += -GAXI_DATA_WIDTH=$(PARAM_AXI_DATA_WIDTH)
	COMPILE_ARGS += -GAXI_ADDR_WIDTH=$(PARAM_AXI_ADDR_WIDTH)
	COMPILE_ARGS += -GAXI_STRB_WIDTH=$(PARAM_AXI_STRB_WIDTH)
	COMPILE_ARGS += -GAXI_ID_WIDTH=$(PARAM_AXI_ID_WIDTH)
	COMPILE_ARGS += -GLEN_WIDTH=$(PARAM_LEN_WIDTH)
	COMPILE_ARGS += -GTAG_WIDTH=$(PARAM_TAG_WIDTH)
	COMPILE_ARGS += -GINGRESS_DMA_MTU=$(PARAM_INGRESS_DMA_MTU)

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
