{% import "verilog-macros.j2" as m with context -%}
/*

Copyright 2021, The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE REGENTS OF THE UNIVERSITY OF CALIFORNIA ''AS
IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS OF THE UNIVERSITY OF CALIFORNIA OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of The Regents of the University of California.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

`define SLICE(arr, idx, width) arr[(idx)*(width) +: width]

/*
 * Application block
 */
module mqnic_app_block #
(
    // Structural configuration
    parameter IF_COUNT = 1,
    parameter PORTS_PER_IF = 1,
    parameter SCHED_PER_IF = PORTS_PER_IF,

    parameter PORT_COUNT = IF_COUNT*PORTS_PER_IF,

    // Clock configuration
    parameter CLK_PERIOD_NS_NUM = 4,
    parameter CLK_PERIOD_NS_DENOM = 1,

    // PTP configuration
    parameter PTP_CLK_PERIOD_NS_NUM = 4,
    parameter PTP_CLK_PERIOD_NS_DENOM = 1,
    parameter PTP_TS_WIDTH = 96,
    parameter PTP_USE_SAMPLE_CLOCK = 0,
    parameter PTP_PORT_CDC_PIPELINE = 0,
    parameter PTP_PEROUT_ENABLE = 0,
    parameter PTP_PEROUT_COUNT = 1,

    // Interface configuration
    parameter PTP_TS_ENABLE = 1,
    parameter TX_TAG_WIDTH = 16,
    parameter MAX_TX_SIZE = 9214,
    parameter MAX_RX_SIZE = 9214,

    // RAM configuration
    parameter DDR_CH = 1,
    parameter DDR_ENABLE = 0,
    parameter DDR_GROUP_SIZE = 1,
    parameter AXI_DDR_DATA_WIDTH = 256,
    parameter AXI_DDR_ADDR_WIDTH = 32,
    parameter AXI_DDR_STRB_WIDTH = (AXI_DDR_DATA_WIDTH/8),
    parameter AXI_DDR_ID_WIDTH = 8,
    parameter AXI_DDR_AWUSER_ENABLE = 0,
    parameter AXI_DDR_AWUSER_WIDTH = 1,
    parameter AXI_DDR_WUSER_ENABLE = 0,
    parameter AXI_DDR_WUSER_WIDTH = 1,
    parameter AXI_DDR_BUSER_ENABLE = 0,
    parameter AXI_DDR_BUSER_WIDTH = 1,
    parameter AXI_DDR_ARUSER_ENABLE = 0,
    parameter AXI_DDR_ARUSER_WIDTH = 1,
    parameter AXI_DDR_RUSER_ENABLE = 0,
    parameter AXI_DDR_RUSER_WIDTH = 1,
    parameter AXI_DDR_MAX_BURST_LEN = 256,
    parameter AXI_DDR_NARROW_BURST = 0,
    parameter AXI_DDR_FIXED_BURST = 0,
    parameter AXI_DDR_WRAP_BURST = 0,
    parameter HBM_CH = 1,
    parameter HBM_ENABLE = 0,
    parameter HBM_GROUP_SIZE = 1,
    parameter AXI_HBM_DATA_WIDTH = 256,
    parameter AXI_HBM_ADDR_WIDTH = 32,
    parameter AXI_HBM_STRB_WIDTH = (AXI_HBM_DATA_WIDTH/8),
    parameter AXI_HBM_ID_WIDTH = 8,
    parameter AXI_HBM_AWUSER_ENABLE = 0,
    parameter AXI_HBM_AWUSER_WIDTH = 1,
    parameter AXI_HBM_WUSER_ENABLE = 0,
    parameter AXI_HBM_WUSER_WIDTH = 1,
    parameter AXI_HBM_BUSER_ENABLE = 0,
    parameter AXI_HBM_BUSER_WIDTH = 1,
    parameter AXI_HBM_ARUSER_ENABLE = 0,
    parameter AXI_HBM_ARUSER_WIDTH = 1,
    parameter AXI_HBM_RUSER_ENABLE = 0,
    parameter AXI_HBM_RUSER_WIDTH = 1,
    parameter AXI_HBM_MAX_BURST_LEN = 256,
    parameter AXI_HBM_NARROW_BURST = 0,
    parameter AXI_HBM_FIXED_BURST = 0,
    parameter AXI_HBM_WRAP_BURST = 0,

    // Application configuration
    parameter APP_ID = 32'h12340100,
    parameter APP_CTRL_ENABLE = 1,
    parameter APP_DMA_ENABLE = 1,
    parameter APP_AXIS_DIRECT_ENABLE = 0,
    parameter APP_AXIS_SYNC_ENABLE = 0,
    parameter APP_AXIS_IF_ENABLE = 1,
    parameter APP_STAT_ENABLE = 1,
    parameter APP_GPIO_IN_WIDTH = 32,
    parameter APP_GPIO_OUT_WIDTH = 32,

    // DMA interface configuration
    parameter DMA_ADDR_WIDTH = 64,
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_SEL_WIDTH = 4,
    parameter RAM_ADDR_WIDTH = 16,
    parameter RAM_SEG_COUNT = 2,
    parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH),
    parameter RAM_PIPELINE = 2,

    // AXI lite interface (application control from host)
    parameter AXIL_APP_CTRL_DATA_WIDTH = 32,
    parameter AXIL_APP_CTRL_ADDR_WIDTH = 16,
    parameter AXIL_APP_CTRL_STRB_WIDTH = (AXIL_APP_CTRL_DATA_WIDTH/8),

    // AXI lite interface (control to NIC)
    parameter AXIL_CTRL_DATA_WIDTH = 32,
    parameter AXIL_CTRL_ADDR_WIDTH = 16,
    parameter AXIL_CTRL_STRB_WIDTH = (AXIL_CTRL_DATA_WIDTH/8),

    // Ethernet interface configuration (direct, async)
    parameter AXIS_DATA_WIDTH = 512,
    parameter AXIS_KEEP_WIDTH = AXIS_DATA_WIDTH/8,
    parameter AXIS_TX_USER_WIDTH = TX_TAG_WIDTH + 1,
    parameter AXIS_RX_USER_WIDTH = (PTP_TS_ENABLE ? PTP_TS_WIDTH : 0) + 1,
    parameter AXIS_RX_USE_READY = 0,

    // Ethernet interface configuration (direct, sync)
    parameter AXIS_SYNC_DATA_WIDTH = AXIS_DATA_WIDTH,
    parameter AXIS_SYNC_KEEP_WIDTH = AXIS_SYNC_DATA_WIDTH/8,
    parameter AXIS_SYNC_TX_USER_WIDTH = AXIS_TX_USER_WIDTH,
    parameter AXIS_SYNC_RX_USER_WIDTH = AXIS_RX_USER_WIDTH,

    // Ethernet interface configuration (interface)
    parameter AXIS_IF_DATA_WIDTH = AXIS_SYNC_DATA_WIDTH*2**$clog2(PORTS_PER_IF),
    parameter AXIS_IF_KEEP_WIDTH = AXIS_IF_DATA_WIDTH/8,
    parameter AXIS_IF_TX_ID_WIDTH = 12,
    parameter AXIS_IF_RX_ID_WIDTH = PORTS_PER_IF > 1 ? $clog2(PORTS_PER_IF) : 1,
    parameter AXIS_IF_TX_DEST_WIDTH = $clog2(PORTS_PER_IF)+4,
    parameter AXIS_IF_RX_DEST_WIDTH = 8,
    parameter AXIS_IF_TX_USER_WIDTH = AXIS_SYNC_TX_USER_WIDTH,
    parameter AXIS_IF_RX_USER_WIDTH = AXIS_SYNC_RX_USER_WIDTH,

    // Statistics counter subsystem
    parameter STAT_ENABLE = 1,
    parameter STAT_INC_WIDTH = 24,
    parameter STAT_ID_WIDTH = 12
)
(
    input  wire                                           clk,
    input  wire                                           rst,

    /*
     * AXI-Lite slave interface (control from host)
     */
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]            s_axil_app_ctrl_awaddr,
    input  wire [2:0]                                     s_axil_app_ctrl_awprot,
    input  wire                                           s_axil_app_ctrl_awvalid,
    output wire                                           s_axil_app_ctrl_awready,
    input  wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]            s_axil_app_ctrl_wdata,
    input  wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]            s_axil_app_ctrl_wstrb,
    input  wire                                           s_axil_app_ctrl_wvalid,
    output wire                                           s_axil_app_ctrl_wready,
    output wire [1:0]                                     s_axil_app_ctrl_bresp,
    output wire                                           s_axil_app_ctrl_bvalid,
    input  wire                                           s_axil_app_ctrl_bready,
    input  wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]            s_axil_app_ctrl_araddr,
    input  wire [2:0]                                     s_axil_app_ctrl_arprot,
    input  wire                                           s_axil_app_ctrl_arvalid,
    output wire                                           s_axil_app_ctrl_arready,
    output wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]            s_axil_app_ctrl_rdata,
    output wire [1:0]                                     s_axil_app_ctrl_rresp,
    output wire                                           s_axil_app_ctrl_rvalid,
    input  wire                                           s_axil_app_ctrl_rready,

    /*
     * AXI-Lite master interface (control to NIC)
     */
    output wire [AXIL_CTRL_ADDR_WIDTH-1:0]                m_axil_ctrl_awaddr,
    output wire [2:0]                                     m_axil_ctrl_awprot,
    output wire                                           m_axil_ctrl_awvalid,
    input  wire                                           m_axil_ctrl_awready,
    output wire [AXIL_CTRL_DATA_WIDTH-1:0]                m_axil_ctrl_wdata,
    output wire [AXIL_CTRL_STRB_WIDTH-1:0]                m_axil_ctrl_wstrb,
    output wire                                           m_axil_ctrl_wvalid,
    input  wire                                           m_axil_ctrl_wready,
    input  wire [1:0]                                     m_axil_ctrl_bresp,
    input  wire                                           m_axil_ctrl_bvalid,
    output wire                                           m_axil_ctrl_bready,
    output wire [AXIL_CTRL_ADDR_WIDTH-1:0]                m_axil_ctrl_araddr,
    output wire [2:0]                                     m_axil_ctrl_arprot,
    output wire                                           m_axil_ctrl_arvalid,
    input  wire                                           m_axil_ctrl_arready,
    input  wire [AXIL_CTRL_DATA_WIDTH-1:0]                m_axil_ctrl_rdata,
    input  wire [1:0]                                     m_axil_ctrl_rresp,
    input  wire                                           m_axil_ctrl_rvalid,
    output wire                                           m_axil_ctrl_rready,

    /*
     * DMA read descriptor output (control)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                      m_axis_ctrl_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_ctrl_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_ctrl_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_ctrl_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_ctrl_dma_read_desc_tag,
    output wire                                           m_axis_ctrl_dma_read_desc_valid,
    input  wire                                           m_axis_ctrl_dma_read_desc_ready,

    /*
     * DMA read descriptor status input (control)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_ctrl_dma_read_desc_status_tag,
    input  wire [3:0]                                     s_axis_ctrl_dma_read_desc_status_error,
    input  wire                                           s_axis_ctrl_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output (control)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                      m_axis_ctrl_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_ctrl_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_ctrl_dma_write_desc_ram_addr,
    output wire [DMA_IMM_WIDTH-1:0]                       m_axis_ctrl_dma_write_desc_imm,
    output wire                                           m_axis_ctrl_dma_write_desc_imm_en,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_ctrl_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_ctrl_dma_write_desc_tag,
    output wire                                           m_axis_ctrl_dma_write_desc_valid,
    input  wire                                           m_axis_ctrl_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (control)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_ctrl_dma_write_desc_status_tag,
    input  wire [3:0]                                     s_axis_ctrl_dma_write_desc_status_error,
    input  wire                                           s_axis_ctrl_dma_write_desc_status_valid,

    /*
     * DMA read descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                      m_axis_data_dma_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_data_dma_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_data_dma_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_data_dma_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_data_dma_read_desc_tag,
    output wire                                           m_axis_data_dma_read_desc_valid,
    input  wire                                           m_axis_data_dma_read_desc_ready,

    /*
     * DMA read descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_data_dma_read_desc_status_tag,
    input  wire [3:0]                                     s_axis_data_dma_read_desc_status_error,
    input  wire                                           s_axis_data_dma_read_desc_status_valid,

    /*
     * DMA write descriptor output (data)
     */
    output wire [DMA_ADDR_WIDTH-1:0]                      m_axis_data_dma_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_data_dma_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_data_dma_write_desc_ram_addr,
    output wire [DMA_IMM_WIDTH-1:0]                       m_axis_data_dma_write_desc_imm,
    output wire                                           m_axis_data_dma_write_desc_imm_en,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_data_dma_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_data_dma_write_desc_tag,
    output wire                                           m_axis_data_dma_write_desc_valid,
    input  wire                                           m_axis_data_dma_write_desc_ready,

    /*
     * DMA write descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_data_dma_write_desc_status_tag,
    input  wire [3:0]                                     s_axis_data_dma_write_desc_status_error,
    input  wire                                           s_axis_data_dma_write_desc_status_valid,

    /*
     * DMA RAM interface (control)
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]         ctrl_dma_ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]      ctrl_dma_ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    ctrl_dma_ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    ctrl_dma_ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_wr_done,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]         ctrl_dma_ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    ctrl_dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    ctrl_dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                       ctrl_dma_ram_rd_resp_ready,

    /*
     * DMA RAM interface (data)
     */
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]         data_dma_ram_wr_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]      data_dma_ram_wr_cmd_be,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    data_dma_ram_wr_cmd_addr,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    data_dma_ram_wr_cmd_data,
    input  wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_wr_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_wr_cmd_ready,
    output wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_wr_done,
    input  wire [RAM_SEG_COUNT*RAM_SEL_WIDTH-1:0]         data_dma_ram_rd_cmd_sel,
    input  wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    data_dma_ram_rd_cmd_addr,
    input  wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_rd_cmd_valid,
    output wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_rd_cmd_ready,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    data_dma_ram_rd_resp_data,
    output wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_rd_resp_valid,
    input  wire [RAM_SEG_COUNT-1:0]                       data_dma_ram_rd_resp_ready,

    /*
     * PTP clock
     */
    input  wire                                           ptp_clk,
    input  wire                                           ptp_rst,
    input  wire                                           ptp_sample_clk,
    input  wire                                           ptp_pps,
    input  wire                                           ptp_pps_str,
    input  wire [PTP_TS_WIDTH-1:0]                        ptp_ts_96,
    input  wire                                           ptp_ts_step,
    input  wire                                           ptp_sync_pps,
    input  wire [PTP_TS_WIDTH-1:0]                        ptp_sync_ts_96,
    input  wire                                           ptp_sync_ts_step,
    input  wire [PTP_PEROUT_COUNT-1:0]                    ptp_perout_locked,
    input  wire [PTP_PEROUT_COUNT-1:0]                    ptp_perout_error,
    input  wire [PTP_PEROUT_COUNT-1:0]                    ptp_perout_pulse,

    /*
     * Ethernet (direct MAC interface - lowest latency raw traffic)
     */
    input  wire [PORT_COUNT-1:0]                          direct_tx_clk,
    input  wire [PORT_COUNT-1:0]                          direct_tx_rst,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]          s_axis_direct_tx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]          s_axis_direct_tx_tkeep,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_tx_tvalid,
    output wire [PORT_COUNT-1:0]                          s_axis_direct_tx_tready,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_tx_tlast,
    input  wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]       s_axis_direct_tx_tuser,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]          m_axis_direct_tx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]          m_axis_direct_tx_tkeep,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                          m_axis_direct_tx_tready,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_tx_tlast,
    output wire [PORT_COUNT*AXIS_TX_USER_WIDTH-1:0]       m_axis_direct_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]             s_axis_direct_tx_cpl_ts,
    input  wire [PORT_COUNT*TX_TAG_WIDTH-1:0]             s_axis_direct_tx_cpl_tag,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_tx_cpl_valid,
    output wire [PORT_COUNT-1:0]                          s_axis_direct_tx_cpl_ready,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]             m_axis_direct_tx_cpl_ts,
    output wire [PORT_COUNT*TX_TAG_WIDTH-1:0]             m_axis_direct_tx_cpl_tag,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_tx_cpl_valid,
    input  wire [PORT_COUNT-1:0]                          m_axis_direct_tx_cpl_ready,

    input  wire [PORT_COUNT-1:0]                          direct_rx_clk,
    input  wire [PORT_COUNT-1:0]                          direct_rx_rst,

    input  wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]          s_axis_direct_rx_tdata,
    input  wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]          s_axis_direct_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_rx_tvalid,
    output wire [PORT_COUNT-1:0]                          s_axis_direct_rx_tready,
    input  wire [PORT_COUNT-1:0]                          s_axis_direct_rx_tlast,
    input  wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]       s_axis_direct_rx_tuser,

    output wire [PORT_COUNT*AXIS_DATA_WIDTH-1:0]          m_axis_direct_rx_tdata,
    output wire [PORT_COUNT*AXIS_KEEP_WIDTH-1:0]          m_axis_direct_rx_tkeep,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_rx_tvalid,
    input  wire [PORT_COUNT-1:0]                          m_axis_direct_rx_tready,
    output wire [PORT_COUNT-1:0]                          m_axis_direct_rx_tlast,
    output wire [PORT_COUNT*AXIS_RX_USER_WIDTH-1:0]       m_axis_direct_rx_tuser,

    /*
     * Ethernet (synchronous MAC interface - low latency raw traffic)
     */
    input  wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]     s_axis_sync_tx_tdata,
    input  wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]     s_axis_sync_tx_tkeep,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_tx_tvalid,
    output wire [PORT_COUNT-1:0]                          s_axis_sync_tx_tready,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_tx_tlast,
    input  wire [PORT_COUNT*AXIS_SYNC_TX_USER_WIDTH-1:0]  s_axis_sync_tx_tuser,

    output wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]     m_axis_sync_tx_tdata,
    output wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]     m_axis_sync_tx_tkeep,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_tx_tvalid,
    input  wire [PORT_COUNT-1:0]                          m_axis_sync_tx_tready,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_tx_tlast,
    output wire [PORT_COUNT*AXIS_SYNC_TX_USER_WIDTH-1:0]  m_axis_sync_tx_tuser,

    input  wire [PORT_COUNT*PTP_TS_WIDTH-1:0]             s_axis_sync_tx_cpl_ts,
    input  wire [PORT_COUNT*TX_TAG_WIDTH-1:0]             s_axis_sync_tx_cpl_tag,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_tx_cpl_valid,
    output wire [PORT_COUNT-1:0]                          s_axis_sync_tx_cpl_ready,

    output wire [PORT_COUNT*PTP_TS_WIDTH-1:0]             m_axis_sync_tx_cpl_ts,
    output wire [PORT_COUNT*TX_TAG_WIDTH-1:0]             m_axis_sync_tx_cpl_tag,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_tx_cpl_valid,
    input  wire [PORT_COUNT-1:0]                          m_axis_sync_tx_cpl_ready,

    input  wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]     s_axis_sync_rx_tdata,
    input  wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]     s_axis_sync_rx_tkeep,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_rx_tvalid,
    output wire [PORT_COUNT-1:0]                          s_axis_sync_rx_tready,
    input  wire [PORT_COUNT-1:0]                          s_axis_sync_rx_tlast,
    input  wire [PORT_COUNT*AXIS_SYNC_RX_USER_WIDTH-1:0]  s_axis_sync_rx_tuser,

    output wire [PORT_COUNT*AXIS_SYNC_DATA_WIDTH-1:0]     m_axis_sync_rx_tdata,
    output wire [PORT_COUNT*AXIS_SYNC_KEEP_WIDTH-1:0]     m_axis_sync_rx_tkeep,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_rx_tvalid,
    input  wire [PORT_COUNT-1:0]                          m_axis_sync_rx_tready,
    output wire [PORT_COUNT-1:0]                          m_axis_sync_rx_tlast,
    output wire [PORT_COUNT*AXIS_SYNC_RX_USER_WIDTH-1:0]  m_axis_sync_rx_tuser,

    /*
     * Ethernet (internal at interface module)
     */
    input  wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]         s_axis_if_tx_tdata,
    input  wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]         s_axis_if_tx_tkeep,
    input  wire [IF_COUNT-1:0]                            s_axis_if_tx_tvalid,
    output wire [IF_COUNT-1:0]                            s_axis_if_tx_tready,
    input  wire [IF_COUNT-1:0]                            s_axis_if_tx_tlast,
    input  wire [IF_COUNT*AXIS_IF_TX_ID_WIDTH-1:0]        s_axis_if_tx_tid,
    input  wire [IF_COUNT*AXIS_IF_TX_DEST_WIDTH-1:0]      s_axis_if_tx_tdest,
    input  wire [IF_COUNT*AXIS_IF_TX_USER_WIDTH-1:0]      s_axis_if_tx_tuser,

    output wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]         m_axis_if_tx_tdata,
    output wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]         m_axis_if_tx_tkeep,
    output wire [IF_COUNT-1:0]                            m_axis_if_tx_tvalid,
    input  wire [IF_COUNT-1:0]                            m_axis_if_tx_tready,
    output wire [IF_COUNT-1:0]                            m_axis_if_tx_tlast,
    output wire [IF_COUNT*AXIS_IF_TX_ID_WIDTH-1:0]        m_axis_if_tx_tid,
    output wire [IF_COUNT*AXIS_IF_TX_DEST_WIDTH-1:0]      m_axis_if_tx_tdest,
    output wire [IF_COUNT*AXIS_IF_TX_USER_WIDTH-1:0]      m_axis_if_tx_tuser,

    input  wire [IF_COUNT*PTP_TS_WIDTH-1:0]               s_axis_if_tx_cpl_ts,
    input  wire [IF_COUNT*TX_TAG_WIDTH-1:0]               s_axis_if_tx_cpl_tag,
    input  wire [IF_COUNT-1:0]                            s_axis_if_tx_cpl_valid,
    output wire [IF_COUNT-1:0]                            s_axis_if_tx_cpl_ready,

    output wire [IF_COUNT*PTP_TS_WIDTH-1:0]               m_axis_if_tx_cpl_ts,
    output wire [IF_COUNT*TX_TAG_WIDTH-1:0]               m_axis_if_tx_cpl_tag,
    output wire [IF_COUNT-1:0]                            m_axis_if_tx_cpl_valid,
    input  wire [IF_COUNT-1:0]                            m_axis_if_tx_cpl_ready,

    input  wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]         s_axis_if_rx_tdata,
    input  wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]         s_axis_if_rx_tkeep,
    input  wire [IF_COUNT-1:0]                            s_axis_if_rx_tvalid,
    output wire [IF_COUNT-1:0]                            s_axis_if_rx_tready,
    input  wire [IF_COUNT-1:0]                            s_axis_if_rx_tlast,
    input  wire [IF_COUNT*AXIS_IF_RX_ID_WIDTH-1:0]        s_axis_if_rx_tid,
    input  wire [IF_COUNT*AXIS_IF_RX_DEST_WIDTH-1:0]      s_axis_if_rx_tdest,
    input  wire [IF_COUNT*AXIS_IF_RX_USER_WIDTH-1:0]      s_axis_if_rx_tuser,

    output wire [IF_COUNT*AXIS_IF_DATA_WIDTH-1:0]         m_axis_if_rx_tdata,
    output wire [IF_COUNT*AXIS_IF_KEEP_WIDTH-1:0]         m_axis_if_rx_tkeep,
    output wire [IF_COUNT-1:0]                            m_axis_if_rx_tvalid,
    input  wire [IF_COUNT-1:0]                            m_axis_if_rx_tready,
    output wire [IF_COUNT-1:0]                            m_axis_if_rx_tlast,
    output wire [IF_COUNT*AXIS_IF_RX_ID_WIDTH-1:0]        m_axis_if_rx_tid,
    output wire [IF_COUNT*AXIS_IF_RX_DEST_WIDTH-1:0]      m_axis_if_rx_tdest,
    output wire [IF_COUNT*AXIS_IF_RX_USER_WIDTH-1:0]      m_axis_if_rx_tuser,

    /*
     * DDR
     */
    input  wire [DDR_CH-1:0]                              ddr_clk,
    input  wire [DDR_CH-1:0]                              ddr_rst,

    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]             m_axi_ddr_awid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]           m_axi_ddr_awaddr,
    output wire [DDR_CH*8-1:0]                            m_axi_ddr_awlen,
    output wire [DDR_CH*3-1:0]                            m_axi_ddr_awsize,
    output wire [DDR_CH*2-1:0]                            m_axi_ddr_awburst,
    output wire [DDR_CH-1:0]                              m_axi_ddr_awlock,
    output wire [DDR_CH*4-1:0]                            m_axi_ddr_awcache,
    output wire [DDR_CH*3-1:0]                            m_axi_ddr_awprot,
    output wire [DDR_CH*4-1:0]                            m_axi_ddr_awqos,
    output wire [DDR_CH*AXI_DDR_AWUSER_WIDTH-1:0]         m_axi_ddr_awuser,
    output wire [DDR_CH-1:0]                              m_axi_ddr_awvalid,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_awready,
    output wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]           m_axi_ddr_wdata,
    output wire [DDR_CH*AXI_DDR_STRB_WIDTH-1:0]           m_axi_ddr_wstrb,
    output wire [DDR_CH-1:0]                              m_axi_ddr_wlast,
    output wire [DDR_CH*AXI_DDR_WUSER_WIDTH-1:0]          m_axi_ddr_wuser,
    output wire [DDR_CH-1:0]                              m_axi_ddr_wvalid,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_wready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]             m_axi_ddr_bid,
    input  wire [DDR_CH*2-1:0]                            m_axi_ddr_bresp,
    input  wire [DDR_CH*AXI_DDR_BUSER_WIDTH-1:0]          m_axi_ddr_buser,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_bvalid,
    output wire [DDR_CH-1:0]                              m_axi_ddr_bready,
    output wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]             m_axi_ddr_arid,
    output wire [DDR_CH*AXI_DDR_ADDR_WIDTH-1:0]           m_axi_ddr_araddr,
    output wire [DDR_CH*8-1:0]                            m_axi_ddr_arlen,
    output wire [DDR_CH*3-1:0]                            m_axi_ddr_arsize,
    output wire [DDR_CH*2-1:0]                            m_axi_ddr_arburst,
    output wire [DDR_CH-1:0]                              m_axi_ddr_arlock,
    output wire [DDR_CH*4-1:0]                            m_axi_ddr_arcache,
    output wire [DDR_CH*3-1:0]                            m_axi_ddr_arprot,
    output wire [DDR_CH*4-1:0]                            m_axi_ddr_arqos,
    output wire [DDR_CH*AXI_DDR_ARUSER_WIDTH-1:0]         m_axi_ddr_aruser,
    output wire [DDR_CH-1:0]                              m_axi_ddr_arvalid,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_arready,
    input  wire [DDR_CH*AXI_DDR_ID_WIDTH-1:0]             m_axi_ddr_rid,
    input  wire [DDR_CH*AXI_DDR_DATA_WIDTH-1:0]           m_axi_ddr_rdata,
    input  wire [DDR_CH*2-1:0]                            m_axi_ddr_rresp,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_rlast,
    input  wire [DDR_CH*AXI_DDR_RUSER_WIDTH-1:0]          m_axi_ddr_ruser,
    input  wire [DDR_CH-1:0]                              m_axi_ddr_rvalid,
    output wire [DDR_CH-1:0]                              m_axi_ddr_rready,

    input  wire [DDR_CH-1:0]                              ddr_status,

    /*
     * HBM
     */
    input  wire [HBM_CH-1:0]                              hbm_clk,
    input  wire [HBM_CH-1:0]                              hbm_rst,

    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]             m_axi_hbm_awid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]           m_axi_hbm_awaddr,
    output wire [HBM_CH*8-1:0]                            m_axi_hbm_awlen,
    output wire [HBM_CH*3-1:0]                            m_axi_hbm_awsize,
    output wire [HBM_CH*2-1:0]                            m_axi_hbm_awburst,
    output wire [HBM_CH-1:0]                              m_axi_hbm_awlock,
    output wire [HBM_CH*4-1:0]                            m_axi_hbm_awcache,
    output wire [HBM_CH*3-1:0]                            m_axi_hbm_awprot,
    output wire [HBM_CH*4-1:0]                            m_axi_hbm_awqos,
    output wire [HBM_CH*AXI_HBM_AWUSER_WIDTH-1:0]         m_axi_hbm_awuser,
    output wire [HBM_CH-1:0]                              m_axi_hbm_awvalid,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_awready,
    output wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]           m_axi_hbm_wdata,
    output wire [HBM_CH*AXI_HBM_STRB_WIDTH-1:0]           m_axi_hbm_wstrb,
    output wire [HBM_CH-1:0]                              m_axi_hbm_wlast,
    output wire [HBM_CH*AXI_HBM_WUSER_WIDTH-1:0]          m_axi_hbm_wuser,
    output wire [HBM_CH-1:0]                              m_axi_hbm_wvalid,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_wready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]             m_axi_hbm_bid,
    input  wire [HBM_CH*2-1:0]                            m_axi_hbm_bresp,
    input  wire [HBM_CH*AXI_HBM_BUSER_WIDTH-1:0]          m_axi_hbm_buser,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_bvalid,
    output wire [HBM_CH-1:0]                              m_axi_hbm_bready,
    output wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]             m_axi_hbm_arid,
    output wire [HBM_CH*AXI_HBM_ADDR_WIDTH-1:0]           m_axi_hbm_araddr,
    output wire [HBM_CH*8-1:0]                            m_axi_hbm_arlen,
    output wire [HBM_CH*3-1:0]                            m_axi_hbm_arsize,
    output wire [HBM_CH*2-1:0]                            m_axi_hbm_arburst,
    output wire [HBM_CH-1:0]                              m_axi_hbm_arlock,
    output wire [HBM_CH*4-1:0]                            m_axi_hbm_arcache,
    output wire [HBM_CH*3-1:0]                            m_axi_hbm_arprot,
    output wire [HBM_CH*4-1:0]                            m_axi_hbm_arqos,
    output wire [HBM_CH*AXI_HBM_ARUSER_WIDTH-1:0]         m_axi_hbm_aruser,
    output wire [HBM_CH-1:0]                              m_axi_hbm_arvalid,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_arready,
    input  wire [HBM_CH*AXI_HBM_ID_WIDTH-1:0]             m_axi_hbm_rid,
    input  wire [HBM_CH*AXI_HBM_DATA_WIDTH-1:0]           m_axi_hbm_rdata,
    input  wire [HBM_CH*2-1:0]                            m_axi_hbm_rresp,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_rlast,
    input  wire [HBM_CH*AXI_HBM_RUSER_WIDTH-1:0]          m_axi_hbm_ruser,
    input  wire [HBM_CH-1:0]                              m_axi_hbm_rvalid,
    output wire [HBM_CH-1:0]                              m_axi_hbm_rready,

    input  wire [HBM_CH-1:0]                              hbm_status,

    /*
     * Statistics increment output
     */
    output wire [STAT_INC_WIDTH-1:0]                      m_axis_stat_tdata,
    output wire [STAT_ID_WIDTH-1:0]                       m_axis_stat_tid,
    output wire                                           m_axis_stat_tvalid,
    input  wire                                           m_axis_stat_tready,

    /*
     * GPIO
     */
    input  wire [APP_GPIO_IN_WIDTH-1:0]                   gpio_in,
    output wire [APP_GPIO_OUT_WIDTH-1:0]                  gpio_out,

    /*
     * JTAG
     */
    input  wire                                           jtag_tdi,
    output wire                                           jtag_tdo,
    input  wire                                           jtag_tms,
    input  wire                                           jtag_tck
);

