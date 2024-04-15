/**
 * PsPIN host memory DMA read datapath
 *
 * Read datapath of the host memory DMA adapter.  Utilises the verilog-pcie
 * DMA client to AXIS, driving the R channel of full AXI.
 *
 * This module does not handle possible AXI interleaving of the R channel.
 * This module does not support unaligned transfers or narrow bursts.  The beats
 * will be correctly received (such that the state machine does not get stuck),
 * but a SLVERR will be raised and the transaction will not take place.
 *
 * This module does not contain the DMA memory between the client and
 * interface, for the sake of ease of testing (verilog-pcie only provides
 * a model for the RAM and not a RAM master).  The RAM should be instantiated
 * in the parent module.
 */

`timescale 1ns / 1ps
`define assert(cond, msg) \
    if (!(cond)) begin \
        $display({"ASSERTION FAILED in %m: cond: ", msg}); \
        $finish; \
    end

module pspin_hostmem_dma_rd #(
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
    parameter RAM_PIPELINE = 2,

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
    input  wire                                         clk,
    input  wire                                         rstn,

    /*
     * DMA read descriptor output (data)
     */
    output reg  [ADDR_WIDTH-1:0]                        m_axis_read_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                     m_axis_read_desc_ram_sel,
    output reg  [RAM_ADDR_WIDTH-1:0]                    m_axis_read_desc_ram_addr,
    output reg  [DMA_LEN_WIDTH-1:0]                     m_axis_read_desc_len,
    output reg  [DMA_TAG_WIDTH-1:0]                     m_axis_read_desc_tag,
    output reg                                          m_axis_read_desc_valid,
    input  wire                                         m_axis_read_desc_ready,

    /*
     * DMA read descriptor status input (data)
     */
    input  wire [DMA_TAG_WIDTH-1:0]                     s_axis_read_desc_status_tag,
    input  wire [3:0]                                   s_axis_read_desc_status_error,
    input  wire                                         s_axis_read_desc_status_valid,
    
    /*
     * RAM interface
     */
    output wire [RAM_SEG_COUNT*RAM_SEG_ADDR_WIDTH-1:0]  ram_rd_cmd_addr,
    output wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_valid,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_rd_cmd_ready,
    input  wire [RAM_SEG_COUNT*RAM_SEG_DATA_WIDTH-1:0]  ram_rd_resp_data,
    input  wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_valid,
    output wire [RAM_SEG_COUNT-1:0]                     ram_rd_resp_ready,

    /* AXI AR & R channels */
    input  wire [ID_WIDTH-1:0]                          s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]                        s_axi_araddr,
    input  wire [7:0]                                   s_axi_arlen,
    input  wire [2:0]                                   s_axi_arsize,
    input  wire [1:0]                                   s_axi_arburst,
    input  wire                                         s_axi_arlock,
    input  wire [3:0]                                   s_axi_arcache,
    input  wire [2:0]                                   s_axi_arprot,
    input  wire [3:0]                                   s_axi_arqos,
    input  wire [3:0]                                   s_axi_arregion,
    input  wire [ARUSER_WIDTH-1:0]                      s_axi_aruser,
    input  wire                                         s_axi_arvalid,
    output reg                                          s_axi_arready,
    output wire [ID_WIDTH-1:0]                          s_axi_rid,
    output wire [DATA_WIDTH-1:0]                        s_axi_rdata,
    output wire [1:0]                                   s_axi_rresp,
    output wire                                         s_axi_rlast,
    output wire [RUSER_WIDTH-1:0]                       s_axi_ruser,
    output wire                                         s_axi_rvalid,
    input  wire                                         s_axi_rready
);

localparam STATE_WIDTH = 4;
localparam
    IDLE = 'h0,
    ISSUE_TO_DMA = 'h1,
    WAIT_DMA = 'h2,
    WAIT_DMA_FIN = 'h3,
    ISSUE_TO_CLIENT = 'h4,
    WAIT_CLIENT = 'h5,
    WAIT_CLIENT_FIN = 'h6,
    FINISH_AXI_ERROR = 'h7;
localparam DMA_ERROR_NONE = 4'b0;
localparam AXI_OKAY = 2'b00;
localparam AXI_SLVERR = 2'b10;
localparam BURST_INCR = 2'b01;

reg [STATE_WIDTH-1:0] state_q, state_d;

reg [RAM_ADDR_WIDTH-1:0] dma_read_desc_ram_addr;
reg [DMA_LEN_WIDTH-1:0] dma_read_desc_len;
reg [ID_WIDTH-1:0] dma_read_desc_id;
reg dma_read_desc_valid;
wire dma_read_desc_ready;
wire dma_read_desc_status_valid;

