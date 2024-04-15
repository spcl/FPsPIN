# Copyright (c) 2023 Alex Forencich
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

# AXI virtual FIFO (raw, write) timing constraints

foreach inst [get_cells -hier -regexp -filter {(ORIG_REF_NAME =~ "axi_vfifo_raw_wr(__xdcDup__\d+)?" || REF_NAME =~ "axi_vfifo_raw_wr(__xdcDup__\d+)?")}] {
    puts "Inserting timing constraints for axi_vfifo_raw_wr instance $inst"

    # get clock periods
    set clk [get_clocks -of_objects [get_cells "$inst/wr_start_ptr_reg_reg[*]"]]
    set input_clk [get_clocks -of_objects [get_cells "$inst/write_fifo_rd_ptr_gray_sync_1_reg_reg[*]"]]

    set clk_period [if {[llength $clk]} {get_property -min PERIOD $clk} {expr 1.0}]
    set input_clk_period [if {[llength $input_clk]} {get_property -min PERIOD $input_clk} {expr 1.0}]

    set min_clk_period [expr min($clk_period, $input_clk_period)]

    # reset synchronization
    set reset_ffs [get_cells -quiet -hier -regexp ".*/rst_sync_\[123\]_reg_reg" -filter "PARENT == $inst"]

    if {[llength $reset_ffs]} {
        set_property ASYNC_REG TRUE $reset_ffs
        set_false_path -to [get_pins -of_objects $reset_ffs -filter {IS_PRESET || IS_RESET}]
    }

    # write FIFO pointer synchronization
    set sync_ffs [get_cells -quiet -hier -regexp ".*/write_fifo_wr_ptr_gray_sync_\[12\]_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]

    if {[llength $sync_ffs]} {
        set_property ASYNC_REG TRUE $sync_ffs

        set_max_delay -from [get_cells "$inst/write_fifo_seg[*].seg_wr_ptr_reg_reg[*] $inst/write_fifo_seg[*].seg_wr_ptr_gray_reg_reg[*]"] -to [get_cells "$inst/write_fifo_wr_ptr_gray_sync_1_reg_reg[*]"] -datapath_only $input_clk_period
        set_bus_skew  -from [get_cells "$inst/write_fifo_seg[*].seg_wr_ptr_reg_reg[*] $inst/write_fifo_seg[*].seg_wr_ptr_gray_reg_reg[*]"] -to [get_cells "$inst/write_fifo_wr_ptr_gray_sync_1_reg_reg[*]"] $clk_period
    }

    set sync_ffs [get_cells -quiet -hier -regexp ".*/write_fifo_rd_ptr_gray_sync_\[12\]_reg_reg\\\[\\d+\\\]" -filter "PARENT == $inst"]

    if {[llength $sync_ffs]} {
        set_property ASYNC_REG TRUE $sync_ffs

        set_max_delay -from [get_cells "$inst/write_fifo_rd_ptr_reg_reg[*] $inst/write_fifo_rd_ptr_gray_reg_reg[*]"] -to [get_cells "$inst/write_fifo_rd_ptr_gray_sync_1_reg_reg[*]"] -datapath_only $clk_period
        set_bus_skew  -from [get_cells "$inst/write_fifo_rd_ptr_reg_reg[*] $inst/write_fifo_rd_ptr_gray_reg_reg[*]"] -to [get_cells "$inst/write_fifo_rd_ptr_gray_sync_1_reg_reg[*]"] $input_clk_period
    }

    # write FIFO output register (needed for distributed RAM sync write/async read)
    set output_reg_ffs [get_cells -quiet "$inst/write_fifo_seg[*].seg_rd_data_reg_reg[*]"]

    if {[llength $output_reg_ffs] && [llength $input_clk]} {
        set_false_path -from $input_clk -to $output_reg_ffs
    }
}