// check configuration
initial begin
    if (APP_ID != 32'h12340100) begin
        $error("Error: Invalid APP_ID (expected 32'h12340100, got 32'h%x) (instance %m)", APP_ID);
        $finish;
    end
end

localparam NUM_CLUSTERS = 2;
localparam NUM_CORES = 8;
localparam NUM_HPU_CMDS = 4;
localparam CMD_ID_WIDTH = $clog2(NUM_CLUSTERS) + $clog2(NUM_CORES) + $clog2(NUM_HPU_CMDS);
localparam NUM_MPQ = 16;  // pspin_cfg_pkg.sv

localparam UMATCH_MATCHER_LEN = 66;
localparam UMATCH_MTU = 1500;
localparam UMATCH_BUF_FRAMES = 0;

{{ m.declare_params() }}

localparam AXI_HOST_ADDR_WIDTH = 64; // pspin_cfg_pkg::HOST_AXI_AW
localparam AXI_DATA_WIDTH = 512; // pspin_cfg_pkg::data_t
localparam AXI_ADDR_WIDTH = 32;
localparam AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8);
localparam AXI_ID_WIDTH = 8;

localparam LEN_WIDTH = 16;
localparam TAG_WIDTH = 32;
localparam MSG_ID_WIDTH = 16;

localparam [AXI_ADDR_WIDTH-1:0] BUF_START = 32'h1c100000; // 1c000000 + MEM_HND_SIZE
localparam [AXI_ADDR_WIDTH-1:0] BUF_SIZE = 512*1024; // match with pspin_cfg_pkg.sv:MEM_PKT_SIZE

// for cdc axis fifo
localparam PACKET_BEATS = (UMATCH_MTU * 8 + AXIS_IF_DATA_WIDTH - 1) / (AXIS_IF_DATA_WIDTH);
localparam IF_CDC_FIFO_DEPTH = 1 * PACKET_BEATS * AXIS_IF_KEEP_WIDTH;

wire [NUM_CLUSTERS-1:0] cl_fetch_en;
wire [NUM_CLUSTERS-1:0] cl_eoc;
wire [NUM_CLUSTERS-1:0] cl_busy;
wire [NUM_MPQ-1:0] mpq_full;
wire aux_rst;
wire pspin_clk;
wire pspin_rst;
wire interconnect_aresetn;
wire mmcm_locked;

// XXX: address space compressed but we don't actually need that much
//      actual width: 22
// L2       starts at 32'h1c00_0000 -> 24'h00_0000
// prog mem starts at 32'h1d00_0000 -> 24'h40_0000
function [31:0] l2_addr_gen;
    input [AXIL_APP_CTRL_ADDR_WIDTH-1:0] mqnic_addr;
    reg   [23:0] real_addr;
    begin
        l2_addr_gen = 32'h0000_0000;
        real_addr = {2'b0, mqnic_addr[AXIL_APP_CTRL_ADDR_WIDTH-3:0]};
        if (mqnic_addr < 24'h40_0000)
            l2_addr_gen = {8'h1c, real_addr};
        else if (mqnic_addr < 24'h80_0000)
            l2_addr_gen = {8'h1d, real_addr};
        `ifndef TARGET_SYNTHESIS
        else begin
            $error("Address greater than limit for L2 & program memory: 0x%0h", mqnic_addr);
            $finish;
        end
        `endif
    end
endfunction

// 50MHz from host before demux
wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]    s_slow_axil_awaddr;
wire [2:0]                             s_slow_axil_awprot;
wire                                   s_slow_axil_awvalid;
wire                                   s_slow_axil_awready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]    s_slow_axil_wdata;
wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]    s_slow_axil_wstrb;
wire                                   s_slow_axil_wvalid;
wire                                   s_slow_axil_wready;
wire [1:0]                             s_slow_axil_bresp;
wire                                   s_slow_axil_bvalid;
wire                                   s_slow_axil_bready;
wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]    s_slow_axil_araddr;
wire [2:0]                             s_slow_axil_arprot;
wire                                   s_slow_axil_arvalid;
wire                                   s_slow_axil_arready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]    s_slow_axil_rdata;
wire [1:0]                             s_slow_axil_rresp;
wire                                   s_slow_axil_rvalid;
wire                                   s_slow_axil_rready;

wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]    pspin_axil_awaddr;
wire [2:0]                             pspin_axil_awprot;
wire                                   pspin_axil_awvalid;
wire                                   pspin_axil_awready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]    pspin_axil_wdata;
wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]    pspin_axil_wstrb;
wire                                   pspin_axil_wvalid;
wire                                   pspin_axil_wready;
wire [1:0]                             pspin_axil_bresp;
wire                                   pspin_axil_bvalid;
wire                                   pspin_axil_bready;
wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]    pspin_axil_araddr;
wire [2:0]                             pspin_axil_arprot;
wire                                   pspin_axil_arvalid;
wire                                   pspin_axil_arready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]    pspin_axil_rdata;
wire [1:0]                             pspin_axil_rresp;
wire                                   pspin_axil_rvalid;
wire                                   pspin_axil_rready;

wire [31 : 0] pspin_axi_narrow_awaddr;
wire [7 : 0] pspin_axi_narrow_awlen;
wire [2 : 0] pspin_axi_narrow_awsize;
wire [1 : 0] pspin_axi_narrow_awburst;
wire [0 : 0] pspin_axi_narrow_awlock;
wire [3 : 0] pspin_axi_narrow_awcache;
wire [2 : 0] pspin_axi_narrow_awprot;
wire [3 : 0] pspin_axi_narrow_awregion;
wire [3 : 0] pspin_axi_narrow_awqos;
wire pspin_axi_narrow_awvalid;
wire pspin_axi_narrow_awready;
wire [31 : 0] pspin_axi_narrow_wdata;
wire [3 : 0] pspin_axi_narrow_wstrb;
wire pspin_axi_narrow_wlast;
wire pspin_axi_narrow_wvalid;
wire pspin_axi_narrow_wready;
wire [1 : 0] pspin_axi_narrow_bresp;
wire pspin_axi_narrow_bvalid;
wire pspin_axi_narrow_bready;
wire [31 : 0] pspin_axi_narrow_araddr;
wire [7 : 0] pspin_axi_narrow_arlen;
wire [2 : 0] pspin_axi_narrow_arsize;
wire [1 : 0] pspin_axi_narrow_arburst;
wire [0 : 0] pspin_axi_narrow_arlock;
wire [3 : 0] pspin_axi_narrow_arcache;
wire [2 : 0] pspin_axi_narrow_arprot;
wire [3 : 0] pspin_axi_narrow_arregion;
wire [3 : 0] pspin_axi_narrow_arqos;
wire pspin_axi_narrow_arvalid;
wire pspin_axi_narrow_arready;
wire [31 : 0] pspin_axi_narrow_rdata;
wire [1 : 0] pspin_axi_narrow_rresp;
wire pspin_axi_narrow_rlast;
wire pspin_axi_narrow_rvalid;
wire pspin_axi_narrow_rready;

wire [31 : 0] pspin_axi_full_awaddr;
wire [7 : 0] pspin_axi_full_awlen;
wire [2 : 0] pspin_axi_full_awsize;
wire [1 : 0] pspin_axi_full_awburst;
wire [0 : 0] pspin_axi_full_awlock;
wire [3 : 0] pspin_axi_full_awcache;
wire [2 : 0] pspin_axi_full_awprot;
wire [3 : 0] pspin_axi_full_awregion;
wire [3 : 0] pspin_axi_full_awqos;
wire pspin_axi_full_awvalid;
wire pspin_axi_full_awready;
wire [511 : 0] pspin_axi_full_wdata;
wire [63 : 0] pspin_axi_full_wstrb;
wire pspin_axi_full_wlast;
wire pspin_axi_full_wvalid;
wire pspin_axi_full_wready;
wire [1 : 0] pspin_axi_full_bresp;
wire pspin_axi_full_bvalid;
wire pspin_axi_full_bready;
wire [31 : 0] pspin_axi_full_araddr;
wire [7 : 0] pspin_axi_full_arlen;
wire [2 : 0] pspin_axi_full_arsize;
wire [1 : 0] pspin_axi_full_arburst;
wire [0 : 0] pspin_axi_full_arlock;
wire [3 : 0] pspin_axi_full_arcache;
wire [2 : 0] pspin_axi_full_arprot;
wire [3 : 0] pspin_axi_full_arregion;
wire [3 : 0] pspin_axi_full_arqos;
wire pspin_axi_full_arvalid;
wire pspin_axi_full_arready;
wire [511 : 0] pspin_axi_full_rdata;
wire [1 : 0] pspin_axi_full_rresp;
wire pspin_axi_full_rlast;
wire pspin_axi_full_rvalid;
wire pspin_axi_full_rready;



wire [31:0] pspin_mapped_axil_awaddr;
wire [31:0] pspin_mapped_axil_araddr;
assign pspin_mapped_axil_awaddr = l2_addr_gen(pspin_axil_awaddr);
assign pspin_mapped_axil_araddr = l2_addr_gen(pspin_axil_araddr);

wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]    ctrl_reg_axil_awaddr;
wire [2:0]                             ctrl_reg_axil_awprot;
wire                                   ctrl_reg_axil_awvalid;
wire                                   ctrl_reg_axil_awready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]    ctrl_reg_axil_wdata;
wire [AXIL_APP_CTRL_STRB_WIDTH-1:0]    ctrl_reg_axil_wstrb;
wire                                   ctrl_reg_axil_wvalid;
wire                                   ctrl_reg_axil_wready;
wire [1:0]                             ctrl_reg_axil_bresp;
wire                                   ctrl_reg_axil_bvalid;
wire                                   ctrl_reg_axil_bready;
wire [AXIL_APP_CTRL_ADDR_WIDTH-1:0]    ctrl_reg_axil_araddr;
wire [2:0]                             ctrl_reg_axil_arprot;
wire                                   ctrl_reg_axil_arvalid;
wire                                   ctrl_reg_axil_arready;
wire [AXIL_APP_CTRL_DATA_WIDTH-1:0]    ctrl_reg_axil_rdata;
wire [1:0]                             ctrl_reg_axil_rresp;
wire                                   ctrl_reg_axil_rvalid;
wire                                   ctrl_reg_axil_rready;

wire stdout_rd_en;
wire [31:0] stdout_dout;
wire stdout_data_valid;

wire [31:0]                                      alloc_dropped_pkts;

{{- m.call_group("me", m.declare_wire, "match") }}

{{- m.call_group("her", m.declare_wire, "her_gen") }}
{{- m.call_group("her_meta", m.declare_wire, "her_gen") }}

wire [AXIS_IF_DATA_WIDTH-1:0]                   s_axis_nic_rx_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0]                   s_axis_nic_rx_tkeep;
wire                                            s_axis_nic_rx_tvalid;
wire                                            s_axis_nic_rx_tready;
wire                                            s_axis_nic_rx_tlast;
wire [AXIS_IF_RX_ID_WIDTH-1:0]                  s_axis_nic_rx_tid;
wire [AXIS_IF_RX_DEST_WIDTH-1:0]                s_axis_nic_rx_tdest;
wire [AXIS_IF_RX_USER_WIDTH-1:0]                s_axis_nic_rx_tuser;

wire [AXIS_IF_DATA_WIDTH-1:0]                   m_axis_nic_rx_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0]                   m_axis_nic_rx_tkeep;
wire                                            m_axis_nic_rx_tvalid;
wire                                            m_axis_nic_rx_tready;
wire                                            m_axis_nic_rx_tlast;
wire [AXIS_IF_RX_ID_WIDTH-1:0]                  m_axis_nic_rx_tid;
wire [AXIS_IF_RX_DEST_WIDTH-1:0]                m_axis_nic_rx_tdest;
wire [AXIS_IF_RX_USER_WIDTH-1:0]                m_axis_nic_rx_tuser;

wire [AXIS_IF_DATA_WIDTH-1:0]                   m_axis_nic_tx_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0]                   m_axis_nic_tx_tkeep;
wire                                            m_axis_nic_tx_tvalid;
wire                                            m_axis_nic_tx_tready;
wire                                            m_axis_nic_tx_tlast;
wire [AXIS_IF_TX_ID_WIDTH-1:0]                  m_axis_nic_tx_tid;
wire [AXIS_IF_TX_DEST_WIDTH-1:0]                m_axis_nic_tx_tdest;
wire [AXIS_IF_TX_USER_WIDTH-1:0]                m_axis_nic_tx_tuser;

wire [AXIS_IF_DATA_WIDTH-1:0]                   m_axis_nic_fast_tx_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0]                   m_axis_nic_fast_tx_tkeep;
wire                                            m_axis_nic_fast_tx_tvalid;
wire                                            m_axis_nic_fast_tx_tready;
wire                                            m_axis_nic_fast_tx_tlast;
wire [AXIS_IF_TX_ID_WIDTH-1:0]                  m_axis_nic_fast_tx_tid;
wire [AXIS_IF_TX_DEST_WIDTH-1:0]                m_axis_nic_fast_tx_tdest;
wire [AXIS_IF_TX_USER_WIDTH-1:0]                m_axis_nic_fast_tx_tuser;

wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_ni_awid;
wire [AXI_ADDR_WIDTH-1:0]                       m_axi_pspin_ni_awaddr;
wire [7:0]                                      m_axi_pspin_ni_awlen;
wire [2:0]                                      m_axi_pspin_ni_awsize;
wire [1:0]                                      m_axi_pspin_ni_awburst;
wire                                            m_axi_pspin_ni_awlock;
wire [3:0]                                      m_axi_pspin_ni_awcache;
wire [2:0]                                      m_axi_pspin_ni_awprot;
wire                                            m_axi_pspin_ni_awvalid;
wire                                            m_axi_pspin_ni_awready;
wire [AXI_DATA_WIDTH-1:0]                       m_axi_pspin_ni_wdata;
wire [AXI_STRB_WIDTH-1:0]                       m_axi_pspin_ni_wstrb;
wire                                            m_axi_pspin_ni_wlast;
wire                                            m_axi_pspin_ni_wvalid;
wire                                            m_axi_pspin_ni_wready;
wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_ni_bid;
wire [1:0]                                      m_axi_pspin_ni_bresp;
wire                                            m_axi_pspin_ni_bvalid;
wire                                            m_axi_pspin_ni_bready;
wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_ni_arid;
wire [AXI_ADDR_WIDTH-1:0]                       m_axi_pspin_ni_araddr;
wire [7:0]                                      m_axi_pspin_ni_arlen;
wire [2:0]                                      m_axi_pspin_ni_arsize;
wire [1:0]                                      m_axi_pspin_ni_arburst;
wire                                            m_axi_pspin_ni_arlock;
wire [3:0]                                      m_axi_pspin_ni_arcache;
wire [2:0]                                      m_axi_pspin_ni_arprot;
wire                                            m_axi_pspin_ni_arvalid;
wire                                            m_axi_pspin_ni_arready;
wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_ni_rid;
wire [AXI_DATA_WIDTH-1:0]                       m_axi_pspin_ni_rdata;
wire [1:0]                                      m_axi_pspin_ni_rresp;
wire                                            m_axi_pspin_ni_rlast;
wire                                            m_axi_pspin_ni_rvalid;
wire                                            m_axi_pspin_ni_rready;

wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_no_awid;
wire [AXI_ADDR_WIDTH-1:0]                       m_axi_pspin_no_awaddr;
wire [7:0]                                      m_axi_pspin_no_awlen;
wire [2:0]                                      m_axi_pspin_no_awsize;
wire [1:0]                                      m_axi_pspin_no_awburst;
wire                                            m_axi_pspin_no_awlock;
wire [3:0]                                      m_axi_pspin_no_awcache;
wire [2:0]                                      m_axi_pspin_no_awprot;
wire                                            m_axi_pspin_no_awvalid;
wire                                            m_axi_pspin_no_awready;
wire [AXI_DATA_WIDTH-1:0]                       m_axi_pspin_no_wdata;
wire [AXI_STRB_WIDTH-1:0]                       m_axi_pspin_no_wstrb;
wire                                            m_axi_pspin_no_wlast;
wire                                            m_axi_pspin_no_wvalid;
wire                                            m_axi_pspin_no_wready;
wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_no_bid;
wire [1:0]                                      m_axi_pspin_no_bresp;
wire                                            m_axi_pspin_no_bvalid;
wire                                            m_axi_pspin_no_bready;
wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_no_arid;
wire [AXI_ADDR_WIDTH-1:0]                       m_axi_pspin_no_araddr;
wire [7:0]                                      m_axi_pspin_no_arlen;
wire [2:0]                                      m_axi_pspin_no_arsize;
wire [1:0]                                      m_axi_pspin_no_arburst;
wire                                            m_axi_pspin_no_arlock;
wire [3:0]                                      m_axi_pspin_no_arcache;
wire [2:0]                                      m_axi_pspin_no_arprot;
wire                                            m_axi_pspin_no_arvalid;
wire                                            m_axi_pspin_no_arready;
wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_no_rid;
wire [AXI_DATA_WIDTH-1:0]                       m_axi_pspin_no_rdata;
wire [1:0]                                      m_axi_pspin_no_rresp;
wire                                            m_axi_pspin_no_rlast;
wire                                            m_axi_pspin_no_rvalid;
wire                                            m_axi_pspin_no_rready;

// in PsPIN clock domain
wire [AXI_ID_WIDTH-1:0]                         s_axi_pspin_dma_awid;
wire [AXI_HOST_ADDR_WIDTH-1:0]                  s_axi_pspin_dma_awaddr;
wire [7:0]                                      s_axi_pspin_dma_awlen;
wire [2:0]                                      s_axi_pspin_dma_awsize;
wire [1:0]                                      s_axi_pspin_dma_awburst;
wire                                            s_axi_pspin_dma_awlock;
wire [3:0]                                      s_axi_pspin_dma_awcache;
wire [2:0]                                      s_axi_pspin_dma_awprot;
wire [3:0]                                      s_axi_pspin_dma_awqos;
wire [3:0]                                      s_axi_pspin_dma_awregion;
wire                                            s_axi_pspin_dma_awvalid;
wire                                            s_axi_pspin_dma_awready;
wire [AXI_DATA_WIDTH-1:0]                       s_axi_pspin_dma_wdata;
wire [AXI_STRB_WIDTH-1:0]                       s_axi_pspin_dma_wstrb;
wire                                            s_axi_pspin_dma_wlast;
wire                                            s_axi_pspin_dma_wvalid;
wire                                            s_axi_pspin_dma_wready;
wire [AXI_ID_WIDTH-1:0]                         s_axi_pspin_dma_bid;
wire [1:0]                                      s_axi_pspin_dma_bresp;
wire                                            s_axi_pspin_dma_bvalid;
wire                                            s_axi_pspin_dma_bready;
wire [AXI_ID_WIDTH-1:0]                         s_axi_pspin_dma_arid;
wire [AXI_HOST_ADDR_WIDTH-1:0]                  s_axi_pspin_dma_araddr;
wire [7:0]                                      s_axi_pspin_dma_arlen;
wire [2:0]                                      s_axi_pspin_dma_arsize;
wire [1:0]                                      s_axi_pspin_dma_arburst;
wire                                            s_axi_pspin_dma_arlock;
wire [3:0]                                      s_axi_pspin_dma_arcache;
wire [2:0]                                      s_axi_pspin_dma_arprot;
wire [3:0]                                      s_axi_pspin_dma_arqos;
wire [3:0]                                      s_axi_pspin_dma_arregion;
wire                                            s_axi_pspin_dma_arvalid;
wire                                            s_axi_pspin_dma_arready;
wire [AXI_ID_WIDTH-1:0]                         s_axi_pspin_dma_rid;
wire [AXI_DATA_WIDTH-1:0]                       s_axi_pspin_dma_rdata;
wire [1:0]                                      s_axi_pspin_dma_rresp;
wire                                            s_axi_pspin_dma_rlast;
wire                                            s_axi_pspin_dma_rvalid;
wire                                            s_axi_pspin_dma_rready;

// in Corundum clock domain
wire [AXI_ID_WIDTH-1:0]                         s_axi_pspin_dma_fast_awid;
wire [AXI_HOST_ADDR_WIDTH-1:0]                  s_axi_pspin_dma_fast_awaddr;
wire [7:0]                                      s_axi_pspin_dma_fast_awlen;
wire [2:0]                                      s_axi_pspin_dma_fast_awsize;
wire [1:0]                                      s_axi_pspin_dma_fast_awburst;
wire                                            s_axi_pspin_dma_fast_awlock;
wire [3:0]                                      s_axi_pspin_dma_fast_awcache;
wire [2:0]                                      s_axi_pspin_dma_fast_awprot;
wire [3:0]                                      s_axi_pspin_dma_fast_awqos;
wire [3:0]                                      s_axi_pspin_dma_fast_awregion;
wire                                            s_axi_pspin_dma_fast_awvalid;
wire                                            s_axi_pspin_dma_fast_awready;
wire [AXI_DATA_WIDTH-1:0]                       s_axi_pspin_dma_fast_wdata;
wire [AXI_STRB_WIDTH-1:0]                       s_axi_pspin_dma_fast_wstrb;
wire                                            s_axi_pspin_dma_fast_wlast;
wire                                            s_axi_pspin_dma_fast_wvalid;
wire                                            s_axi_pspin_dma_fast_wready;
wire [AXI_ID_WIDTH-1:0]                         s_axi_pspin_dma_fast_bid;
wire [1:0]                                      s_axi_pspin_dma_fast_bresp;
wire                                            s_axi_pspin_dma_fast_bvalid;
wire                                            s_axi_pspin_dma_fast_bready;
wire [AXI_ID_WIDTH-1:0]                         s_axi_pspin_dma_fast_arid;
wire [AXI_HOST_ADDR_WIDTH-1:0]                  s_axi_pspin_dma_fast_araddr;
wire [7:0]                                      s_axi_pspin_dma_fast_arlen;
wire [2:0]                                      s_axi_pspin_dma_fast_arsize;
wire [1:0]                                      s_axi_pspin_dma_fast_arburst;
wire                                            s_axi_pspin_dma_fast_arlock;
wire [3:0]                                      s_axi_pspin_dma_fast_arcache;
wire [2:0]                                      s_axi_pspin_dma_fast_arprot;
wire [3:0]                                      s_axi_pspin_dma_fast_arqos;
wire [3:0]                                      s_axi_pspin_dma_fast_arregion;
wire                                            s_axi_pspin_dma_fast_arvalid;
wire                                            s_axi_pspin_dma_fast_arready;
wire [AXI_ID_WIDTH-1:0]                         s_axi_pspin_dma_fast_rid;
wire [AXI_DATA_WIDTH-1:0]                       s_axi_pspin_dma_fast_rdata;
wire [1:0]                                      s_axi_pspin_dma_fast_rresp;
wire                                            s_axi_pspin_dma_fast_rlast;
wire                                            s_axi_pspin_dma_fast_rvalid;
wire                                            s_axi_pspin_dma_fast_rready;

