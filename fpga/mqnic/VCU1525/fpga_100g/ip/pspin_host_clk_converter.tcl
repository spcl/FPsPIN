
create_ip -name axi_clock_converter -vendor xilinx.com -library ip -module_name pspin_host_clk_converter

set_property -dict [list \
    CONFIG.PROTOCOL {AXI4LITE} \
    CONFIG.ADDR_WIDTH {24} \
    CONFIG.ACLK_ASYNC {1} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.ID_WIDTH {0} \
    CONFIG.AWUSER_WIDTH {0} \
    CONFIG.ARUSER_WIDTH {0} \
    CONFIG.RUSER_WIDTH {0} \
    CONFIG.WUSER_WIDTH {0} \
    CONFIG.BUSER_WIDTH {0}
] [get_ips pspin_host_clk_converter]