reg [DMA_LEN_WIDTH-1:0] saved_dma_len;

wire [ID_WIDTH-1:0]                          s_axi_data_rid;
wire [DATA_WIDTH-1:0]                        s_axi_data_rdata;
wire [1:0]                                   s_axi_data_rresp;
wire                                         s_axi_data_rlast;
wire [RUSER_WIDTH-1:0]                       s_axi_data_ruser;
wire                                         s_axi_data_rvalid;

reg  [ID_WIDTH-1:0]                          s_axi_error_rid;
reg  [DATA_WIDTH-1:0]                        s_axi_error_rdata;
reg  [1:0]                                   s_axi_error_rresp;
wire                                         s_axi_error_rlast;
reg  [RUSER_WIDTH-1:0]                       s_axi_error_ruser;
reg                                          s_axi_error_rvalid;

assign s_axi_rid = state_q == FINISH_AXI_ERROR ? s_axi_error_rid : s_axi_data_rid;
assign s_axi_rdata = state_q == FINISH_AXI_ERROR ? s_axi_error_rdata : s_axi_data_rdata;
assign s_axi_rresp = state_q == FINISH_AXI_ERROR ? s_axi_error_rresp : s_axi_data_rresp;
assign s_axi_rlast = state_q == FINISH_AXI_ERROR ? s_axi_error_rlast : s_axi_data_rlast;
assign s_axi_ruser = state_q == FINISH_AXI_ERROR ? s_axi_error_ruser : s_axi_data_ruser;
assign s_axi_rvalid = state_q == FINISH_AXI_ERROR ? s_axi_error_rvalid : s_axi_data_rvalid;

assign s_axi_data_rresp = AXI_OKAY;
assign s_axi_error_rlast = error_beats_left == 9'h1;

initial begin
    if (DMA_TAG_WIDTH < ID_WIDTH) begin
        $error("DMA interface tag too narrow: %d vs AXI ID_WIDTH %d\n", DMA_TAG_WIDTH, ID_WIDTH);
        $finish;
    end
end

always @(posedge clk) begin
    state_q <= state_d;
    if (!rstn) begin
        state_q <= IDLE;
    end
end

// length calculation
reg [DMA_LEN_WIDTH-1:0] dma_len_d;
localparam NUM_BYTES_BUS = DATA_WIDTH / 8;
reg [8:0] num_beats_d;
always @* begin
    num_beats_d = s_axi_arlen + 1;
    // we assume no narrow transfers => full beats
    dma_len_d = NUM_BYTES_BUS * num_beats_d;
end
reg [8:0] error_beats_left;

// state transition
always @* begin
    state_d = state_q;
    case (state_q)
        IDLE: begin
            if (s_axi_arready && s_axi_arvalid)
                state_d = ISSUE_TO_DMA;
        end
        ISSUE_TO_DMA, WAIT_DMA: if (m_axis_read_desc_valid && m_axis_read_desc_ready)
            state_d = WAIT_DMA_FIN;
        else
            state_d = WAIT_DMA;
        WAIT_DMA_FIN: if (s_axis_read_desc_status_valid) begin
            if (s_axis_read_desc_status_error != DMA_ERROR_NONE) begin
                state_d = FINISH_AXI_ERROR; // in case of slave error we still need the required number of beats
            end else
                state_d = ISSUE_TO_CLIENT;
        end
        ISSUE_TO_CLIENT, WAIT_CLIENT: if (dma_read_desc_valid && dma_read_desc_ready)
            state_d = WAIT_CLIENT_FIN;
        else
            state_d = WAIT_CLIENT;
        WAIT_CLIENT_FIN, FINISH_AXI_ERROR: if (s_axi_rvalid && s_axi_rready && s_axi_rlast)
            state_d = IDLE;
    endcase
end