wire                                            her_ready;
wire                                            her_valid;
wire [MSG_ID_WIDTH-1:0]                         her_msgid;
wire                                            her_is_eom;
wire [AXI_ADDR_WIDTH-1:0]                       her_addr;
wire [AXI_ADDR_WIDTH-1:0]                       her_size;
wire [AXI_ADDR_WIDTH-1:0]                       her_xfer_size;
{{- m.call_group_single("her_meta", m.declare_wire, "her_meta") }}

wire                                            feedback_ready;
wire                                            feedback_valid;
wire [AXI_ADDR_WIDTH-1:0]                       feedback_her_addr;
wire [LEN_WIDTH-1:0]                            feedback_her_size;
wire [MSG_ID_WIDTH-1:0]                         feedback_msgid;

wire                                            nic_cmd_req_ready;
wire                                            nic_cmd_req_valid;
wire [CMD_ID_WIDTH-1:0]                         nic_cmd_req_id;
wire [31:0]                                     nic_cmd_req_nid;
wire [31:0]                                     nic_cmd_req_fid;
wire [AXI_HOST_ADDR_WIDTH-1:0]                  nic_cmd_req_src_addr;
wire [AXI_ADDR_WIDTH-1:0]                       nic_cmd_req_length;
wire [63:0]                                     nic_cmd_req_user_ptr;

wire                                            nic_cmd_resp_valid;
wire [CMD_ID_WIDTH-1:0]                         nic_cmd_resp_id;

wire [3:0]                                      egress_dma_last_error;

wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]       hostdma_ram_wr_cmd_be;
wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]     hostdma_ram_wr_cmd_addr;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]     hostdma_ram_wr_cmd_data;
wire [RAM_SEG_COUNT-1:0]                        hostdma_ram_wr_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                        hostdma_ram_wr_cmd_ready;
wire [RAM_SEG_COUNT-1:0]                        hostdma_ram_wr_done;

wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]     hostdma_ram_rd_cmd_addr;
wire [RAM_SEG_COUNT-1:0]                        hostdma_ram_rd_cmd_valid;
wire [RAM_SEG_COUNT-1:0]                        hostdma_ram_rd_cmd_ready;
wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]     hostdma_ram_rd_resp_data;
wire [RAM_SEG_COUNT-1:0]                        hostdma_ram_rd_resp_valid;
wire [RAM_SEG_COUNT-1:0]                        hostdma_ram_rd_resp_ready;

pspin_clk_wiz i_pspin_clk_wiz (
    .clk_out1(pspin_clk),
    .reset(rst),
    .locked(mmcm_locked),
    .clk_in1(clk)
);

