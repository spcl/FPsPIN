
create_ip -name axi_dwidth_converter -vendor xilinx.com -library ip -module_name axi_dwidth_converter_0

set_property -dict [list \
    CONFIG.MI_DATA_WIDTH {512}
] [get_ips axi_dwidth_converter_0]