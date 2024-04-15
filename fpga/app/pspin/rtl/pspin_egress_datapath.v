/**
 * PsPIN Egress Datapath
 *
 * Takes NIC command from PsPIN and DMAs the requested buffer in the packet
 * memory to Corundum's output path.
 *
 * Following discussion in the sPIN Town Square (https://chat.spcl.inf.ethz.ch/spin/pl/mfstskqqwbf98br1yk6a484xga),
 * we currently ignore the NID, FID, and user_ptr fields of the NIC command.
 * A better model for connection handover is needed.
 */

`timescale 1ns / 1ps
module pspin_egress_datapath #(
    parameter AXI_HOST_ADDR_WIDTH = 64, // pspin_cfg_pkg::HOST_AXI_AW
    parameter AXI_DATA_WIDTH = 512, // pspin_cfg_pkg::data_t
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    parameter AXI_ID_WIDTH = 8,

    parameter AXIS_IF_DATA_WIDTH = 512,
    parameter AXIS_IF_KEEP_WIDTH = AXIS_IF_DATA_WIDTH/8,
    parameter AXIS_IF_TX_ID_WIDTH = 12,
    parameter AXIS_IF_TX_DEST_WIDTH = 4,
    parameter AXIS_IF_TX_USER_WIDTH = 16,

    parameter NUM_CLUSTERS = 2,
    parameter NUM_CORES = 8,
    parameter NUM_HPU_CMDS = 4,
    parameter CMD_ID_WIDTH = $clog2(NUM_CLUSTERS) + $clog2(NUM_CORES) + $clog2(NUM_HPU_CMDS),

    parameter LEN_WIDTH = 32,
    parameter TAG_WIDTH = 32

) (
    input  wire                                            clk,
    input  wire                                            rstn,

    // to PsPIN NIC Inbound
    output wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_no_awid,
    output wire [AXI_ADDR_WIDTH-1:0]                       m_axi_pspin_no_awaddr,
    output wire [7:0]                                      m_axi_pspin_no_awlen,
    output wire [2:0]                                      m_axi_pspin_no_awsize,
    output wire [1:0]                                      m_axi_pspin_no_awburst,
    output wire                                            m_axi_pspin_no_awlock,
    output wire [3:0]                                      m_axi_pspin_no_awcache,
    output wire [2:0]                                      m_axi_pspin_no_awprot,
    output wire                                            m_axi_pspin_no_awvalid,
    input  wire                                            m_axi_pspin_no_awready,
    output wire [AXI_DATA_WIDTH-1:0]                       m_axi_pspin_no_wdata,
    output wire [AXI_STRB_WIDTH-1:0]                       m_axi_pspin_no_wstrb,
    output wire                                            m_axi_pspin_no_wlast,
    output wire                                            m_axi_pspin_no_wvalid,
    input  wire                                            m_axi_pspin_no_wready,
    input  wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_no_bid,
    input  wire [1:0]                                      m_axi_pspin_no_bresp,
    input  wire                                            m_axi_pspin_no_bvalid,
    output wire                                            m_axi_pspin_no_bready,
    output wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_no_arid,
    output wire [AXI_ADDR_WIDTH-1:0]                       m_axi_pspin_no_araddr,
    output wire [7:0]                                      m_axi_pspin_no_arlen,
    output wire [2:0]                                      m_axi_pspin_no_arsize,
    output wire [1:0]                                      m_axi_pspin_no_arburst,
    output wire                                            m_axi_pspin_no_arlock,
    output wire [3:0]                                      m_axi_pspin_no_arcache,
    output wire [2:0]                                      m_axi_pspin_no_arprot,
    output wire                                            m_axi_pspin_no_arvalid,
    input  wire                                            m_axi_pspin_no_arready,
    input  wire [AXI_ID_WIDTH-1:0]                         m_axi_pspin_no_rid,
    input  wire [AXI_DATA_WIDTH-1:0]                       m_axi_pspin_no_rdata,
    input  wire [1:0]                                      m_axi_pspin_no_rresp,
    input  wire                                            m_axi_pspin_no_rlast,
    input  wire                                            m_axi_pspin_no_rvalid,
    output wire                                            m_axi_pspin_no_rready,

    // to NIC - unmatched
    output wire [AXIS_IF_DATA_WIDTH-1:0]                   m_axis_nic_tx_tdata,
    output wire [AXIS_IF_KEEP_WIDTH-1:0]                   m_axis_nic_tx_tkeep,
    output wire                                            m_axis_nic_tx_tvalid,
    input  wire                                            m_axis_nic_tx_tready,
    output wire                                            m_axis_nic_tx_tlast,
    output wire [AXIS_IF_TX_ID_WIDTH-1:0]                  m_axis_nic_tx_tid,
    output wire [AXIS_IF_TX_DEST_WIDTH-1:0]                m_axis_nic_tx_tdest,
    output wire [AXIS_IF_TX_USER_WIDTH-1:0]                m_axis_nic_tx_tuser,

    // from PsPIN - NIC Command
    output wire                                            nic_cmd_req_ready,
    input  wire                                            nic_cmd_req_valid,
    input  wire [CMD_ID_WIDTH-1:0]                         nic_cmd_req_id,
    input  wire [31:0]                                     nic_cmd_req_nid,
    input  wire [31:0]                                     nic_cmd_req_fid,
    input  wire [AXI_HOST_ADDR_WIDTH-1:0]                  nic_cmd_req_src_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]                       nic_cmd_req_length,
    input  wire [63:0]                                     nic_cmd_req_user_ptr,
  
    // to PsPIN - NIC Command Response
    output wire                                            nic_cmd_resp_valid,
    output wire [CMD_ID_WIDTH-1:0]                         nic_cmd_resp_id,

    // to ctrl regs - last error
    output reg  [3:0]                                      egress_dma_last_error
);

wire [3:0] dma_desc_status_error;

assign m_axi_pspin_no_awid = {AXI_ID_WIDTH{1'b0}};
assign m_axi_pspin_no_awaddr = {AXI_ADDR_WIDTH{1'b0}};
assign m_axi_pspin_no_awlen = 8'b0;
assign m_axi_pspin_no_awsize = 3'b0;
assign m_axi_pspin_no_awburst = 2'b0;
assign m_axi_pspin_no_awlock = 1'b0;
assign m_axi_pspin_no_awcache = 4'b0;
assign m_axi_pspin_no_awprot = 3'b0;
assign m_axi_pspin_no_awvalid = 1'b0;
assign m_axi_pspin_no_wdata = {AXI_DATA_WIDTH{1'b0}};
assign m_axi_pspin_no_wstrb = {AXI_STRB_WIDTH{1'b0}};
assign m_axi_pspin_no_wlast = 1'b0;
assign m_axi_pspin_no_wvalid = 1'b0;
assign m_axi_pspin_no_bready = 1'b0;

always @(posedge clk) begin
    if (nic_cmd_resp_valid)
        egress_dma_last_error <= dma_desc_status_error;
    if (!rstn)
        egress_dma_last_error <= 4'b0;
end

axi_dma_rd #(
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXIS_DATA_WIDTH(AXIS_IF_DATA_WIDTH),
    .AXIS_KEEP_WIDTH(AXIS_IF_KEEP_WIDTH),
    .AXIS_ID_ENABLE(1),
    .AXIS_ID_WIDTH(AXIS_IF_TX_ID_WIDTH),
    .AXIS_DEST_ENABLE(1),
    .AXIS_DEST_WIDTH(AXIS_IF_TX_DEST_WIDTH),
    .AXIS_USER_ENABLE(1),
    .AXIS_USER_WIDTH(AXIS_IF_TX_USER_WIDTH),
    .LEN_WIDTH(LEN_WIDTH),
    .TAG_WIDTH(TAG_WIDTH)
) i_egress_dma (
    .clk                                (clk),
    .rst                                (!rstn),

    .s_axis_read_desc_addr              (nic_cmd_req_src_addr[31:0]),
    .s_axis_read_desc_len               (nic_cmd_req_length),
    .s_axis_read_desc_tag               (nic_cmd_req_id),
    // TODO: determine appropriate tdest,user,id
    .s_axis_read_desc_id                ({{AXIS_IF_TX_ID_WIDTH-CMD_ID_WIDTH{1'b0}}, nic_cmd_req_id}),
    .s_axis_read_desc_dest              ({AXIS_IF_TX_DEST_WIDTH{1'b0}}),
    .s_axis_read_desc_user              ({AXIS_IF_TX_USER_WIDTH{1'b0}}),
    .s_axis_read_desc_valid             (nic_cmd_req_valid),
    .s_axis_read_desc_ready             (nic_cmd_req_ready),

    .m_axis_read_desc_status_tag        (nic_cmd_resp_id),
    .m_axis_read_desc_status_error      (dma_desc_status_error),
    .m_axis_read_desc_status_valid      (nic_cmd_resp_valid),

    .m_axis_read_data_tdata             (m_axis_nic_tx_tdata  ),
    .m_axis_read_data_tkeep             (m_axis_nic_tx_tkeep  ),
    .m_axis_read_data_tvalid            (m_axis_nic_tx_tvalid ),
    .m_axis_read_data_tready            (m_axis_nic_tx_tready ),
    .m_axis_read_data_tlast             (m_axis_nic_tx_tlast  ),
    .m_axis_read_data_tid               (m_axis_nic_tx_tid    ),
    .m_axis_read_data_tdest             (m_axis_nic_tx_tdest  ),
    .m_axis_read_data_tuser             (m_axis_nic_tx_tuser  ),

    .m_axi_arid                         (m_axi_pspin_no_arid   ),
    .m_axi_araddr                       (m_axi_pspin_no_araddr ),
    .m_axi_arlen                        (m_axi_pspin_no_arlen  ),
    .m_axi_arsize                       (m_axi_pspin_no_arsize ),
    .m_axi_arburst                      (m_axi_pspin_no_arburst),
    .m_axi_arlock                       (m_axi_pspin_no_arlock ),
    .m_axi_arcache                      (m_axi_pspin_no_arcache),
    .m_axi_arprot                       (m_axi_pspin_no_arprot ),
    .m_axi_arvalid                      (m_axi_pspin_no_arvalid),
    .m_axi_arready                      (m_axi_pspin_no_arready),
    .m_axi_rid                          (m_axi_pspin_no_rid    ),
    .m_axi_rdata                        (m_axi_pspin_no_rdata  ),
    .m_axi_rresp                        (m_axi_pspin_no_rresp  ),
    .m_axi_rlast                        (m_axi_pspin_no_rlast  ),
    .m_axi_rvalid                       (m_axi_pspin_no_rvalid ),
    .m_axi_rready                       (m_axi_pspin_no_rready ),

    .enable                             (1'b1)
);

endmodule