proc_sys_reset_0 i_pspin_rst (
  .slowest_sync_clk(pspin_clk),        // input wire slowest_sync_clk
  .ext_reset_in(rst),                  // input wire ext_reset_in
  .aux_reset_in('b0),                  // input wire aux_reset_in
  .mb_debug_sys_rst('b0),              // input wire mb_debug_sys_rst
  .dcm_locked(mmcm_locked),            // input wire dcm_locked
  .mb_reset(pspin_rst),                // output wire mb_reset
  .bus_struct_reset(),                 // output wire [0 : 0] bus_struct_reset
  .peripheral_reset(),                 // output wire [0 : 0] peripheral_reset
  .interconnect_aresetn,               // output wire [0 : 0] interconnect_aresetn
  .peripheral_aresetn()                // output wire [0 : 0] peripheral_aresetn
);

pspin_hostdma_clk_converter i_pspin_hostdma_conv (
  .s_axi_aclk(pspin_clk),          // input wire s_axi_aclk
  .s_axi_aresetn(!pspin_rst),    // input wire s_axi_aresetn
  .s_axi_awid(s_axi_pspin_dma_awid),          // input wire [7 : 0] s_axi_awid
  .s_axi_awaddr(s_axi_pspin_dma_awaddr),      // input wire [63 : 0] s_axi_awaddr
  .s_axi_awlen(s_axi_pspin_dma_awlen),        // input wire [7 : 0] s_axi_awlen
  .s_axi_awsize(s_axi_pspin_dma_awsize),      // input wire [2 : 0] s_axi_awsize
  .s_axi_awburst(s_axi_pspin_dma_awburst),    // input wire [1 : 0] s_axi_awburst
  .s_axi_awlock(s_axi_pspin_dma_awlock),      // input wire [0 : 0] s_axi_awlock
  .s_axi_awcache(s_axi_pspin_dma_awcache),    // input wire [3 : 0] s_axi_awcache
  .s_axi_awprot(s_axi_pspin_dma_awprot),      // input wire [2 : 0] s_axi_awprot
  .s_axi_awregion(s_axi_pspin_dma_awregion),  // input wire [3 : 0] s_axi_awregion
  .s_axi_awqos(s_axi_pspin_dma_awqos),        // input wire [3 : 0] s_axi_awqos
  .s_axi_awvalid(s_axi_pspin_dma_awvalid),    // input wire s_axi_awvalid
  .s_axi_awready(s_axi_pspin_dma_awready),    // output wire s_axi_awready
  .s_axi_wdata(s_axi_pspin_dma_wdata),        // input wire [511 : 0] s_axi_wdata
  .s_axi_wstrb(s_axi_pspin_dma_wstrb),        // input wire [63 : 0] s_axi_wstrb
  .s_axi_wlast(s_axi_pspin_dma_wlast),        // input wire s_axi_wlast
  .s_axi_wvalid(s_axi_pspin_dma_wvalid),      // input wire s_axi_wvalid
  .s_axi_wready(s_axi_pspin_dma_wready),      // output wire s_axi_wready
  .s_axi_bid(s_axi_pspin_dma_bid),            // output wire [7 : 0] s_axi_bid
  .s_axi_bresp(s_axi_pspin_dma_bresp),        // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(s_axi_pspin_dma_bvalid),      // output wire s_axi_bvalid
  .s_axi_bready(s_axi_pspin_dma_bready),      // input wire s_axi_bready
  .s_axi_arid(s_axi_pspin_dma_arid),          // input wire [7 : 0] s_axi_arid
  .s_axi_araddr(s_axi_pspin_dma_araddr),      // input wire [63 : 0] s_axi_araddr
  .s_axi_arlen(s_axi_pspin_dma_arlen),        // input wire [7 : 0] s_axi_arlen
  .s_axi_arsize(s_axi_pspin_dma_arsize),      // input wire [2 : 0] s_axi_arsize
  .s_axi_arburst(s_axi_pspin_dma_arburst),    // input wire [1 : 0] s_axi_arburst
  .s_axi_arlock(s_axi_pspin_dma_arlock),      // input wire [0 : 0] s_axi_arlock
  .s_axi_arcache(s_axi_pspin_dma_arcache),    // input wire [3 : 0] s_axi_arcache
  .s_axi_arprot(s_axi_pspin_dma_arprot),      // input wire [2 : 0] s_axi_arprot
  .s_axi_arregion(s_axi_pspin_dma_arregion),  // input wire [3 : 0] s_axi_arregion
  .s_axi_arqos(s_axi_pspin_dma_arqos),        // input wire [3 : 0] s_axi_arqos
  .s_axi_arvalid(s_axi_pspin_dma_arvalid),    // input wire s_axi_arvalid
  .s_axi_arready(s_axi_pspin_dma_arready),    // output wire s_axi_arready
  .s_axi_rid(s_axi_pspin_dma_rid),            // output wire [7 : 0] s_axi_rid
  .s_axi_rdata(s_axi_pspin_dma_rdata),        // output wire [511 : 0] s_axi_rdata
  .s_axi_rresp(s_axi_pspin_dma_rresp),        // output wire [1 : 0] s_axi_rresp
  .s_axi_rlast(s_axi_pspin_dma_rlast),        // output wire s_axi_rlast
  .s_axi_rvalid(s_axi_pspin_dma_rvalid),      // output wire s_axi_rvalid
  .s_axi_rready(s_axi_pspin_dma_rready),      // input wire s_axi_rready
  .m_axi_aclk(clk),          // input wire m_axi_aclk
  .m_axi_aresetn(!rst),    // input wire m_axi_aresetn
  .m_axi_awid(s_axi_pspin_dma_fast_awid),          // output wire [7 : 0] m_axi_awid
  .m_axi_awaddr(s_axi_pspin_dma_fast_awaddr),      // output wire [63 : 0] m_axi_awaddr
  .m_axi_awlen(s_axi_pspin_dma_fast_awlen),        // output wire [7 : 0] m_axi_awlen
  .m_axi_awsize(s_axi_pspin_dma_fast_awsize),      // output wire [2 : 0] m_axi_awsize
  .m_axi_awburst(s_axi_pspin_dma_fast_awburst),    // output wire [1 : 0] m_axi_awburst
  .m_axi_awlock(s_axi_pspin_dma_fast_awlock),      // output wire [0 : 0] m_axi_awlock
  .m_axi_awcache(s_axi_pspin_dma_fast_awcache),    // output wire [3 : 0] m_axi_awcache
  .m_axi_awprot(s_axi_pspin_dma_fast_awprot),      // output wire [2 : 0] m_axi_awprot
  .m_axi_awregion(s_axi_pspin_dma_fast_awregion),  // output wire [3 : 0] m_axi_awregion
  .m_axi_awqos(s_axi_pspin_dma_fast_awqos),        // output wire [3 : 0] m_axi_awqos
  .m_axi_awvalid(s_axi_pspin_dma_fast_awvalid),    // output wire m_axi_awvalid
  .m_axi_awready(s_axi_pspin_dma_fast_awready),    // input wire m_axi_awready
  .m_axi_wdata(s_axi_pspin_dma_fast_wdata),        // output wire [511 : 0] m_axi_wdata
  .m_axi_wstrb(s_axi_pspin_dma_fast_wstrb),        // output wire [63 : 0] m_axi_wstrb
  .m_axi_wlast(s_axi_pspin_dma_fast_wlast),        // output wire m_axi_wlast
  .m_axi_wvalid(s_axi_pspin_dma_fast_wvalid),      // output wire m_axi_wvalid
  .m_axi_wready(s_axi_pspin_dma_fast_wready),      // input wire m_axi_wready
  .m_axi_bid(s_axi_pspin_dma_fast_bid),            // input wire [7 : 0] m_axi_bid
  .m_axi_bresp(s_axi_pspin_dma_fast_bresp),        // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid(s_axi_pspin_dma_fast_bvalid),      // input wire m_axi_bvalid
  .m_axi_bready(s_axi_pspin_dma_fast_bready),      // output wire m_axi_bready
  .m_axi_arid(s_axi_pspin_dma_fast_arid),          // output wire [7 : 0] m_axi_arid
  .m_axi_araddr(s_axi_pspin_dma_fast_araddr),      // output wire [63 : 0] m_axi_araddr
  .m_axi_arlen(s_axi_pspin_dma_fast_arlen),        // output wire [7 : 0] m_axi_arlen
  .m_axi_arsize(s_axi_pspin_dma_fast_arsize),      // output wire [2 : 0] m_axi_arsize
  .m_axi_arburst(s_axi_pspin_dma_fast_arburst),    // output wire [1 : 0] m_axi_arburst
  .m_axi_arlock(s_axi_pspin_dma_fast_arlock),      // output wire [0 : 0] m_axi_arlock
  .m_axi_arcache(s_axi_pspin_dma_fast_arcache),    // output wire [3 : 0] m_axi_arcache
  .m_axi_arprot(s_axi_pspin_dma_fast_arprot),      // output wire [2 : 0] m_axi_arprot
  .m_axi_arregion(s_axi_pspin_dma_fast_arregion),  // output wire [3 : 0] m_axi_arregion
  .m_axi_arqos(s_axi_pspin_dma_fast_arqos),        // output wire [3 : 0] m_axi_arqos
  .m_axi_arvalid(s_axi_pspin_dma_fast_arvalid),    // output wire m_axi_arvalid
  .m_axi_arready(s_axi_pspin_dma_fast_arready),    // input wire m_axi_arready
  .m_axi_rid(s_axi_pspin_dma_fast_rid),            // input wire [7 : 0] m_axi_rid
  .m_axi_rdata(s_axi_pspin_dma_fast_rdata),        // input wire [511 : 0] m_axi_rdata
  .m_axi_rresp(s_axi_pspin_dma_fast_rresp),        // input wire [1 : 0] m_axi_rresp
  .m_axi_rlast(s_axi_pspin_dma_fast_rlast),        // input wire m_axi_rlast
  .m_axi_rvalid(s_axi_pspin_dma_fast_rvalid),      // input wire m_axi_rvalid
  .m_axi_rready(s_axi_pspin_dma_fast_rready)      // output wire m_axi_rready
);

pspin_host_clk_converter i_pspin_axil_conv (
  .s_axi_aclk(clk),                         // input wire s_axi_aclk
  .s_axi_aresetn(!rst),                     // input wire s_axi_aresetn
  .s_axi_awaddr(s_axil_app_ctrl_awaddr),    // input wire [23 : 0] s_axi_awaddr
  .s_axi_awprot(s_axil_app_ctrl_awprot),    // input wire [2 : 0] s_axi_awprot
  .s_axi_awvalid(s_axil_app_ctrl_awvalid),  // input wire s_axi_awvalid
  .s_axi_awready(s_axil_app_ctrl_awready),  // output wire s_axi_awready
  .s_axi_wdata(s_axil_app_ctrl_wdata),      // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb(s_axil_app_ctrl_wstrb),      // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid(s_axil_app_ctrl_wvalid),    // input wire s_axi_wvalid
  .s_axi_wready(s_axil_app_ctrl_wready),    // output wire s_axi_wready
  .s_axi_bresp(s_axil_app_ctrl_bresp),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(s_axil_app_ctrl_bvalid),    // output wire s_axi_bvalid
  .s_axi_bready(s_axil_app_ctrl_bready),    // input wire s_axi_bready
  .s_axi_araddr(s_axil_app_ctrl_araddr),    // input wire [23 : 0] s_axi_araddr
  .s_axi_arprot(s_axil_app_ctrl_arprot),    // input wire [2 : 0] s_axi_arprot
  .s_axi_arvalid(s_axil_app_ctrl_arvalid),  // input wire s_axi_arvalid
  .s_axi_arready(s_axil_app_ctrl_arready),  // output wire s_axi_arready
  .s_axi_rdata(s_axil_app_ctrl_rdata),      // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(s_axil_app_ctrl_rresp),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(s_axil_app_ctrl_rvalid),    // output wire s_axi_rvalid
  .s_axi_rready(s_axil_app_ctrl_rready),    // input wire s_axi_rready

  .m_axi_aclk(pspin_clk),               // input wire m_axi_aclk
  .m_axi_aresetn(interconnect_aresetn), // input wire m_axi_aresetn
  .m_axi_awaddr(s_slow_axil_awaddr),    // output wire [23 : 0] m_axi_awaddr
  .m_axi_awprot(s_slow_axil_awprot),    // output wire [2 : 0] m_axi_awprot
  .m_axi_awvalid(s_slow_axil_awvalid),  // output wire m_axi_awvalid
  .m_axi_awready(s_slow_axil_awready),  // input wire m_axi_awready
  .m_axi_wdata(s_slow_axil_wdata),      // output wire [31 : 0] m_axi_wdata
  .m_axi_wstrb(s_slow_axil_wstrb),      // output wire [3 : 0] m_axi_wstrb
  .m_axi_wvalid(s_slow_axil_wvalid),    // output wire m_axi_wvalid
  .m_axi_wready(s_slow_axil_wready),    // input wire m_axi_wready
  .m_axi_bresp(s_slow_axil_bresp),      // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid(s_slow_axil_bvalid),    // input wire m_axi_bvalid
  .m_axi_bready(s_slow_axil_bready),    // output wire m_axi_bready
  .m_axi_araddr(s_slow_axil_araddr),    // output wire [23 : 0] m_axi_araddr
  .m_axi_arprot(s_slow_axil_arprot),    // output wire [2 : 0] m_axi_arprot
  .m_axi_arvalid(s_slow_axil_arvalid),  // output wire m_axi_arvalid
  .m_axi_arready(s_slow_axil_arready),  // input wire m_axi_arready
  .m_axi_rdata(s_slow_axil_rdata),      // input wire [31 : 0] m_axi_rdata
  .m_axi_rresp(s_slow_axil_rresp),      // input wire [1 : 0] m_axi_rresp
  .m_axi_rvalid(s_slow_axil_rvalid),    // input wire m_axi_rvalid
  .m_axi_rready(s_slow_axil_rready)     // output wire m_axi_rready
);

axil_interconnect_wrap_1x2 #(
    .DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
    .ADDR_WIDTH(AXIL_APP_CTRL_ADDR_WIDTH),
    .STRB_WIDTH(AXIL_APP_CTRL_STRB_WIDTH),
    // total 24 bits of app addr
    .M00_BASE_ADDR(24'h00_0000),    // L2 memory write
    .M00_ADDR_WIDTH(23),
    .M01_BASE_ADDR(24'h80_0000),    // control registers
    .M01_ADDR_WIDTH(16)
) i_host_interconnect (
    .clk                    (pspin_clk),
    .rst                    (pspin_rst),

    .s00_axil_awaddr        (s_slow_axil_awaddr),
    .s00_axil_awprot        (s_slow_axil_awprot),
    .s00_axil_awvalid       (s_slow_axil_awvalid),
    .s00_axil_awready       (s_slow_axil_awready),
    .s00_axil_wdata         (s_slow_axil_wdata),
    .s00_axil_wstrb         (s_slow_axil_wstrb),
    .s00_axil_wvalid        (s_slow_axil_wvalid),
    .s00_axil_wready        (s_slow_axil_wready),
    .s00_axil_bresp         (s_slow_axil_bresp),
    .s00_axil_bvalid        (s_slow_axil_bvalid),
    .s00_axil_bready        (s_slow_axil_bready),
    .s00_axil_araddr        (s_slow_axil_araddr),
    .s00_axil_arprot        (s_slow_axil_arprot),
    .s00_axil_arvalid       (s_slow_axil_arvalid),
    .s00_axil_arready       (s_slow_axil_arready),
    .s00_axil_rdata         (s_slow_axil_rdata),
    .s00_axil_rresp         (s_slow_axil_rresp),
    .s00_axil_rvalid        (s_slow_axil_rvalid),
    .s00_axil_rready        (s_slow_axil_rready),

    .m00_axil_awaddr        (pspin_axil_awaddr),
    .m00_axil_awprot        (pspin_axil_awprot),
    .m00_axil_awvalid       (pspin_axil_awvalid),
    .m00_axil_awready       (pspin_axil_awready),
    .m00_axil_wdata         (pspin_axil_wdata),
    .m00_axil_wstrb         (pspin_axil_wstrb),
    .m00_axil_wvalid        (pspin_axil_wvalid),
    .m00_axil_wready        (pspin_axil_wready),
    .m00_axil_bresp         (pspin_axil_bresp),
    .m00_axil_bvalid        (pspin_axil_bvalid),
    .m00_axil_bready        (pspin_axil_bready),
    .m00_axil_araddr        (pspin_axil_araddr),
    .m00_axil_arprot        (pspin_axil_arprot),
    .m00_axil_arvalid       (pspin_axil_arvalid),
    .m00_axil_arready       (pspin_axil_arready),
    .m00_axil_rdata         (pspin_axil_rdata),
    .m00_axil_rresp         (pspin_axil_rresp),
    .m00_axil_rvalid        (pspin_axil_rvalid),
    .m00_axil_rready        (pspin_axil_rready),

    .m01_axil_awaddr        (ctrl_reg_axil_awaddr),
    .m01_axil_awprot        (ctrl_reg_axil_awprot),
    .m01_axil_awvalid       (ctrl_reg_axil_awvalid),
    .m01_axil_awready       (ctrl_reg_axil_awready),
    .m01_axil_wdata         (ctrl_reg_axil_wdata),
    .m01_axil_wstrb         (ctrl_reg_axil_wstrb),
    .m01_axil_wvalid        (ctrl_reg_axil_wvalid),
    .m01_axil_wready        (ctrl_reg_axil_wready),
    .m01_axil_bresp         (ctrl_reg_axil_bresp),
    .m01_axil_bvalid        (ctrl_reg_axil_bvalid),
    .m01_axil_bready        (ctrl_reg_axil_bready),
    .m01_axil_araddr        (ctrl_reg_axil_araddr),
    .m01_axil_arprot        (ctrl_reg_axil_arprot),
    .m01_axil_arvalid       (ctrl_reg_axil_arvalid),
    .m01_axil_arready       (ctrl_reg_axil_arready),
    .m01_axil_rdata         (ctrl_reg_axil_rdata),
    .m01_axil_rresp         (ctrl_reg_axil_rresp),
    .m01_axil_rvalid        (ctrl_reg_axil_rvalid),
    .m01_axil_rready        (ctrl_reg_axil_rready)
);

pspin_ctrl_regs #(
    .DATA_WIDTH(AXIL_APP_CTRL_DATA_WIDTH),
    .ADDR_WIDTH(16), // we only have 16 bits of addr
    .STRB_WIDTH(AXIL_APP_CTRL_STRB_WIDTH),
    .NUM_CLUSTERS(NUM_CLUSTERS),
    .NUM_MPQ(NUM_MPQ)
) i_pspin_ctrl (
    .clk(pspin_clk),
    .rst(pspin_rst),

    .s_axil_awaddr          (ctrl_reg_axil_awaddr),
    .s_axil_awprot          (ctrl_reg_axil_awprot),
    .s_axil_awvalid         (ctrl_reg_axil_awvalid),
    .s_axil_awready         (ctrl_reg_axil_awready),
    .s_axil_wdata           (ctrl_reg_axil_wdata),
    .s_axil_wstrb           (ctrl_reg_axil_wstrb),
    .s_axil_wvalid          (ctrl_reg_axil_wvalid),
    .s_axil_wready          (ctrl_reg_axil_wready),
    .s_axil_bresp           (ctrl_reg_axil_bresp),
    .s_axil_bvalid          (ctrl_reg_axil_bvalid),
    .s_axil_bready          (ctrl_reg_axil_bready),
    .s_axil_araddr          (ctrl_reg_axil_araddr),
    .s_axil_arprot          (ctrl_reg_axil_arprot),
    .s_axil_arvalid         (ctrl_reg_axil_arvalid),
    .s_axil_arready         (ctrl_reg_axil_arready),
    .s_axil_rdata           (ctrl_reg_axil_rdata),
    .s_axil_rresp           (ctrl_reg_axil_rresp),
    .s_axil_rvalid          (ctrl_reg_axil_rvalid),
    .s_axil_rready          (ctrl_reg_axil_rready),

    .cl_fetch_en_o          (cl_fetch_en),
    .aux_rst_o              (aux_rst),
    .cl_eoc_i               (cl_eoc),
    .cl_busy_i              (cl_busy),
    .mpq_full_i             (mpq_full),

    .stdout_rd_en,
    .stdout_dout,
    .stdout_data_valid,

    .alloc_dropped_pkts,

{{- m.call_group("me", m.connect_wire, "match") }}

{{- m.call_group("her", m.connect_wire, "her_gen") }}
{{- m.call_group("her_meta", m.connect_wire, "her_gen") }}

    .egress_dma_last_error
);

axi_protocol_converter_0 i_host_to_full (
  .aclk(pspin_clk),                      // input wire aclk
  .aresetn(!pspin_rst),                // input wire aresetn
  .s_axi_awaddr(pspin_mapped_axil_awaddr),      // input wire [31 : 0] s_axi_awaddr
  .s_axi_awprot(pspin_axil_awprot),      // input wire [2 : 0] s_axi_awprot
  .s_axi_awvalid(pspin_axil_awvalid),    // input wire s_axi_awvalid
  .s_axi_awready(pspin_axil_awready),    // output wire s_axi_awready
  .s_axi_wdata(pspin_axil_wdata),        // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb(pspin_axil_wstrb),        // input wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid(pspin_axil_wvalid),      // input wire s_axi_wvalid
  .s_axi_wready(pspin_axil_wready),      // output wire s_axi_wready
  .s_axi_bresp(pspin_axil_bresp),        // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(pspin_axil_bvalid),      // output wire s_axi_bvalid
  .s_axi_bready(pspin_axil_bready),      // input wire s_axi_bready
  .s_axi_araddr(pspin_mapped_axil_araddr),      // input wire [31 : 0] s_axi_araddr
  .s_axi_arprot(pspin_axil_arprot),      // input wire [2 : 0] s_axi_arprot
  .s_axi_arvalid(pspin_axil_arvalid),    // input wire s_axi_arvalid
  .s_axi_arready(pspin_axil_arready),    // output wire s_axi_arready
  .s_axi_rdata(pspin_axil_rdata),        // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(pspin_axil_rresp),        // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid(pspin_axil_rvalid),      // output wire s_axi_rvalid
  .s_axi_rready(pspin_axil_rready),      // input wire s_axi_rready
  .m_axi_awaddr(pspin_axi_narrow_awaddr),      // output wire [31 : 0] m_axi_awaddr
  .m_axi_awlen(pspin_axi_narrow_awlen),        // output wire [7 : 0] m_axi_awlen
  .m_axi_awsize(pspin_axi_narrow_awsize),      // output wire [2 : 0] m_axi_awsize
  .m_axi_awburst(pspin_axi_narrow_awburst),    // output wire [1 : 0] m_axi_awburst
  .m_axi_awlock(pspin_axi_narrow_awlock),      // output wire [0 : 0] m_axi_awlock
  .m_axi_awcache(pspin_axi_narrow_awcache),    // output wire [3 : 0] m_axi_awcache
  .m_axi_awprot(pspin_axi_narrow_awprot),      // output wire [2 : 0] m_axi_awprot
  .m_axi_awregion(pspin_axi_narrow_awregion),  // output wire [3 : 0] m_axi_awregion
  .m_axi_awqos(pspin_axi_narrow_awqos),        // output wire [3 : 0] m_axi_awqos
  .m_axi_awvalid(pspin_axi_narrow_awvalid),    // output wire m_axi_awvalid
  .m_axi_awready(pspin_axi_narrow_awready),    // input wire m_axi_awready
  .m_axi_wdata(pspin_axi_narrow_wdata),        // output wire [31 : 0] m_axi_wdata
  .m_axi_wstrb(pspin_axi_narrow_wstrb),        // output wire [3 : 0] m_axi_wstrb
  .m_axi_wlast(pspin_axi_narrow_wlast),        // output wire m_axi_wlast
  .m_axi_wvalid(pspin_axi_narrow_wvalid),      // output wire m_axi_wvalid
  .m_axi_wready(pspin_axi_narrow_wready),      // input wire m_axi_wready
  .m_axi_bresp(pspin_axi_narrow_bresp),        // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid(pspin_axi_narrow_bvalid),      // input wire m_axi_bvalid
  .m_axi_bready(pspin_axi_narrow_bready),      // output wire m_axi_bready
  .m_axi_araddr(pspin_axi_narrow_araddr),      // output wire [31 : 0] m_axi_araddr
  .m_axi_arlen(pspin_axi_narrow_arlen),        // output wire [7 : 0] m_axi_arlen
  .m_axi_arsize(pspin_axi_narrow_arsize),      // output wire [2 : 0] m_axi_arsize
  .m_axi_arburst(pspin_axi_narrow_arburst),    // output wire [1 : 0] m_axi_arburst
  .m_axi_arlock(pspin_axi_narrow_arlock),      // output wire [0 : 0] m_axi_arlock
  .m_axi_arcache(pspin_axi_narrow_arcache),    // output wire [3 : 0] m_axi_arcache
  .m_axi_arprot(pspin_axi_narrow_arprot),      // output wire [2 : 0] m_axi_arprot
  .m_axi_arregion(pspin_axi_narrow_arregion),  // output wire [3 : 0] m_axi_arregion
  .m_axi_arqos(pspin_axi_narrow_arqos),        // output wire [3 : 0] m_axi_arqos
  .m_axi_arvalid(pspin_axi_narrow_arvalid),    // output wire m_axi_arvalid
  .m_axi_arready(pspin_axi_narrow_arready),    // input wire m_axi_arready
  .m_axi_rdata(pspin_axi_narrow_rdata),        // input wire [31 : 0] m_axi_rdata
  .m_axi_rresp(pspin_axi_narrow_rresp),        // input wire [1 : 0] m_axi_rresp
  .m_axi_rlast(pspin_axi_narrow_rlast),        // input wire m_axi_rlast
  .m_axi_rvalid(pspin_axi_narrow_rvalid),      // input wire m_axi_rvalid
  .m_axi_rready(pspin_axi_narrow_rready)      // output wire m_axi_rready
);

axis_async_fifo #(
    .DEPTH(IF_CDC_FIFO_DEPTH),
    .DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .ID_ENABLE(1),
    .ID_WIDTH(AXIS_IF_RX_ID_WIDTH),
    .DEST_ENABLE(1),
    .DEST_WIDTH(AXIS_IF_RX_DEST_WIDTH),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_IF_RX_USER_WIDTH),
    .FRAME_FIFO(0),
    .DROP_WHEN_FULL(0)
) i_if_cdc_fifo_rx_to_pspin (
    .s_clk(clk),
    .s_rst(rst),

    .s_axis_tdata(`SLICE(s_axis_if_rx_tdata, 0, AXIS_IF_DATA_WIDTH)),
    .s_axis_tkeep(`SLICE(s_axis_if_rx_tkeep, 0, AXIS_IF_KEEP_WIDTH)),
    .s_axis_tvalid(`SLICE(s_axis_if_rx_tvalid, 0, 1)),
    .s_axis_tready(`SLICE(s_axis_if_rx_tready, 0, 1)),
    .s_axis_tlast(`SLICE(s_axis_if_rx_tlast, 0, 1)),
    .s_axis_tid(`SLICE(s_axis_if_rx_tid, 0, AXIS_IF_RX_ID_WIDTH)),
    .s_axis_tdest(`SLICE(s_axis_if_rx_tdest, 0, AXIS_IF_RX_DEST_WIDTH)),
    .s_axis_tuser(`SLICE(s_axis_if_rx_tuser, 0, AXIS_IF_RX_USER_WIDTH)),

    .m_clk(pspin_clk),
    .m_rst(pspin_rst),
    .m_axis_tdata(s_axis_nic_rx_tdata),
    .m_axis_tkeep(s_axis_nic_rx_tkeep),
    .m_axis_tvalid(s_axis_nic_rx_tvalid),
    .m_axis_tready(s_axis_nic_rx_tready),
    .m_axis_tlast(s_axis_nic_rx_tlast),
    .m_axis_tid(s_axis_nic_rx_tid),
    .m_axis_tdest(s_axis_nic_rx_tdest),
    .m_axis_tuser(s_axis_nic_rx_tuser),

    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

axis_async_fifo #(
    .DEPTH(IF_CDC_FIFO_DEPTH),
    .DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .ID_ENABLE(1),
    .ID_WIDTH(AXIS_IF_RX_ID_WIDTH),
    .DEST_ENABLE(1),
    .DEST_WIDTH(AXIS_IF_RX_DEST_WIDTH),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_IF_RX_USER_WIDTH),
    .FRAME_FIFO(0),
    .DROP_WHEN_FULL(0)
) i_if_cdc_fifo_rx_to_nic (
    .s_clk(pspin_clk),
    .s_rst(pspin_rst),
    .s_axis_tdata(m_axis_nic_rx_tdata),
    .s_axis_tkeep(m_axis_nic_rx_tkeep),
    .s_axis_tvalid(m_axis_nic_rx_tvalid),
    .s_axis_tready(m_axis_nic_rx_tready),
    .s_axis_tlast(m_axis_nic_rx_tlast),
    .s_axis_tid(m_axis_nic_rx_tid),
    .s_axis_tdest(m_axis_nic_rx_tdest),
    .s_axis_tuser(m_axis_nic_rx_tuser),

    .m_clk(clk),
    .m_rst(rst),
    .m_axis_tdata(`SLICE(m_axis_if_rx_tdata, 0, AXIS_IF_DATA_WIDTH)),
    .m_axis_tkeep(`SLICE(m_axis_if_rx_tkeep, 0, AXIS_IF_KEEP_WIDTH)),
    .m_axis_tvalid(`SLICE(m_axis_if_rx_tvalid, 0, 1)),
    .m_axis_tready(`SLICE(m_axis_if_rx_tready, 0, 1)),
    .m_axis_tlast(`SLICE(m_axis_if_rx_tlast, 0, 1)),
    .m_axis_tid(`SLICE(m_axis_if_rx_tid, 0, AXIS_IF_RX_ID_WIDTH)),
    .m_axis_tdest(`SLICE(m_axis_if_rx_tdest, 0, AXIS_IF_RX_DEST_WIDTH)),
    .m_axis_tuser(`SLICE(m_axis_if_rx_tuser, 0, AXIS_IF_RX_USER_WIDTH)),

    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

axis_async_fifo #(
    .DEPTH(IF_CDC_FIFO_DEPTH),
    .DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .KEEP_ENABLE(1),
    .KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .ID_ENABLE(1),
    .ID_WIDTH(AXIS_IF_TX_ID_WIDTH),
    .DEST_ENABLE(1),
    .DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_IF_TX_USER_WIDTH),
    .FRAME_FIFO(0),
    .DROP_WHEN_FULL(0)
) i_if_cdc_fifo_tx_to_nic (
    .s_clk(pspin_clk),
    .s_rst(pspin_rst),
    .s_axis_tdata(m_axis_nic_tx_tdata),
    .s_axis_tkeep(m_axis_nic_tx_tkeep),
    .s_axis_tvalid(m_axis_nic_tx_tvalid),
    .s_axis_tready(m_axis_nic_tx_tready),
    .s_axis_tlast(m_axis_nic_tx_tlast),
    .s_axis_tid(m_axis_nic_tx_tid),
    .s_axis_tdest(m_axis_nic_tx_tdest),
    .s_axis_tuser(m_axis_nic_tx_tuser),

    .m_clk(clk),
    .m_rst(rst),
    .m_axis_tdata(m_axis_nic_fast_tx_tdata),
    .m_axis_tkeep(m_axis_nic_fast_tx_tkeep),
    .m_axis_tvalid(m_axis_nic_fast_tx_tvalid),
    .m_axis_tready(m_axis_nic_fast_tx_tready),
    .m_axis_tlast(m_axis_nic_fast_tx_tlast),
    .m_axis_tid(m_axis_nic_fast_tx_tid),
    .m_axis_tdest(m_axis_nic_fast_tx_tdest),
    .m_axis_tuser(m_axis_nic_fast_tx_tuser),

    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

wire [AXIS_IF_DATA_WIDTH-1:0]                   s_axis_if_0_tx_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0]                   s_axis_if_0_tx_tkeep;
wire                                            s_axis_if_0_tx_tvalid;
wire                                            s_axis_if_0_tx_tready;
wire                                            s_axis_if_0_tx_tlast;
wire [AXIS_IF_TX_ID_WIDTH-1:0]                  s_axis_if_0_tx_tid;
wire [AXIS_IF_TX_DEST_WIDTH-1:0]                s_axis_if_0_tx_tdest;
wire [AXIS_IF_TX_USER_WIDTH-1:0]                s_axis_if_0_tx_tuser;

wire [AXIS_IF_DATA_WIDTH-1:0]                   m_axis_if_0_tx_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0]                   m_axis_if_0_tx_tkeep;
wire                                            m_axis_if_0_tx_tvalid;
wire                                            m_axis_if_0_tx_tready;
wire                                            m_axis_if_0_tx_tlast;
wire [AXIS_IF_TX_ID_WIDTH-1:0]                  m_axis_if_0_tx_tid;
wire [AXIS_IF_TX_DEST_WIDTH-1:0]                m_axis_if_0_tx_tdest;
wire [AXIS_IF_TX_USER_WIDTH-1:0]                m_axis_if_0_tx_tuser;

