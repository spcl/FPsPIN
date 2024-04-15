/**
 * PsPIN host memory DMA write datapath
 *
 * Write datapath of the host memory DMA adapter.  Utilises the verilog-pcie
 * DMA client to AXIS, driving the R channel of full AXI.
 *
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






module pspin_hostmem_dma_wr #(
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
    input  wire                                           clk,
    input  wire                                           rstn,

    /*
     * DMA write descriptor output (data)
     */
    output reg  [ADDR_WIDTH-1:0]                          m_axis_write_desc_dma_addr,
    output wire [RAM_SEL_WIDTH-1:0]                       m_axis_write_desc_ram_sel,
    output reg  [RAM_ADDR_WIDTH-1:0]                      m_axis_write_desc_ram_addr,
    output reg  [DMA_IMM_WIDTH-1:0]                       m_axis_write_desc_imm,
    output reg                                            m_axis_write_desc_imm_en,
    output reg  [DMA_LEN_WIDTH-1:0]                       m_axis_write_desc_len,
    output reg  [DMA_TAG_WIDTH-1:0]                       m_axis_write_desc_tag,
    output reg                                            m_axis_write_desc_valid,
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


    /* AXI AW, W & B channels */
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
    output reg                                            s_axi_awready,
    input  wire [DATA_WIDTH-1:0]                          s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]                          s_axi_wstrb,
    input  wire                                           s_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]                         s_axi_wuser,
    input  wire                                           s_axi_wvalid,
    output wire                                           s_axi_wready,
    output reg  [ID_WIDTH-1:0]                            s_axi_bid,
    output reg  [1:0]                                     s_axi_bresp,
    output reg  [BUSER_WIDTH-1:0]                         s_axi_buser,
    output reg                                            s_axi_bvalid,
    input  wire                                           s_axi_bready
);

localparam STATE_WIDTH = 4;
localparam
    IDLE = 'h0,
    ISSUE_TO_CLIENT = 'h1,
    WAIT_CLIENT = 'h2,
    WAIT_CLIENT_FIN = 'h3,
    ISSUE_TO_DMA = 'h4,
    WAIT_DMA = 'h5,
    WAIT_DMA_FIN = 'h6,
    FINISH_AXI = 'h7; // issue write response
localparam DMA_ERROR_NONE = 4'b0;
localparam AXI_OKAY = 2'b00;
localparam AXI_SLVERR = 2'b10;
localparam BURST_INCR = 2'b01;

reg [STATE_WIDTH-1:0] state_q, state_d;

reg [RAM_ADDR_WIDTH-1:0] dma_write_desc_ram_addr;
reg [DMA_LEN_WIDTH-1:0] dma_write_desc_len;
reg [ID_WIDTH-1:0] dma_write_desc_tag;
reg dma_write_desc_valid;
wire dma_write_desc_ready;
wire dma_write_desc_status_valid;
wire [ID_WIDTH-1:0] dma_write_desc_status_tag;

reg [ADDR_WIDTH-1:0] saved_dma_addr;
reg [DMA_LEN_WIDTH-1:0] saved_dma_len;

initial begin
    
    if (!(DMA_TAG_WIDTH >= ID_WIDTH)) begin
        $display({"ASSERTION FAILED in %m: DMA_TAG_WIDTH >= ID_WIDTH: ", "DMA interface tag too narrow"});
        $finish;
    end;
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
    num_beats_d = s_axi_awlen + 1;
    // we assume no narrow transfers => full beats
    dma_len_d = NUM_BYTES_BUS * num_beats_d;
end

// state transition
always @* begin
    state_d = state_q;
    case (state_q)
        IDLE: begin
            if (s_axi_awready && s_axi_awvalid)
                state_d = ISSUE_TO_CLIENT;
            dma_error_d = 1'b0;
        end
        ISSUE_TO_CLIENT, WAIT_CLIENT: if (dma_write_desc_valid && dma_write_desc_ready)
            state_d = WAIT_CLIENT_FIN;
        else
            state_d = WAIT_CLIENT;
        WAIT_CLIENT_FIN: if (dma_write_desc_status_valid)
            state_d = ISSUE_TO_DMA;
        ISSUE_TO_DMA, WAIT_DMA: if (m_axis_write_desc_valid && m_axis_write_desc_ready)
            state_d = WAIT_DMA_FIN;
        else
            state_d = WAIT_DMA;
        WAIT_DMA_FIN: if (s_axis_read_desc_status_valid)
            state_d = FINISH_AXI;
        FINISH_AXI: if (s_axi_bready && s_axi_bvalid)
            state_d = IDLE;
    endcase
end

