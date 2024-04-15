
create_ip -name axi_clock_converter -vendor xilinx.com -library ip -version 2.1 -module_name pspin_hostdma_clk_converter

set_property -dict [list \
    CONFIG.ADDR_WIDTH {64} \
    CONFIG.DATA_WIDTH {512} \
    CONFIG.ID_WIDTH {8} \
    CONFIG.ACLK_ASYNC {1}
] [get_ips pspin_hostdma_clk_converter]