assign s_axis_if_0_tx_tdata = `SLICE(s_axis_if_tx_tdata, 0, AXIS_IF_DATA_WIDTH);
assign s_axis_if_0_tx_tkeep = `SLICE(s_axis_if_tx_tkeep, 0, AXIS_IF_KEEP_WIDTH);
assign s_axis_if_0_tx_tvalid = `SLICE(s_axis_if_tx_tvalid, 0, 1);
assign `SLICE(s_axis_if_tx_tready, 0, 1) = s_axis_if_0_tx_tready;
assign s_axis_if_0_tx_tlast = `SLICE(s_axis_if_tx_tlast, 0, 1);
assign s_axis_if_0_tx_tid = `SLICE(s_axis_if_tx_tid, 0, AXIS_IF_TX_ID_WIDTH);
assign s_axis_if_0_tx_tdest = `SLICE(s_axis_if_tx_tdest, 0, AXIS_IF_TX_DEST_WIDTH);
assign s_axis_if_0_tx_tuser = `SLICE(s_axis_if_tx_tuser, 0, AXIS_IF_TX_USER_WIDTH);

assign `SLICE(m_axis_if_tx_tdata, 0, AXIS_IF_DATA_WIDTH) = m_axis_if_0_tx_tdata;
assign `SLICE(m_axis_if_tx_tkeep, 0, AXIS_IF_KEEP_WIDTH) = m_axis_if_0_tx_tkeep;
assign `SLICE(m_axis_if_tx_tvalid, 0, 1) = m_axis_if_0_tx_tvalid;
assign m_axis_if_0_tx_tready = `SLICE(m_axis_if_tx_tready, 0, 1);
assign `SLICE(m_axis_if_tx_tlast, 0, 1) = m_axis_if_0_tx_tlast;
assign `SLICE(m_axis_if_tx_tid, 0, AXIS_IF_TX_ID_WIDTH) = m_axis_if_0_tx_tid;
assign `SLICE(m_axis_if_tx_tdest, 0, AXIS_IF_TX_DEST_WIDTH) = m_axis_if_0_tx_tdest;
assign `SLICE(m_axis_if_tx_tuser, 0, AXIS_IF_TX_USER_WIDTH) = m_axis_if_0_tx_tuser;

axis_arb_mux #(
    .S_COUNT(2),
    .DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .ID_ENABLE(1),
    .S_ID_WIDTH(AXIS_IF_TX_ID_WIDTH),
    .DEST_ENABLE(1),
    .DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
    .USER_ENABLE(1),
    .USER_WIDTH(AXIS_IF_TX_USER_WIDTH)
) i_tx_arb_mux (
    .clk(clk),
    .rst(rst),

    // PsPIN tx has priority
    .s_axis_tdata({s_axis_if_0_tx_tdata, m_axis_nic_fast_tx_tdata}),
    .s_axis_tkeep({s_axis_if_0_tx_tkeep, m_axis_nic_fast_tx_tkeep}),
    .s_axis_tvalid({s_axis_if_0_tx_tvalid, m_axis_nic_fast_tx_tvalid}),
    .s_axis_tready({s_axis_if_0_tx_tready, m_axis_nic_fast_tx_tready}),
    .s_axis_tlast({s_axis_if_0_tx_tlast, m_axis_nic_fast_tx_tlast}),
    .s_axis_tid({s_axis_if_0_tx_tid, m_axis_nic_fast_tx_tid}),
    .s_axis_tdest({s_axis_if_0_tx_tdest, m_axis_nic_fast_tx_tdest}),
    .s_axis_tuser({s_axis_if_0_tx_tuser, m_axis_nic_fast_tx_tuser}),

    .m_axis_tdata(m_axis_if_0_tx_tdata),
    .m_axis_tkeep(m_axis_if_0_tx_tkeep),
    .m_axis_tvalid(m_axis_if_0_tx_tvalid),
    .m_axis_tready(m_axis_if_0_tx_tready),
    .m_axis_tlast(m_axis_if_0_tx_tlast),
    .m_axis_tid(m_axis_if_0_tx_tid),
    .m_axis_tdest(m_axis_if_0_tx_tdest),
    .m_axis_tuser(m_axis_if_0_tx_tuser)
);

axi_dwidth_converter_0 i_pspin_upsize (
  .s_axi_aclk(pspin_clk),          // input wire s_axi_aclk
  .s_axi_aresetn(!pspin_rst),    // input wire s_axi_aresetn
  .s_axi_awaddr(pspin_axi_narrow_awaddr),      // input wire [31 : 0] s_axi_awaddr
  .s_axi_awlen(pspin_axi_narrow_awlen),        // input wire [7 : 0] s_axi_awlen
  .s_axi_awsize(pspin_axi_narrow_awsize),      // input wire [2 : 0] s_axi_awsize
  .s_axi_awburst(pspin_axi_narrow_awburst),    // input wire [1 : 0] s_axi_awburst
  .s_axi_awlock(pspin_axi_narrow_awlock),      // input wire [0 : 0] s_axi_awlock
  .s_axi_awcache(pspin_axi_narrow_awcache),    // input wire [3 : 0] s_axi_awcache
  .s_axi_awprot(pspin_axi_narrow_awprot),      // input wire [2 : 0] s_axi_awprot
  .s_axi_awregion(pspin_axi_narrow_awregion),  // input wire [3 : 0] s_axi_awregion
  .s_axi_awqos(pspin_axi_narrow_awqos),        // input wire [3 : 0] s_axi_awqos
  .s_axi_awvalid(pspin_axi_narrow_awvalid),    // input wire s_axi_awvalid
  .s_axi_awready(pspin_axi_narrow_awready),    // output wire s_axi_awready
  .s_axi_wdata(pspin_axi_narrow_wdata),        // input wire [31 : 0] s_axi_wdata
  .s_axi_wstrb(pspin_axi_narrow_wstrb),        // input wire [3 : 0] s_axi_wstrb
  .s_axi_wlast(pspin_axi_narrow_wlast),        // input wire s_axi_wlast
  .s_axi_wvalid(pspin_axi_narrow_wvalid),      // input wire s_axi_wvalid
  .s_axi_wready(pspin_axi_narrow_wready),      // output wire s_axi_wready
  .s_axi_bresp(pspin_axi_narrow_bresp),        // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid(pspin_axi_narrow_bvalid),      // output wire s_axi_bvalid
  .s_axi_bready(pspin_axi_narrow_bready),      // input wire s_axi_bready
  .s_axi_araddr(pspin_axi_narrow_araddr),      // input wire [31 : 0] s_axi_araddr
  .s_axi_arlen(pspin_axi_narrow_arlen),        // input wire [7 : 0] s_axi_arlen
  .s_axi_arsize(pspin_axi_narrow_arsize),      // input wire [2 : 0] s_axi_arsize
  .s_axi_arburst(pspin_axi_narrow_arburst),    // input wire [1 : 0] s_axi_arburst
  .s_axi_arlock(pspin_axi_narrow_arlock),      // input wire [0 : 0] s_axi_arlock
  .s_axi_arcache(pspin_axi_narrow_arcache),    // input wire [3 : 0] s_axi_arcache
  .s_axi_arprot(pspin_axi_narrow_arprot),      // input wire [2 : 0] s_axi_arprot
  .s_axi_arregion(pspin_axi_narrow_arregion),  // input wire [3 : 0] s_axi_arregion
  .s_axi_arqos(pspin_axi_narrow_arqos),        // input wire [3 : 0] s_axi_arqos
  .s_axi_arvalid(pspin_axi_narrow_arvalid),    // input wire s_axi_arvalid
  .s_axi_arready(pspin_axi_narrow_arready),    // output wire s_axi_arready
  .s_axi_rdata(pspin_axi_narrow_rdata),        // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp(pspin_axi_narrow_rresp),        // output wire [1 : 0] s_axi_rresp
  .s_axi_rlast(pspin_axi_narrow_rlast),        // output wire s_axi_rlast
  .s_axi_rvalid(pspin_axi_narrow_rvalid),      // output wire s_axi_rvalid
  .s_axi_rready(pspin_axi_narrow_rready),      // input wire s_axi_rready
  .m_axi_awaddr(pspin_axi_full_awaddr),      // output wire [31 : 0] m_axi_awaddr
  .m_axi_awlen(pspin_axi_full_awlen),        // output wire [7 : 0] m_axi_awlen
  .m_axi_awsize(pspin_axi_full_awsize),      // output wire [2 : 0] m_axi_awsize
  .m_axi_awburst(pspin_axi_full_awburst),    // output wire [1 : 0] m_axi_awburst
  .m_axi_awlock(pspin_axi_full_awlock),      // output wire [0 : 0] m_axi_awlock
  .m_axi_awcache(pspin_axi_full_awcache),    // output wire [3 : 0] m_axi_awcache
  .m_axi_awprot(pspin_axi_full_awprot),      // output wire [2 : 0] m_axi_awprot
  .m_axi_awregion(pspin_axi_full_awregion),  // output wire [3 : 0] m_axi_awregion
  .m_axi_awqos(pspin_axi_full_awqos),        // output wire [3 : 0] m_axi_awqos
  .m_axi_awvalid(pspin_axi_full_awvalid),    // output wire m_axi_awvalid
  .m_axi_awready(pspin_axi_full_awready),    // input wire m_axi_awready
  .m_axi_wdata(pspin_axi_full_wdata),        // output wire [511 : 0] m_axi_wdata
  .m_axi_wstrb(pspin_axi_full_wstrb),        // output wire [63 : 0] m_axi_wstrb
  .m_axi_wlast(pspin_axi_full_wlast),        // output wire m_axi_wlast
  .m_axi_wvalid(pspin_axi_full_wvalid),      // output wire m_axi_wvalid
  .m_axi_wready(pspin_axi_full_wready),      // input wire m_axi_wready
  .m_axi_bresp(pspin_axi_full_bresp),        // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid(pspin_axi_full_bvalid),      // input wire m_axi_bvalid
  .m_axi_bready(pspin_axi_full_bready),      // output wire m_axi_bready
  .m_axi_araddr(pspin_axi_full_araddr),      // output wire [31 : 0] m_axi_araddr
  .m_axi_arlen(pspin_axi_full_arlen),        // output wire [7 : 0] m_axi_arlen
  .m_axi_arsize(pspin_axi_full_arsize),      // output wire [2 : 0] m_axi_arsize
  .m_axi_arburst(pspin_axi_full_arburst),    // output wire [1 : 0] m_axi_arburst
  .m_axi_arlock(pspin_axi_full_arlock),      // output wire [0 : 0] m_axi_arlock
  .m_axi_arcache(pspin_axi_full_arcache),    // output wire [3 : 0] m_axi_arcache
  .m_axi_arprot(pspin_axi_full_arprot),      // output wire [2 : 0] m_axi_arprot
  .m_axi_arregion(pspin_axi_full_arregion),  // output wire [3 : 0] m_axi_arregion
  .m_axi_arqos(pspin_axi_full_arqos),        // output wire [3 : 0] m_axi_arqos
  .m_axi_arvalid(pspin_axi_full_arvalid),    // output wire m_axi_arvalid
  .m_axi_arready(pspin_axi_full_arready),    // input wire m_axi_arready
  .m_axi_rdata(pspin_axi_full_rdata),        // input wire [511 : 0] m_axi_rdata
  .m_axi_rresp(pspin_axi_full_rresp),        // input wire [1 : 0] m_axi_rresp
  .m_axi_rlast(pspin_axi_full_rlast),        // input wire m_axi_rlast
  .m_axi_rvalid(pspin_axi_full_rvalid),      // input wire m_axi_rvalid
  .m_axi_rready(pspin_axi_full_rready)      // output wire m_axi_rready
);

pspin_ingress_datapath #(
    .UMATCH_MATCHER_LEN(UMATCH_MATCHER_LEN),
    .UMATCH_MTU(UMATCH_MTU),
    .UMATCH_BUF_FRAMES(UMATCH_BUF_FRAMES),

    .AXIS_IF_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .AXIS_IF_KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .AXIS_IF_RX_ID_WIDTH(AXIS_IF_RX_ID_WIDTH),
    .AXIS_IF_RX_DEST_WIDTH(AXIS_IF_RX_DEST_WIDTH),
    .AXIS_IF_RX_USER_WIDTH(AXIS_IF_RX_USER_WIDTH),

    .AXI_HOST_ADDR_WIDTH(AXI_HOST_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),

    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH),
    .MSG_ID_WIDTH(MSG_ID_WIDTH),

    .BUF_START(BUF_START),
    .BUF_SIZE(BUF_SIZE)
) i_ingress_path (
    .clk(pspin_clk),
    .rstn(!pspin_rst && !aux_rst),

{{- m.call_group("me", m.connect_wire, "match") }}

{{- m.call_group("her", m.connect_wire, "her_gen") }}
{{- m.call_group("her_meta", m.connect_wire, "her_gen") }}

    .s_axis_nic_rx_tdata,
    .s_axis_nic_rx_tkeep,
    .s_axis_nic_rx_tvalid,
    .s_axis_nic_rx_tready,
    .s_axis_nic_rx_tlast,
    .s_axis_nic_rx_tid,
    .s_axis_nic_rx_tdest,
    .s_axis_nic_rx_tuser,

    .m_axis_nic_rx_tdata,
    .m_axis_nic_rx_tkeep,
    .m_axis_nic_rx_tvalid,
    .m_axis_nic_rx_tready,
    .m_axis_nic_rx_tlast,
    .m_axis_nic_rx_tid,
    .m_axis_nic_rx_tdest,
    .m_axis_nic_rx_tuser,

    .m_axi_pspin_ni_awid,
    .m_axi_pspin_ni_awaddr,
    .m_axi_pspin_ni_awlen,
    .m_axi_pspin_ni_awsize,
    .m_axi_pspin_ni_awburst,
    .m_axi_pspin_ni_awlock,
    .m_axi_pspin_ni_awcache,
    .m_axi_pspin_ni_awprot,
    .m_axi_pspin_ni_awvalid,
    .m_axi_pspin_ni_awready,
    .m_axi_pspin_ni_wdata,
    .m_axi_pspin_ni_wstrb,
    .m_axi_pspin_ni_wlast,
    .m_axi_pspin_ni_wvalid,
    .m_axi_pspin_ni_wready,
    .m_axi_pspin_ni_bid,
    .m_axi_pspin_ni_bresp,
    .m_axi_pspin_ni_bvalid,
    .m_axi_pspin_ni_bready,
    .m_axi_pspin_ni_arid,
    .m_axi_pspin_ni_araddr,
    .m_axi_pspin_ni_arlen,
    .m_axi_pspin_ni_arsize,
    .m_axi_pspin_ni_arburst,
    .m_axi_pspin_ni_arlock,
    .m_axi_pspin_ni_arcache,
    .m_axi_pspin_ni_arprot,
    .m_axi_pspin_ni_arvalid,
    .m_axi_pspin_ni_arready,
    .m_axi_pspin_ni_rid,
    .m_axi_pspin_ni_rdata,
    .m_axi_pspin_ni_rresp,
    .m_axi_pspin_ni_rlast,
    .m_axi_pspin_ni_rvalid,
    .m_axi_pspin_ni_rready,

    .her_ready,
    .her_valid,
    .her_msgid,
    .her_is_eom,
    .her_addr,
    .her_size,
    .her_xfer_size,
{{- m.call_group("her_meta", m.connect_wire, "her_meta") }}

    .feedback_ready,
    .feedback_valid,
    .feedback_her_addr,
    .feedback_her_size,
    .feedback_msgid,

    .alloc_dropped_pkts
);

pspin_egress_datapath #(
    .AXI_HOST_ADDR_WIDTH(AXI_HOST_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),

    .AXIS_IF_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .AXIS_IF_KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .AXIS_IF_TX_ID_WIDTH(AXIS_IF_TX_ID_WIDTH),
    .AXIS_IF_TX_DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
    .AXIS_IF_TX_USER_WIDTH(AXIS_IF_TX_USER_WIDTH),

    .NUM_CLUSTERS(NUM_CLUSTERS),
    .NUM_CORES(NUM_CORES),
    .NUM_HPU_CMDS(NUM_HPU_CMDS),

    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH)
) i_egress_path (
    .clk(pspin_clk),
    .rstn(!pspin_rst && !aux_rst),

    .m_axi_pspin_no_awid,
    .m_axi_pspin_no_awaddr,
    .m_axi_pspin_no_awlen,
    .m_axi_pspin_no_awsize,
    .m_axi_pspin_no_awburst,
    .m_axi_pspin_no_awlock,
    .m_axi_pspin_no_awcache,
    .m_axi_pspin_no_awprot,
    .m_axi_pspin_no_awvalid,
    .m_axi_pspin_no_awready,
    .m_axi_pspin_no_wdata,
    .m_axi_pspin_no_wstrb,
    .m_axi_pspin_no_wlast,
    .m_axi_pspin_no_wvalid,
    .m_axi_pspin_no_wready,
    .m_axi_pspin_no_bid,
    .m_axi_pspin_no_bresp,
    .m_axi_pspin_no_bvalid,
    .m_axi_pspin_no_bready,
    .m_axi_pspin_no_arid,
    .m_axi_pspin_no_araddr,
    .m_axi_pspin_no_arlen,
    .m_axi_pspin_no_arsize,
    .m_axi_pspin_no_arburst,
    .m_axi_pspin_no_arlock,
    .m_axi_pspin_no_arcache,
    .m_axi_pspin_no_arprot,
    .m_axi_pspin_no_arvalid,
    .m_axi_pspin_no_arready,
    .m_axi_pspin_no_rid,
    .m_axi_pspin_no_rdata,
    .m_axi_pspin_no_rresp,
    .m_axi_pspin_no_rlast,
    .m_axi_pspin_no_rvalid,
    .m_axi_pspin_no_rready,

    .m_axis_nic_tx_tdata,
    .m_axis_nic_tx_tkeep,
    .m_axis_nic_tx_tvalid,
    .m_axis_nic_tx_tready,
    .m_axis_nic_tx_tlast,
    .m_axis_nic_tx_tid,
    .m_axis_nic_tx_tdest,
    .m_axis_nic_tx_tuser,

    .nic_cmd_req_ready,
    .nic_cmd_req_valid,
    .nic_cmd_req_id,
    .nic_cmd_req_nid,
    .nic_cmd_req_fid,
    .nic_cmd_req_src_addr,
    .nic_cmd_req_length,
    .nic_cmd_req_user_ptr,

    .nic_cmd_resp_valid,
    .nic_cmd_resp_id,

    .egress_dma_last_error
);