// state-machine output
always @(posedge clk) begin
    case (state_d)
        IDLE: begin
            s_axi_awready <= 1'b1;
            s_axi_bid <= {ID_WIDTH{1'b0}};
            s_axi_bresp <= AXI_OKAY;
            s_axi_buser <= {BUSER_WIDTH{1'b0}};
            s_axi_bvalid <= 1'b0;
            dma_write_desc_ram_addr <= {RAM_ADDR_WIDTH{1'b0}};
            dma_write_desc_len <= {DMA_LEN_WIDTH{1'b0}};
            dma_write_desc_tag <= {ID_WIDTH{1'b0}};
            dma_write_desc_valid <= 1'b0;
            m_axis_write_desc_dma_addr <= {ADDR_WIDTH{1'b0}};
            m_axis_write_desc_ram_addr <= {RAM_ADDR_WIDTH{1'b0}};
            m_axis_write_desc_len <= {DMA_LEN_WIDTH{1'b0}};
            m_axis_write_desc_tag <= {DMA_TAG_WIDTH{1'b0}};
            // disable IMM support until PsPIN is ready
            m_axis_write_desc_imm <= {DMA_IMM_WIDTH{1'b0}};
            m_axis_write_desc_imm_en <= 1'b0;
            m_axis_write_desc_valid <= 1'b0;
        end
        ISSUE_TO_CLIENT: begin
            // always zero RAM address
            dma_write_desc_len <= dma_len_d;
            dma_write_desc_tag <= s_axi_awid;
            dma_write_desc_valid <= 1'b1;
            saved_dma_addr <= s_axi_awaddr;
            saved_dma_len <= dma_len_d;

            // checks for simulation
            
    if (!('h1 << s_axi_awsize == NUM_BYTES_BUS)) begin
        $display({"ASSERTION FAILED in %m: 'h1 << s_axi_awsize == NUM_BYTES_BUS: ", "narrow burst not supported"});
        $finish;
    end;
            
    if (!(s_axi_awburst == BURST_INCR)) begin
        $display({"ASSERTION FAILED in %m: s_axi_awburst == BURST_INCR: ", "burst other than INCR not supported"});
        $finish;
    end;
            
    if (!(s_axi_awaddr % NUM_BYTES_BUS == 'h0)) begin
        $display({"ASSERTION FAILED in %m: s_axi_awaddr % NUM_BYTES_BUS == 'h0: ", "unaligned transfer not supported"});
        $finish;
    end;
        end
        WAIT_CLIENT: if (dma_write_desc_ready)
            dma_write_desc_valid <= 1'b0;
        // WAIT_CLIENT_FIN: nothing
        ISSUE_TO_DMA: begin
            m_axis_write_desc_dma_addr <= saved_dma_addr;
            m_axis_write_desc_dma_len <= saved_dma_len;
            m_axis_write_desc_tag <= dma_write_desc_status_tag;
            // always zero RAM address
            m_axis_write_desc_valid <= 1'b1;
        end
        WAIT_DMA: if (m_axis_write_desc_ready)
            m_axis_write_desc_valid <= 1'b0;
        // WAIT_DMA_FIN: nothing
        FINISH_AXI: begin
            s_axi_bid <= s_axis_write_desc_status_tag;
            s_axi_bresp <= s_axis_write_desc_status_error == 4'b0 ? AXI_OKAY : AXI_SLVERR;
            s_axi_bvalid <= 1'b1;
        end
        default: begin /* nothing */ end
    endcase
end

assign m_axis_write_desc_ram_sel = {RAM_SEL_WIDTH{1'b0}};

dma_client_axis_sink #(
    .SEG_COUNT(RAM_SEG_COUNT),
    .SEG_DATA_WIDTH(RAM_SEG_DATA_WIDTH),
    .SEG_ADDR_WIDTH(RAM_SEG_ADDR_WIDTH),
    .SEG_BE_WIDTH(RAM_SEG_BE_WIDTH),
    .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
    .AXIS_DATA_WIDTH(DATA_WIDTH),
    .AXIS_KEEP_ENABLE(1),
    .AXIS_KEEP_WIDTH(STRB_WIDTH),
    .AXIS_LAST_ENABLE(1),
    .AXIS_ID_ENABLE(0),
    .AXIS_ID_WIDTH(1),
    .AXIS_DEST_ENABLE(0),
    .AXIS_DEST_WIDTH(1),
    .AXIS_USER_ENABLE(0),
    .AXIS_USER_WIDTH(1),
    .LEN_WIDTH(DMA_LEN_WIDTH),
    .TAG_WIDTH(ID_WIDTH)
) i_dma_client_axis (
    .clk(clk),
    .rst(!rstn),

    .s_axis_write_desc_ram_addr(dma_write_desc_ram_addr),
    .s_axis_write_desc_len(dma_write_desc_len),
    .s_axis_write_desc_tag(dma_write_desc_tag),
    .s_axis_write_desc_id(1'b0),
    .s_axis_write_desc_dest(1'b0),
    .s_axis_write_desc_user(1'b0),
    .s_axis_write_desc_valid(dma_write_desc_valid),
    .s_axis_write_desc_ready(dma_write_desc_ready),

    .m_axis_write_desc_status_tag(dma_write_desc_status_tag),
    .m_axis_write_desc_status_error(),
    .m_axis_write_desc_status_valid(dma_write_desc_status_valid),

    .s_axis_write_data_tdata(s_axi_wdata),
    .s_axis_write_data_tkeep(s_axi_wstrb),
    .s_axis_write_data_tvalid(s_axi_wvalid),
    .s_axis_write_data_tready(s_axi_wready),
    .s_axis_write_data_tlast(s_axi_wlast),
    .s_axis_write_data_tid(1'b0),
    .s_axis_write_data_tdest(1'b0),
    .s_axis_write_data_tuser(1'b0),

    .ram_wr_cmd_be,
    .ram_wr_cmd_addr,
    .ram_wr_cmd_data,
    .ram_wr_cmd_valid,
    .ram_wr_cmd_ready,
    .ram_wr_done,

    .enable(1'b1),
    .abort(1'b0)
);
endmodule