// state-machine output
always @(posedge clk) begin
    case (state_d)
        IDLE: begin
            s_axi_arready <= 1'b1;
            s_axi_error_rid <= {ID_WIDTH{1'b0}};
            s_axi_error_rresp <= AXI_OKAY;
            s_axi_error_rdata <= {DATA_WIDTH{1'b0}};
            s_axi_error_ruser <= {RUSER_WIDTH{1'b0}};
            s_axi_error_rvalid <= 1'b0;
            dma_read_desc_ram_addr <= {RAM_ADDR_WIDTH{1'b0}};
            dma_read_desc_len <= {DMA_LEN_WIDTH{1'b0}};
            dma_read_desc_id <= {ID_WIDTH{1'b0}};
            dma_read_desc_valid <= 1'b0;
            m_axis_read_desc_dma_addr <= {ADDR_WIDTH{1'b0}};
            m_axis_read_desc_ram_addr <= {RAM_ADDR_WIDTH{1'b0}};
            m_axis_read_desc_len <= {DMA_LEN_WIDTH{1'b0}};
            m_axis_read_desc_tag <= {DMA_TAG_WIDTH{1'b0}};
            m_axis_read_desc_valid <= 1'b0;
            error_beats_left <= 9'h0;
        end
        ISSUE_TO_DMA: begin
            // always zero RAM address
            saved_dma_len <= dma_len_d;
            error_beats_left <= num_beats_d;
            m_axis_read_desc_dma_addr <= s_axi_araddr;
            m_axis_read_desc_len <= dma_len_d;
            m_axis_read_desc_tag <= s_axi_arid;
            m_axis_read_desc_valid <= 1'b1;
            // block AR
            s_axi_arready <= 1'b0;

            `assert('h1 << s_axi_arsize == NUM_BYTES_BUS, "narrow burst not supported");
            `assert(s_axi_arburst == BURST_INCR, "burst other than INCR not supported");
            `assert(s_axi_araddr % NUM_BYTES_BUS == 'h0, "unaligned transfer not supported");
        end
        WAIT_DMA: if (m_axis_read_desc_ready)
            m_axis_read_desc_valid <= 1'b0;
        WAIT_DMA_FIN:
            m_axis_read_desc_valid <= 1'b0;
        ISSUE_TO_CLIENT: begin
            dma_read_desc_len <= saved_dma_len;
            dma_read_desc_id <= s_axis_read_desc_status_tag;
            // always zero RAM address
            dma_read_desc_valid <= 1'b1;
        end
        WAIT_CLIENT: if (dma_read_desc_ready)
            dma_read_desc_valid <= 1'b0;
        WAIT_CLIENT_FIN:
            dma_read_desc_valid <= 1'b0;
        FINISH_AXI_ERROR: begin
            s_axi_error_rresp <= AXI_SLVERR;
            s_axi_error_rdata <= {DATA_WIDTH{1'b0}};
            s_axi_error_rid <= s_axis_read_desc_status_tag;
            s_axi_error_ruser <= 1'b0;
            s_axi_error_rvalid <= 1'b1;

            if (s_axi_error_rvalid && s_axi_rready)
                error_beats_left <= error_beats_left - 9'h1;
        end
        default: begin /* nothing */ end
    endcase
end

assign m_axis_read_desc_ram_sel = {RAM_SEL_WIDTH{1'b0}};

dma_client_axis_source #(
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(DATA_WIDTH),
    .AXIS_KEEP_ENABLE(1),
    .AXIS_KEEP_WIDTH(STRB_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(1),
    .AXIS_ID_WIDTH(ID_WIDTH),
    .AXIS_DEST_ENABLE(0),
    .AXIS_DEST_WIDTH(1),
    .AXIS_USER_ENABLE(0),
    .AXIS_USER_WIDTH(1),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .TAG_WIDTH(1)
) i_dma_client_axis (
    .clk(clk),
    .rst(!rstn),

    /*
     * DMA read descriptor input
     */
    .s_axis_read_desc_ram_addr(dma_read_desc_ram_addr),
    .s_axis_read_desc_len(dma_read_desc_len),
    .s_axis_read_desc_tag(1'b0),
    .s_axis_read_desc_id(dma_read_desc_id),
    .s_axis_read_desc_dest(1'b0),
    .s_axis_read_desc_user(1'b0),
    .s_axis_read_desc_valid(dma_read_desc_valid),
    .s_axis_read_desc_ready(dma_read_desc_ready),

    /*
     * DMA read descriptor status output
     */
    .m_axis_read_desc_status_tag(),
    .m_axis_read_desc_status_error(),
    .m_axis_read_desc_status_valid(dma_read_desc_status_valid),

    /*
     * AXI stream read data output
     */
    .m_axis_read_data_tdata(s_axi_data_rdata),
    .m_axis_read_data_tkeep(),
    .m_axis_read_data_tvalid(s_axi_data_rvalid),
    .m_axis_read_data_tready(s_axi_rready),
    .m_axis_read_data_tlast(s_axi_data_rlast),
    .m_axis_read_data_tid(s_axi_data_rid),
    .m_axis_read_data_tdest(),
    .m_axis_read_data_tuser(s_axi_data_ruser),

    /*
     * RAM interface
     */
    .ram_rd_cmd_addr,
    .ram_rd_cmd_valid,
    .ram_rd_cmd_ready,
    .ram_rd_resp_data,
    .ram_rd_resp_valid,
    .ram_rd_resp_ready,

    /*
     * Configuration
     */
    .enable(1'b1)
);


endmodule