dma_psdpram #(
    .SIZE(4096),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .PIPELINE(RAM_PIPELINE)
) i_dma_wr_ram (
    .clk,
    .rst,

    .wr_cmd_be(hostdma_ram_wr_cmd_be),
    .wr_cmd_addr(hostdma_ram_wr_cmd_addr),
    .wr_cmd_data(hostdma_ram_wr_cmd_data),
    .wr_cmd_valid(hostdma_ram_wr_cmd_valid),
    .wr_cmd_ready(hostdma_ram_wr_cmd_ready),
    .wr_done(hostdma_ram_wr_done),

    .rd_cmd_addr(data_dma_ram_rd_cmd_addr),
    .rd_cmd_valid(data_dma_ram_rd_cmd_valid),
    .rd_cmd_ready(data_dma_ram_rd_cmd_ready),
    .rd_resp_data(data_dma_ram_rd_resp_data),
    .rd_resp_valid(data_dma_ram_rd_resp_valid),
    .rd_resp_ready(data_dma_ram_rd_resp_ready)
);

dma_psdpram #(
    .SIZE(4096),
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .PIPELINE(RAM_PIPELINE)
) i_dma_rd_ram (
    .clk,
    .rst,

    .wr_cmd_be(data_dma_ram_wr_cmd_be),
    .wr_cmd_addr(data_dma_ram_wr_cmd_addr),
    .wr_cmd_data(data_dma_ram_wr_cmd_data),
    .wr_cmd_valid(data_dma_ram_wr_cmd_valid),
    .wr_cmd_ready(data_dma_ram_wr_cmd_ready),
    .wr_done(data_dma_ram_wr_done),

    .rd_cmd_addr(hostdma_ram_rd_cmd_addr),
    .rd_cmd_valid(hostdma_ram_rd_cmd_valid),
    .rd_cmd_ready(hostdma_ram_rd_cmd_ready),
    .rd_resp_data(hostdma_ram_rd_resp_data),
    .rd_resp_valid(hostdma_ram_rd_resp_valid),
    .rd_resp_ready(hostdma_ram_rd_resp_ready)
);

