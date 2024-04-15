
create_ip -name axi_protocol_converter -vendor xilinx.com -library ip -module_name axi_protocol_converter_0

set_property -dict [list \
    CONFIG.SI_PROTOCOL {AXI4LITE} \
    CONFIG.MI_PROTOCOL {AXI4} \
    CONFIG.TRANSLATION_MODE {2} \
    CONFIG.DATA_WIDTH {32}
] [get_ips axi_protocol_converter_0]