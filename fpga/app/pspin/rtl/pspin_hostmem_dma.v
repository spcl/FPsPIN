/**
 * PsPIN host memory DMA adapter
 *
 * The host memory DMA adapter is a AXI4 slave that issues Corundum DMA
 * requests.  This is a simple one-to-one mapping implementation and we do
 * not perform requests combining.
 *
 * This module does not contain the DMA memory between the client and
 * interface, for the sake of ease of testing (verilog-pcie only provides
 * a model for the RAM and not a RAM master).  The RAM should be instantiated
 * in the parent module.
 */

`timescale 1ns / 1ps
module pspin_hostmem_dma #(
    parameter DMA_IMM_ENABLE = 0,
    parameter DMA_IMM_WIDTH = 32,
    parameter DMA_LEN_WIDTH = 16,
    parameter DMA_TAG_WIDTH = 16,
    parameter RAM_SEL_WIDTH = 4,
    parameter RAM_ADDR_WIDTH = 20,
    parameter RAM_SEG_COUNT = 2,
    parameter RAM_SEG_DATA_WIDTH = 256*2/RAM_SEG_COUNT,
    parameter RAM_SEG_BE_WIDTH = RAM_SEG_DATA_WIDTH/8,
    parameter RAM_SEG_ADDR_WIDTH = RAM_ADDR_WIDTH-$clog2(RAM_SEG_COUNT*RAM_SEG_BE_WIDTH),

    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 512,
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    parameter ID_WIDTH = 8,
    parameter AWUSER_WIDTH = 1,
    parameter WUSER_WIDTH = 1,
    parameter BUSER_WIDTH = 1,
    parameter ARUSER_WIDTH = 1,
    parameter RUSER_WIDTH = 1
) (
    input  wire                                           clk,
    input  wire                                           rstn,

    /*
     * DMA read descriptor output (data)
     */
    output wire [ADDR_WIDTH-1:0]                          m_axis_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_read_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_read_desc_ram_addr,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_read_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_read_desc_tag,
    output wire                                           m_axis_read_desc_valid,
    input  wire                                           m_axis_read_desc_ready,

    /*
     * DMA read descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_read_desc_status_tag,
    input  wire [3:0]                                     s_axis_read_desc_status_error,
    input  wire                                           s_axis_read_desc_status_valid,

    /*
     * DMA write descriptor output (data)
     */
    output wire [ADDR_WIDTH-1:0]                          m_axis_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_write_desc_ram_sel,
    output wire [RAM_ADDR_WIDTH-1:0]                      m_axis_write_desc_ram_addr,
    output wire [DMA_IMM_WIDTH-1:0]                       m_axis_write_desc_imm,
    output wire                                           m_axis_write_desc_imm_en,
    output wire [DMA_LEN_WIDTH-1:0]                       m_axis_write_desc_len,
    output wire [DMA_TAG_WIDTH-1:0]                       m_axis_write_desc_tag,
    output wire                                           m_axis_write_desc_valid,
    input  wire                                           m_axis_write_desc_ready,

    /*
     * DMA write descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                       s_axis_write_desc_status_tag,
    input  wire [3:0]                                     s_axis_write_desc_status_error,
    input  wire                                           s_axis_write_desc_status_valid,

    /*
     * DMA RAM interface (data)
     */
    output wire [RAM_SEG_COUNT*RAM_SEG_BE_WIDTH-1:0]      ram_wr_cmd_be,
    output wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    ram_wr_cmd_addr,
    output wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    ram_wr_cmd_data,
    output wire [RAM_SEG_COUNT-1:0]                       ram_wr_cmd_valid,
    input  wire [RAM_SEG_COUNT-1:0]                       ram_wr_cmd_ready,
    input  wire [RAM_SEG_COUNT-1:0]                       ram_wr_done,

    output wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]    ram_rd_cmd_addr,
    output wire [RAM_SEG_COUNT-1:0]                       ram_rd_cmd_valid,
    input  wire [RAM_SEG_COUNT-1:0]                       ram_rd_cmd_ready,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]    ram_rd_resp_data,
    input  wire [RAM_SEG_COUNT-1:0]                       ram_rd_resp_valid,
    output wire [RAM_SEG_COUNT-1:0]                       ram_rd_resp_ready,

    /*
     * AXI slave interface
     */
    input  wire [ID_WIDTH-1:0]                            s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]                          s_axi_awaddr,
    input  wire [7:0]                                     s_axi_awlen,
    input  wire [2:0]                                     s_axi_awsize,
    input  wire [1:0]                                     s_axi_awburst,
    input  wire                                           s_axi_awlock,
    input  wire [3:0]                                     s_axi_awcache,
    input  wire [2:0]                                     s_axi_awprot,
    input  wire [3:0]                                     s_axi_awqos,
    input  wire [3:0]                                     s_axi_awregion,
    input  wire [AWUSER_WIDTH-1:0]                        s_axi_awuser,
    input  wire                                           s_axi_awvalid,
    output wire                                           s_axi_awready,
    input  wire [DATA_WIDTH-1:0]                          s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]                          s_axi_wstrb,
    input  wire                                           s_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]                         s_axi_wuser,
    input  wire                                           s_axi_wvalid,
    output wire                                           s_axi_wready,
    output wire [ID_WIDTH-1:0]                            s_axi_bid,
    output wire [1:0]                                     s_axi_bresp,
    output wire [BUSER_WIDTH-1:0]                         s_axi_buser,
    output wire                                           s_axi_bvalid,
    input  wire                                           s_axi_bready,
    input  wire [ID_WIDTH-1:0]                            s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]                          s_axi_araddr,
    input  wire [7:0]                                     s_axi_arlen,
    input  wire [2:0]                                     s_axi_arsize,
    input  wire [1:0]                                     s_axi_arburst,
    input  wire                                           s_axi_arlock,
    input  wire [3:0]                                     s_axi_arcache,
    input  wire [2:0]                                     s_axi_arprot,
    input  wire [3:0]                                     s_axi_arqos,
    input  wire [3:0]                                     s_axi_arregion,
    input  wire [ARUSER_WIDTH-1:0]                        s_axi_aruser,
    input  wire                                           s_axi_arvalid,
    output wire                                           s_axi_arready,
    output wire [ID_WIDTH-1:0]                            s_axi_rid,
    output wire [DATA_WIDTH-1:0]                          s_axi_rdata,
    output wire [1:0]                                     s_axi_rresp,
    output wire                                           s_axi_rlast,
    output wire [RUSER_WIDTH-1:0]                         s_axi_ruser,
    output wire                                           s_axi_rvalid,
    input  wire                                           s_axi_rready
);

pspin_hostmem_dma_rd #(
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
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .AWUSER_WIDTH(AWUSER_WIDTH),
    .WUSER_WIDTH(WUSER_WIDTH),
    .BUSER_WIDTH(BUSER_WIDTH),
    .ARUSER_WIDTH(ARUSER_WIDTH),
    .RUSER_WIDTH(RUSER_WIDTH)
) i_rd (
    .clk,
    .rstn,

    .m_axis_read_desc_dma_addr,
    .m_axis_read_desc_ram_sel,
    .m_axis_read_desc_ram_addr,
    .m_axis_read_desc_len,
    .m_axis_read_desc_tag,
    .m_axis_read_desc_valid,
    .m_axis_read_desc_ready,

    .s_axis_read_desc_status_tag,
    .s_axis_read_desc_status_error,
    .s_axis_read_desc_status_valid,

    .ram_rd_cmd_addr,
    .ram_rd_cmd_valid,
    .ram_rd_cmd_ready,
    .ram_rd_resp_data,
    .ram_rd_resp_valid,
    .ram_rd_resp_ready,

    .s_axi_arid,
    .s_axi_araddr,
    .s_axi_arlen,
    .s_axi_arsize,
    .s_axi_arburst,
    .s_axi_arlock,
    .s_axi_arcache,
    .s_axi_arprot,
    .s_axi_arqos,
    .s_axi_arregion,
    .s_axi_aruser,
    .s_axi_arvalid,
    .s_axi_arready,
    .s_axi_rid,
    .s_axi_rdata,
    .s_axi_rresp,
    .s_axi_rlast,
    .s_axi_ruser,
    .s_axi_rvalid,
    .s_axi_rready
);

pspin_hostmem_dma_wr #(
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
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .AWUSER_WIDTH(AWUSER_WIDTH),
    .WUSER_WIDTH(WUSER_WIDTH),
    .BUSER_WIDTH(BUSER_WIDTH),
    .ARUSER_WIDTH(ARUSER_WIDTH),
    .RUSER_WIDTH(RUSER_WIDTH)
) i_wr (
    .clk,
    .rstn,

    .m_axis_write_desc_dma_addr,
    .m_axis_write_desc_ram_sel,
    .m_axis_write_desc_ram_addr,
    .m_axis_write_desc_imm,
    .m_axis_write_desc_imm_en,
    .m_axis_write_desc_len,
    .m_axis_write_desc_tag,
    .m_axis_write_desc_valid,
    .m_axis_write_desc_ready,

    .s_axis_write_desc_status_tag,
    .s_axis_write_desc_status_error,
    .s_axis_write_desc_status_valid,

    .ram_wr_cmd_be,
    .ram_wr_cmd_addr,
    .ram_wr_cmd_data,
    .ram_wr_cmd_valid,
    .ram_wr_cmd_ready,
    .ram_wr_done,

    .s_axi_awid,
    .s_axi_awaddr,
    .s_axi_awlen,
    .s_axi_awsize,
    .s_axi_awburst,
    .s_axi_awlock,
    .s_axi_awcache,
    .s_axi_awprot,
    .s_axi_awqos,
    .s_axi_awregion,
    .s_axi_awuser,
    .s_axi_awvalid,
    .s_axi_awready,
    .s_axi_wdata,
    .s_axi_wstrb,
    .s_axi_wlast,
    .s_axi_wuser,
    .s_axi_wvalid,
    .s_axi_wready,
    .s_axi_bid,
    .s_axi_bresp,
    .s_axi_buser,
    .s_axi_bvalid,
    .s_axi_bready
);

endmodule