pspin_hostmem_dma #(
    .DMA_IMM_ENABLE(DMA_IMM_ENABLE),
    .DMA_IMM_WIDTH(DMA_IMM_WIDTH),
    .DMA_LEN_WIDTH(DMA_LEN_WIDTH),
    .DMA_TAG_WIDTH(DMA_TAG_WIDTH),
    .RAM_SEL_WIDTH(RAM_SEL_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .RAM_SEG_COUNT(RAM_SEG_COUNT),
    .RAM_SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .RAM_SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),

    .ADDR_WIDTH(AXI_HOST_ADDR_WIDTH),
    .DATA_WIDTH(AXI_DATA_WIDTH),
    .STRB_WIDTH(AXI_STRB_WIDTH),
    .ID_WIDTH(AXI_ID_WIDTH)
) i_hostmem_dma (
    .clk,
    .rstn(!rst),

    .s_axi_awid            (s_axi_pspin_dma_fast_awid),
    .s_axi_awaddr          (s_axi_pspin_dma_fast_awaddr),
    .s_axi_awlen           (s_axi_pspin_dma_fast_awlen),
    .s_axi_awsize          (s_axi_pspin_dma_fast_awsize),
    .s_axi_awburst         (s_axi_pspin_dma_fast_awburst),
    .s_axi_awlock          (s_axi_pspin_dma_fast_awlock),
    .s_axi_awcache         (s_axi_pspin_dma_fast_awcache),
    .s_axi_awprot          (s_axi_pspin_dma_fast_awprot),
    .s_axi_awqos           (s_axi_pspin_dma_fast_awqos),
    .s_axi_awregion        (s_axi_pspin_dma_fast_awregion),
    .s_axi_awuser          (1'b0),
    .s_axi_awvalid         (s_axi_pspin_dma_fast_awvalid),
    .s_axi_awready         (s_axi_pspin_dma_fast_awready),
    .s_axi_wdata           (s_axi_pspin_dma_fast_wdata),
    .s_axi_wstrb           (s_axi_pspin_dma_fast_wstrb),
    .s_axi_wlast           (s_axi_pspin_dma_fast_wlast),
    .s_axi_wuser           (1'b0),
    .s_axi_wvalid          (s_axi_pspin_dma_fast_wvalid),
    .s_axi_wready          (s_axi_pspin_dma_fast_wready),
    .s_axi_bid             (s_axi_pspin_dma_fast_bid),
    .s_axi_bresp           (s_axi_pspin_dma_fast_bresp),
    .s_axi_buser           (),
    .s_axi_bvalid          (s_axi_pspin_dma_fast_bvalid),
    .s_axi_bready          (s_axi_pspin_dma_fast_bready),
    .s_axi_arid            (s_axi_pspin_dma_fast_arid),
    .s_axi_araddr          (s_axi_pspin_dma_fast_araddr),
    .s_axi_arlen           (s_axi_pspin_dma_fast_arlen),
    .s_axi_arsize          (s_axi_pspin_dma_fast_arsize),
    .s_axi_arburst         (s_axi_pspin_dma_fast_arburst),
    .s_axi_arlock          (s_axi_pspin_dma_fast_arlock),
    .s_axi_arcache         (s_axi_pspin_dma_fast_arcache),
    .s_axi_arprot          (s_axi_pspin_dma_fast_arprot),
    .s_axi_arqos           (s_axi_pspin_dma_fast_arqos),
    .s_axi_arregion        (s_axi_pspin_dma_fast_arregion),
    .s_axi_aruser          (1'b0),
    .s_axi_arvalid         (s_axi_pspin_dma_fast_arvalid),
    .s_axi_arready         (s_axi_pspin_dma_fast_arready),
    .s_axi_rid             (s_axi_pspin_dma_fast_rid),
    .s_axi_rdata           (s_axi_pspin_dma_fast_rdata),
    .s_axi_rresp           (s_axi_pspin_dma_fast_rresp),
    .s_axi_rlast           (s_axi_pspin_dma_fast_rlast),
    .s_axi_ruser           (),
    .s_axi_rvalid          (s_axi_pspin_dma_fast_rvalid),
    .s_axi_rready          (s_axi_pspin_dma_fast_rready),

    .m_axis_read_desc_dma_addr(m_axis_data_dma_read_desc_dma_addr),
    .m_axis_read_desc_ram_sel(m_axis_data_dma_read_desc_ram_sel),
    .m_axis_read_desc_ram_addr(m_axis_data_dma_read_desc_ram_addr),
    .m_axis_read_desc_len(m_axis_data_dma_read_desc_len),
    .m_axis_read_desc_tag(m_axis_data_dma_read_desc_tag),
    .m_axis_read_desc_valid(m_axis_data_dma_read_desc_valid),
    .m_axis_read_desc_ready(m_axis_data_dma_read_desc_ready),

    .s_axis_read_desc_status_tag(s_axis_data_dma_read_desc_status_tag),
    .s_axis_read_desc_status_error(s_axis_data_dma_read_desc_status_error),
    .s_axis_read_desc_status_valid(s_axis_data_dma_read_desc_status_valid),

    .m_axis_write_desc_dma_addr(m_axis_data_dma_write_desc_dma_addr),
    .m_axis_write_desc_ram_sel(m_axis_data_dma_write_desc_ram_sel),
    .m_axis_write_desc_ram_addr(m_axis_data_dma_write_desc_ram_addr),
    .m_axis_write_desc_imm(m_axis_data_dma_write_desc_imm),
    .m_axis_write_desc_imm_en(m_axis_data_dma_write_desc_imm_en),
    .m_axis_write_desc_len(m_axis_data_dma_write_desc_len),
    .m_axis_write_desc_tag(m_axis_data_dma_write_desc_tag),
    .m_axis_write_desc_valid(m_axis_data_dma_write_desc_valid),
    .m_axis_write_desc_ready(m_axis_data_dma_write_desc_ready),

    .s_axis_write_desc_status_tag(s_axis_data_dma_write_desc_status_tag),
    .s_axis_write_desc_status_error(s_axis_data_dma_write_desc_status_error),
    .s_axis_write_desc_status_valid(s_axis_data_dma_write_desc_status_valid),

    .ram_wr_cmd_be(hostdma_ram_wr_cmd_be),
    .ram_wr_cmd_addr(hostdma_ram_wr_cmd_addr),
    .ram_wr_cmd_data(hostdma_ram_wr_cmd_data),
    .ram_wr_cmd_valid(hostdma_ram_wr_cmd_valid),
    .ram_wr_cmd_ready(hostdma_ram_wr_cmd_ready),
    .ram_wr_done(hostdma_ram_wr_done),

    .ram_rd_cmd_addr(hostdma_ram_rd_cmd_addr),
    .ram_rd_cmd_valid(hostdma_ram_rd_cmd_valid),
    .ram_rd_cmd_ready(hostdma_ram_rd_cmd_ready),
    .ram_rd_resp_data(hostdma_ram_rd_resp_data),
    .ram_rd_resp_valid(hostdma_ram_rd_resp_valid),
    .ram_rd_resp_ready(hostdma_ram_rd_resp_ready)
);

pspin_wrap #(
    .N_CLUSTERS(NUM_CLUSTERS), // pspin_cfg_pkg::NUM_CLUSTERS
    .N_MPQ(NUM_MPQ)     // pspin_cfg_pkg::NUM_MPQ
)
pspin_inst (
    .clk_i(pspin_clk),
    .rst_ni(!pspin_rst && !aux_rst),

    .cl_fetch_en_i(cl_fetch_en),
    .cl_eoc_o(cl_eoc),
    .cl_busy_o(cl_busy),

    .mpq_full_o(mpq_full),

    .host_master_aw_addr_o(s_axi_pspin_dma_awaddr),
    .host_master_aw_prot_o(s_axi_pspin_dma_awprot),
    .host_master_aw_region_o(s_axi_pspin_dma_awregion),
    .host_master_aw_len_o(s_axi_pspin_dma_awlen),
    .host_master_aw_size_o(s_axi_pspin_dma_awsize),
    .host_master_aw_burst_o(s_axi_pspin_dma_awburst),
    .host_master_aw_lock_o(s_axi_pspin_dma_awlock),
    .host_master_aw_atop_o(),
    .host_master_aw_cache_o(s_axi_pspin_dma_awcache),
    .host_master_aw_qos_o(s_axi_pspin_dma_awqos),
    .host_master_aw_id_o(s_axi_pspin_dma_awid),
    .host_master_aw_user_o(),
    .host_master_aw_valid_o(s_axi_pspin_dma_awvalid),
    .host_master_aw_ready_i(s_axi_pspin_dma_awready),

    .host_master_ar_addr_o(s_axi_pspin_dma_araddr),
    .host_master_ar_prot_o(s_axi_pspin_dma_arprot),
    .host_master_ar_region_o(s_axi_pspin_dma_arregion),
    .host_master_ar_len_o(s_axi_pspin_dma_arlen),
    .host_master_ar_size_o(s_axi_pspin_dma_arsize),
    .host_master_ar_burst_o(s_axi_pspin_dma_arburst),
    .host_master_ar_lock_o(s_axi_pspin_dma_arlock),
    .host_master_ar_cache_o(s_axi_pspin_dma_arcache),
    .host_master_ar_qos_o(s_axi_pspin_dma_arqos),
    .host_master_ar_id_o(s_axi_pspin_dma_arid),
    .host_master_ar_user_o(),
    .host_master_ar_valid_o(s_axi_pspin_dma_arvalid),
    .host_master_ar_ready_i(s_axi_pspin_dma_arready),

    .host_master_w_data_o(s_axi_pspin_dma_wdata),
    .host_master_w_strb_o(s_axi_pspin_dma_wstrb),
    .host_master_w_user_o(),
    .host_master_w_last_o(s_axi_pspin_dma_wlast),
    .host_master_w_valid_o(s_axi_pspin_dma_wvalid),
    .host_master_w_ready_i(s_axi_pspin_dma_wready),

    .host_master_r_data_i(s_axi_pspin_dma_rdata),
    .host_master_r_resp_i(s_axi_pspin_dma_rresp),
    .host_master_r_last_i(s_axi_pspin_dma_rlast),
    .host_master_r_id_i(s_axi_pspin_dma_rid),
    .host_master_r_user_i(1'b0),
    .host_master_r_valid_i(s_axi_pspin_dma_rvalid),
    .host_master_r_ready_o(s_axi_pspin_dma_rready),

    .host_master_b_resp_i(s_axi_pspin_dma_bresp),
    .host_master_b_id_i(s_axi_pspin_dma_bid),
    .host_master_b_user_i(1'b0),
    .host_master_b_valid_i(s_axi_pspin_dma_bvalid),
    .host_master_b_ready_o(s_axi_pspin_dma_bready),

    .host_slave_aw_addr_i   (pspin_axi_full_awaddr),
    .host_slave_aw_prot_i   (pspin_axi_full_awprot),
    .host_slave_aw_region_i (pspin_axi_full_awregion),
    .host_slave_aw_len_i    (pspin_axi_full_awlen),
    .host_slave_aw_size_i   (pspin_axi_full_awsize),
    .host_slave_aw_burst_i  (pspin_axi_full_awburst),
    .host_slave_aw_lock_i   (pspin_axi_full_awlock),
    .host_slave_aw_atop_i   (5'b0),
    .host_slave_aw_cache_i  (pspin_axi_full_awcache),
    .host_slave_aw_qos_i    (pspin_axi_full_awqos),
    .host_slave_aw_id_i     (6'b0),
    .host_slave_aw_user_i   (4'b0),
    .host_slave_aw_valid_i  (pspin_axi_full_awvalid),
    .host_slave_aw_ready_o  (pspin_axi_full_awready),

    .host_slave_ar_addr_i   (pspin_axi_full_araddr),
    .host_slave_ar_prot_i   (pspin_axi_full_arprot),
    .host_slave_ar_region_i (pspin_axi_full_arregion),
    .host_slave_ar_len_i    (pspin_axi_full_arlen),
    .host_slave_ar_size_i   (pspin_axi_full_arsize),
    .host_slave_ar_burst_i  (pspin_axi_full_arburst),
    .host_slave_ar_lock_i   (pspin_axi_full_arlock),
    .host_slave_ar_cache_i  (pspin_axi_full_arcache),
    .host_slave_ar_qos_i    (pspin_axi_full_arqos),
    .host_slave_ar_id_i     (6'b0),
    .host_slave_ar_user_i   (4'b0),
    .host_slave_ar_valid_i  (pspin_axi_full_arvalid),
    .host_slave_ar_ready_o  (pspin_axi_full_arready),

    .host_slave_w_data_i    (pspin_axi_full_wdata),
    .host_slave_w_strb_i    (pspin_axi_full_wstrb),
    .host_slave_w_user_i    (4'b0),
    .host_slave_w_last_i    (pspin_axi_full_wlast),
    .host_slave_w_valid_i   (pspin_axi_full_wvalid),
    .host_slave_w_ready_o   (pspin_axi_full_wready),

    .host_slave_r_data_o    (pspin_axi_full_rdata),
    .host_slave_r_resp_o    (pspin_axi_full_rresp),
    .host_slave_r_last_o    (pspin_axi_full_rlast),
    .host_slave_r_id_o      (6'b0),
    .host_slave_r_user_o    (4'b0),
    .host_slave_r_valid_o   (pspin_axi_full_rvalid),
    .host_slave_r_ready_i   (pspin_axi_full_rready),

    .host_slave_b_resp_o    (pspin_axi_full_bresp),
    .host_slave_b_id_o      (6'b0),
    .host_slave_b_user_o    (4'b0),
    .host_slave_b_valid_o   (pspin_axi_full_bvalid),
    .host_slave_b_ready_i   (pspin_axi_full_bready),

    .ni_slave_aw_addr_i(m_axi_pspin_ni_awaddr), //
    .ni_slave_aw_prot_i(m_axi_pspin_ni_awprot), //
    .ni_slave_aw_region_i(4'b0),
    .ni_slave_aw_len_i(m_axi_pspin_ni_awlen), //
    .ni_slave_aw_size_i(m_axi_pspin_ni_awsize), //
    .ni_slave_aw_burst_i(m_axi_pspin_ni_awburst), //
    .ni_slave_aw_lock_i(m_axi_pspin_ni_awlock), //
    .ni_slave_aw_atop_i(6'b0),
    .ni_slave_aw_cache_i(m_axi_pspin_ni_awcache), //
    .ni_slave_aw_qos_i(4'b0),
    .ni_slave_aw_id_i(m_axi_pspin_ni_awid), //
    .ni_slave_aw_user_i(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .ni_slave_aw_valid_i(m_axi_pspin_ni_awvalid), //
    .ni_slave_aw_ready_o(m_axi_pspin_ni_awready), //

    .ni_slave_ar_addr_i(m_axi_pspin_ni_araddr), //
    .ni_slave_ar_prot_i(m_axi_pspin_ni_arprot), //
    .ni_slave_ar_region_i(4'b0),
    .ni_slave_ar_len_i(m_axi_pspin_ni_arlen), //
    .ni_slave_ar_size_i(m_axi_pspin_ni_arsize), //
    .ni_slave_ar_burst_i(m_axi_pspin_ni_arburst), //
    .ni_slave_ar_lock_i(m_axi_pspin_ni_arlock), //
    .ni_slave_ar_cache_i(m_axi_pspin_ni_arcache), //
    .ni_slave_ar_qos_i(4'b0),
    .ni_slave_ar_id_i(m_axi_pspin_ni_arid), //
    .ni_slave_ar_user_i(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .ni_slave_ar_valid_i(m_axi_pspin_ni_arvalid), //
    .ni_slave_ar_ready_o(m_axi_pspin_ni_arready), //

    .ni_slave_w_data_i(m_axi_pspin_ni_wdata), //
    .ni_slave_w_strb_i(m_axi_pspin_ni_wstrb), //
    .ni_slave_w_user_i(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .ni_slave_w_last_i(m_axi_pspin_ni_wlast), //
    .ni_slave_w_valid_i(m_axi_pspin_ni_wvalid), //
    .ni_slave_w_ready_o(m_axi_pspin_ni_wready), //

    .ni_slave_r_data_o(m_axi_pspin_ni_rdata), //
    .ni_slave_r_resp_o(m_axi_pspin_ni_rresp), //
    .ni_slave_r_last_o(m_axi_pspin_ni_rlast), //
    .ni_slave_r_id_o(m_axi_pspin_ni_rid), //
    .ni_slave_r_user_o(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .ni_slave_r_valid_o(m_axi_pspin_ni_rvalid), //
    .ni_slave_r_ready_i(m_axi_pspin_ni_rready), //

    .ni_slave_b_resp_o(m_axi_pspin_ni_bresp), //
    .ni_slave_b_id_o(m_axi_pspin_ni_bid), //
    .ni_slave_b_user_o(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .ni_slave_b_valid_o(m_axi_pspin_ni_bvalid), //
    .ni_slave_b_ready_i(m_axi_pspin_ni_bready), //

    .no_slave_aw_addr_i(m_axi_pspin_no_awaddr), //
    .no_slave_aw_prot_i(m_axi_pspin_no_awprot), //
    .no_slave_aw_region_i(4'b0),
    .no_slave_aw_len_i(m_axi_pspin_no_awlen), //
    .no_slave_aw_size_i(m_axi_pspin_no_awsize), //
    .no_slave_aw_burst_i(m_axi_pspin_no_awburst), //
    .no_slave_aw_lock_i(m_axi_pspin_no_awlock), //
    .no_slave_aw_atop_i(6'b0),
    .no_slave_aw_cache_i(m_axi_pspin_no_awcache), //
    .no_slave_aw_qos_i(4'b0),
    .no_slave_aw_id_i(m_axi_pspin_no_awid), //
    .no_slave_aw_user_i(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .no_slave_aw_valid_i(m_axi_pspin_no_awvalid), //
    .no_slave_aw_ready_o(m_axi_pspin_no_awready), //

    .no_slave_ar_addr_i(m_axi_pspin_no_araddr), //
    .no_slave_ar_prot_i(m_axi_pspin_no_arprot), //
    .no_slave_ar_region_i(4'b0),
    .no_slave_ar_len_i(m_axi_pspin_no_arlen), //
    .no_slave_ar_size_i(m_axi_pspin_no_arsize), //
    .no_slave_ar_burst_i(m_axi_pspin_no_arburst), //
    .no_slave_ar_lock_i(m_axi_pspin_no_arlock), //
    .no_slave_ar_cache_i(m_axi_pspin_no_arcache), //
    .no_slave_ar_qos_i(4'b0),
    .no_slave_ar_id_i(m_axi_pspin_no_arid), //
    .no_slave_ar_user_i(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .no_slave_ar_valid_i(m_axi_pspin_no_arvalid), //
    .no_slave_ar_ready_o(m_axi_pspin_no_arready), //

    .no_slave_w_data_i(m_axi_pspin_no_wdata), //
    .no_slave_w_strb_i(m_axi_pspin_no_wstrb), //
    .no_slave_w_user_i(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .no_slave_w_last_i(m_axi_pspin_no_wlast), //
    .no_slave_w_valid_i(m_axi_pspin_no_wvalid), //
    .no_slave_w_ready_o(m_axi_pspin_no_wready), //

    .no_slave_r_data_o(m_axi_pspin_no_rdata), //
    .no_slave_r_resp_o(m_axi_pspin_no_rresp), //
    .no_slave_r_last_o(m_axi_pspin_no_rlast), //
    .no_slave_r_id_o(m_axi_pspin_no_rid), //
    .no_slave_r_user_o(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .no_slave_r_valid_o(m_axi_pspin_no_rvalid), //
    .no_slave_r_ready_i(m_axi_pspin_no_rready), //

    .no_slave_b_resp_o(m_axi_pspin_no_bresp), //
    .no_slave_b_id_o(m_axi_pspin_no_bid), //
    .no_slave_b_user_o(4'b0), // pulp_cluster_cfg_pkg::AXI_UW
    .no_slave_b_valid_o(m_axi_pspin_no_bvalid), //
    .no_slave_b_ready_i(m_axi_pspin_no_bready), //

    .nic_cmd_req_ready_i(nic_cmd_req_ready),
    .nic_cmd_req_valid_o(nic_cmd_req_valid),
    .nic_cmd_req_id_o(nic_cmd_req_id),
    .nic_cmd_req_nid_o(nic_cmd_req_nid),
    .nic_cmd_req_fid_o(nic_cmd_req_fid),
    .nic_cmd_req_src_addr_o(nic_cmd_req_src_addr),
    .nic_cmd_req_length_o(nic_cmd_req_length),
    .nic_cmd_req_user_ptr_o(nic_cmd_req_user_ptr),

    .nic_cmd_resp_valid_i(nic_cmd_resp_valid),
    .nic_cmd_resp_id_i(nic_cmd_resp_id),

    .her_ready_o(her_ready),
    .her_valid_i(her_valid),
    .her_msgid_i(her_msgid),
    .her_is_eom_i(her_is_eom),
    .her_addr_i(her_addr),
    .her_size_i(her_size),
    .her_xfer_size_i(her_xfer_size),

{%- macro connect_pspin(signal_name, sg) %}
    .{{ signal_name }}_{{ sg.name }}_i({{ signal_name }}_{{ sg.name }}),
{%- endmacro %}
{{- m.call_group("her_meta", connect_pspin, "her_meta") }}

    .feedback_ready_i(feedback_ready),
    .feedback_valid_o(feedback_valid),
    .feedback_her_addr_o(feedback_her_addr),
    .feedback_her_size_o(feedback_her_size),
    .feedback_msgid_o(feedback_msgid),

    .stdout_rd_en,
    .stdout_dout,
    .stdout_data_valid
);

/*
 * AXI-Lite master interface (control to NIC)
 */
assign m_axil_ctrl_awaddr = 0;
assign m_axil_ctrl_awprot = 0;
assign m_axil_ctrl_awvalid = 1'b0;
assign m_axil_ctrl_wdata = 0;
assign m_axil_ctrl_wstrb = 0;
assign m_axil_ctrl_wvalid = 1'b0;
assign m_axil_ctrl_bready = 1'b1;
assign m_axil_ctrl_araddr = 0;
assign m_axil_ctrl_arprot = 0;
assign m_axil_ctrl_arvalid = 1'b0;
assign m_axil_ctrl_rready = 1'b1;

/*
 * DMA interface (control)
 */
assign m_axis_ctrl_dma_read_desc_dma_addr = 0;
assign m_axis_ctrl_dma_read_desc_ram_sel = 0;
assign m_axis_ctrl_dma_read_desc_ram_addr = 0;
assign m_axis_ctrl_dma_read_desc_len = 0;
assign m_axis_ctrl_dma_read_desc_tag = 0;
assign m_axis_ctrl_dma_read_desc_valid = 1'b0;
assign m_axis_ctrl_dma_write_desc_dma_addr = 0;
assign m_axis_ctrl_dma_write_desc_ram_sel = 0;
assign m_axis_ctrl_dma_write_desc_ram_addr = 0;
assign m_axis_ctrl_dma_write_desc_imm = 0;
assign m_axis_ctrl_dma_write_desc_imm_en = 0;
assign m_axis_ctrl_dma_write_desc_len = 0;
assign m_axis_ctrl_dma_write_desc_tag = 0;
assign m_axis_ctrl_dma_write_desc_valid = 1'b0;

assign ctrl_dma_ram_wr_cmd_ready = 1'b1;
assign ctrl_dma_ram_wr_done = ctrl_dma_ram_wr_cmd_valid;
assign ctrl_dma_ram_rd_cmd_ready = ctrl_dma_ram_rd_resp_ready;
assign ctrl_dma_ram_rd_resp_data = 0;
assign ctrl_dma_ram_rd_resp_valid = ctrl_dma_ram_rd_cmd_valid;

/*
 * Ethernet (direct MAC interface - lowest latency raw traffic)
 */
assign m_axis_direct_tx_tdata = s_axis_direct_tx_tdata;
assign m_axis_direct_tx_tkeep = s_axis_direct_tx_tkeep;
assign m_axis_direct_tx_tvalid = s_axis_direct_tx_tvalid;
assign s_axis_direct_tx_tready = m_axis_direct_tx_tready;
assign m_axis_direct_tx_tlast = s_axis_direct_tx_tlast;
assign m_axis_direct_tx_tuser = s_axis_direct_tx_tuser;

assign m_axis_direct_tx_cpl_ts = s_axis_direct_tx_cpl_ts;
assign m_axis_direct_tx_cpl_tag = s_axis_direct_tx_cpl_tag;
assign m_axis_direct_tx_cpl_valid = s_axis_direct_tx_cpl_valid;
assign s_axis_direct_tx_cpl_ready = m_axis_direct_tx_cpl_ready;

assign m_axis_direct_rx_tdata = s_axis_direct_rx_tdata;
assign m_axis_direct_rx_tkeep = s_axis_direct_rx_tkeep;
assign m_axis_direct_rx_tvalid = s_axis_direct_rx_tvalid;
assign s_axis_direct_rx_tready = m_axis_direct_rx_tready;
assign m_axis_direct_rx_tlast = s_axis_direct_rx_tlast;
assign m_axis_direct_rx_tuser = s_axis_direct_rx_tuser;

/*
 * Ethernet (synchronous MAC interface - low latency raw traffic)
 */
assign m_axis_sync_tx_tdata = s_axis_sync_tx_tdata;
assign m_axis_sync_tx_tkeep = s_axis_sync_tx_tkeep;
assign m_axis_sync_tx_tvalid = s_axis_sync_tx_tvalid;
assign s_axis_sync_tx_tready = m_axis_sync_tx_tready;
assign m_axis_sync_tx_tlast = s_axis_sync_tx_tlast;
assign m_axis_sync_tx_tuser = s_axis_sync_tx_tuser;

assign m_axis_sync_tx_cpl_ts = s_axis_sync_tx_cpl_ts;
assign m_axis_sync_tx_cpl_tag = s_axis_sync_tx_cpl_tag;
assign m_axis_sync_tx_cpl_valid = s_axis_sync_tx_cpl_valid;
assign s_axis_sync_tx_cpl_ready = m_axis_sync_tx_cpl_ready;

assign m_axis_sync_rx_tdata = s_axis_sync_rx_tdata;
assign m_axis_sync_rx_tkeep = s_axis_sync_rx_tkeep;
assign m_axis_sync_rx_tvalid = s_axis_sync_rx_tvalid;
assign s_axis_sync_rx_tready = m_axis_sync_rx_tready;
assign m_axis_sync_rx_tlast = s_axis_sync_rx_tlast;
assign m_axis_sync_rx_tuser = s_axis_sync_rx_tuser;

/*
 * Ethernet (internal at interface module)
 */
generate
if (IF_COUNT == 2) begin
    assign `SLICE(m_axis_if_tx_tdata, 1, AXIS_IF_DATA_WIDTH) = `SLICE(s_axis_if_tx_tdata, 1, AXIS_IF_DATA_WIDTH);
    assign `SLICE(m_axis_if_tx_tkeep, 1, AXIS_IF_KEEP_WIDTH) = `SLICE(s_axis_if_tx_tkeep, 1, AXIS_IF_KEEP_WIDTH);
    assign `SLICE(m_axis_if_tx_tvalid, 1, 1) = `SLICE(s_axis_if_tx_tvalid, 1, 1);
    assign `SLICE(s_axis_if_tx_tready, 1, 1) = `SLICE(m_axis_if_tx_tready, 1, 1);
    assign `SLICE(m_axis_if_tx_tlast, 1, 1) = `SLICE(s_axis_if_tx_tlast, 1, 1);
    assign `SLICE(m_axis_if_tx_tid, 1, AXIS_IF_TX_ID_WIDTH) = `SLICE(s_axis_if_tx_tid, 1, AXIS_IF_TX_ID_WIDTH);
    assign `SLICE(m_axis_if_tx_tdest, 1, AXIS_IF_TX_DEST_WIDTH) = `SLICE(s_axis_if_tx_tdest, 1, AXIS_IF_TX_DEST_WIDTH);
    assign `SLICE(m_axis_if_tx_tuser, 1, AXIS_IF_TX_USER_WIDTH) = `SLICE(s_axis_if_tx_tuser, 1, AXIS_IF_TX_USER_WIDTH);
end
endgenerate

// PTP timestamps - we do not need this in PsPIN
assign m_axis_if_tx_cpl_ts = s_axis_if_tx_cpl_ts;
assign m_axis_if_tx_cpl_tag = s_axis_if_tx_cpl_tag;
assign m_axis_if_tx_cpl_valid = s_axis_if_tx_cpl_valid;
assign s_axis_if_tx_cpl_ready = m_axis_if_tx_cpl_ready;

// passthrough IF#1
generate
if (IF_COUNT == 2) begin
    assign `SLICE(m_axis_if_rx_tdata, 1, AXIS_IF_DATA_WIDTH) = `SLICE(s_axis_if_rx_tdata, 1, AXIS_IF_DATA_WIDTH);
    assign `SLICE(m_axis_if_rx_tkeep, 1, AXIS_IF_KEEP_WIDTH) = `SLICE(s_axis_if_rx_tkeep, 1, AXIS_IF_KEEP_WIDTH);
    assign `SLICE(m_axis_if_rx_tvalid, 1, 1) = `SLICE(s_axis_if_rx_tvalid, 1, 1);
    assign `SLICE(s_axis_if_rx_tready, 1, 1) = `SLICE(m_axis_if_rx_tready, 1, 1);
    assign `SLICE(m_axis_if_rx_tlast, 1, 1) = `SLICE(s_axis_if_rx_tlast, 1, 1);
    assign `SLICE(m_axis_if_rx_tid, 1, AXIS_IF_RX_ID_WIDTH) = `SLICE(s_axis_if_rx_tid, 1, AXIS_IF_RX_ID_WIDTH);
    assign `SLICE(m_axis_if_rx_tdest, 1, AXIS_IF_RX_DEST_WIDTH) = `SLICE(s_axis_if_rx_tdest, 1, AXIS_IF_RX_DEST_WIDTH);
    assign `SLICE(m_axis_if_rx_tuser, 1, AXIS_IF_RX_USER_WIDTH) = `SLICE(s_axis_if_rx_tuser, 1, AXIS_IF_RX_USER_WIDTH);
end
endgenerate

/*
 * DDR
 */
assign m_axi_ddr_awid = 0;
assign m_axi_ddr_awaddr = 0;
assign m_axi_ddr_awlen = 0;
assign m_axi_ddr_awsize = 0;
assign m_axi_ddr_awburst = 0;
assign m_axi_ddr_awlock = 0;
assign m_axi_ddr_awcache = 0;
assign m_axi_ddr_awprot = 0;
assign m_axi_ddr_awqos = 0;
assign m_axi_ddr_awuser = 0;
assign m_axi_ddr_awvalid = 0;
assign m_axi_ddr_wdata = 0;
assign m_axi_ddr_wstrb = 0;
assign m_axi_ddr_wlast = 0;
assign m_axi_ddr_wuser = 0;
assign m_axi_ddr_wvalid = 0;
assign m_axi_ddr_bready = 0;
assign m_axi_ddr_arid = 0;
assign m_axi_ddr_araddr = 0;
assign m_axi_ddr_arlen = 0;
assign m_axi_ddr_arsize = 0;
assign m_axi_ddr_arburst = 0;
assign m_axi_ddr_arlock = 0;
assign m_axi_ddr_arcache = 0;
assign m_axi_ddr_arprot = 0;
assign m_axi_ddr_arqos = 0;
assign m_axi_ddr_aruser = 0;
assign m_axi_ddr_arvalid = 0;
assign m_axi_ddr_rready = 0;

/*
 * HBM
 */
assign m_axi_hbm_awid = 0;
assign m_axi_hbm_awaddr = 0;
assign m_axi_hbm_awlen = 0;
assign m_axi_hbm_awsize = 0;
assign m_axi_hbm_awburst = 0;
assign m_axi_hbm_awlock = 0;
assign m_axi_hbm_awcache = 0;
assign m_axi_hbm_awprot = 0;
assign m_axi_hbm_awqos = 0;
assign m_axi_hbm_awuser = 0;
assign m_axi_hbm_awvalid = 0;
assign m_axi_hbm_wdata = 0;
assign m_axi_hbm_wstrb = 0;
assign m_axi_hbm_wlast = 0;
assign m_axi_hbm_wuser = 0;
assign m_axi_hbm_wvalid = 0;
assign m_axi_hbm_bready = 0;
assign m_axi_hbm_arid = 0;
assign m_axi_hbm_araddr = 0;
assign m_axi_hbm_arlen = 0;
assign m_axi_hbm_arsize = 0;
assign m_axi_hbm_arburst = 0;
assign m_axi_hbm_arlock = 0;
assign m_axi_hbm_arcache = 0;
assign m_axi_hbm_arprot = 0;
assign m_axi_hbm_arqos = 0;
assign m_axi_hbm_aruser = 0;
assign m_axi_hbm_arvalid = 0;
assign m_axi_hbm_rready = 0;

/*
 * Statistics increment output
 */
assign m_axis_stat_tdata = 0;
assign m_axis_stat_tid = 0;
assign m_axis_stat_tvalid = 1'b0;

/*
 * GPIO
 */
assign gpio_out = 0;

/*
 * JTAG
 */
assign jtag_tdo = jtag_tdi;

endmodule

`resetall
