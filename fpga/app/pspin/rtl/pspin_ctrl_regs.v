/* Generated on 2023-08-27 16:16:25.262246 with: ./regs-compiler.py --all v ../rtl */

`timescale 1ns / 1ps
`define SLICE(arr, idx, width) arr[(idx)*(width) +: width]

// XXX: We are latching most of the configuration again at the consumer side.
//      Should we only latch it once here / at the consumer (timing
//      considerations)?
module pspin_ctrl_regs #
(
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH/8,
    parameter NUM_CLUSTERS = 2,
    parameter NUM_MPQ = 16
) (
    input  wire                   clk,
    input  wire                   rst,

    /*
     * AXI-Lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,

    // register data
    output reg  [NUM_CLUSTERS-1:0] cl_fetch_en_o,
    output reg                     aux_rst_o,
    input  wire [NUM_CLUSTERS-1:0] cl_eoc_i,
    input  wire [NUM_CLUSTERS-1:0] cl_busy_i,
    input  wire [NUM_MPQ-1:0]      mpq_full_i,
    
    // stdout FIFO
    output reg                    stdout_rd_en,
    input  wire [31:0]            stdout_dout,
    input  wire                   stdout_data_valid,

    // packet allocator dropped packets
    input  wire [31:0]                                      alloc_dropped_pkts,

    // matching engine configuration
    output reg  [0:0] match_valid,
    output reg  [3:0] match_mode,
    output reg  [511:0] match_idx,
    output reg  [511:0] match_mask,
    output reg  [511:0] match_start,
    output reg  [511:0] match_end,

    // HER generator execution context
    output reg  [0:0] her_gen_valid,
    output reg  [3:0] her_gen_ctx_enabled,
    output reg  [127:0] her_gen_handler_mem_addr,
    output reg  [127:0] her_gen_handler_mem_size,
    output reg  [255:0] her_gen_host_mem_addr,
    output reg  [127:0] her_gen_host_mem_size,
    output reg  [127:0] her_gen_hh_addr,
    output reg  [127:0] her_gen_hh_size,
    output reg  [127:0] her_gen_ph_addr,
    output reg  [127:0] her_gen_ph_size,
    output reg  [127:0] her_gen_th_addr,
    output reg  [127:0] her_gen_th_size,
    output reg  [127:0] her_gen_scratchpad_0_addr,
    output reg  [127:0] her_gen_scratchpad_0_size,
    output reg  [127:0] her_gen_scratchpad_1_addr,
    output reg  [127:0] her_gen_scratchpad_1_size,
    output reg  [127:0] her_gen_scratchpad_2_addr,
    output reg  [127:0] her_gen_scratchpad_2_size,
    output reg  [127:0] her_gen_scratchpad_3_addr,
    output reg  [127:0] her_gen_scratchpad_3_size,

    // egress datapath
    input  wire [3:0]                                       egress_dma_last_error
);


localparam UMATCH_WIDTH = 32;
localparam UMATCH_ENTRIES = 4;
localparam UMATCH_RULESETS = 4;
localparam UMATCH_MODES = 2;
localparam HER_NUM_HANDLER_CTX = 4;

localparam VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
localparam WORD_WIDTH = STRB_WIDTH;
localparam WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

localparam NUM_REGS = 158;

reg [DATA_WIDTH-1:0] ctrl_regs [NUM_REGS-1:0];

`define REGFILE_IDX_INVALID {VALID_ADDR_WIDTH{1'b1}}
wire [NUM_REGS-1:0] REGFILE_IDX_READONLY;
localparam [ADDR_WIDTH-1:0] CL_CTRL_BASE = {{ADDR_WIDTH{1'b0}}, 32'h0};
localparam CL_CTRL_REG_COUNT = 2;
localparam CL_CTRL_REG_OFF = 0;
assign REGFILE_IDX_READONLY[1:0] = 2'b00;

localparam [ADDR_WIDTH-1:0] CL_FIFO_BASE = {{ADDR_WIDTH{1'b0}}, 32'h8};
localparam CL_FIFO_REG_COUNT = 1;
localparam CL_FIFO_REG_OFF = 2;
assign REGFILE_IDX_READONLY[2:2] = 1'b1;


localparam [ADDR_WIDTH-1:0] STATS_CLUSTER_BASE = {{ADDR_WIDTH{1'b0}}, 32'h1000};
localparam STATS_CLUSTER_REG_COUNT = 2;
localparam STATS_CLUSTER_REG_OFF = 3;
assign REGFILE_IDX_READONLY[4:3] = 2'b11;

localparam [ADDR_WIDTH-1:0] STATS_MPQ_BASE = {{ADDR_WIDTH{1'b0}}, 32'h1008};
localparam STATS_MPQ_REG_COUNT = 1;
localparam STATS_MPQ_REG_OFF = 5;
assign REGFILE_IDX_READONLY[5:5] = 1'b1;

localparam [ADDR_WIDTH-1:0] STATS_DATAPATH_BASE = {{ADDR_WIDTH{1'b0}}, 32'h100c};
localparam STATS_DATAPATH_REG_COUNT = 2;
localparam STATS_DATAPATH_REG_OFF = 6;
assign REGFILE_IDX_READONLY[7:6] = 2'b11;


localparam [ADDR_WIDTH-1:0] ME_VALID_BASE = {{ADDR_WIDTH{1'b0}}, 32'h2000};
localparam ME_VALID_REG_COUNT = 1;
localparam ME_VALID_REG_OFF = 8;
assign REGFILE_IDX_READONLY[8:8] = 1'b0;

localparam [ADDR_WIDTH-1:0] ME_MODE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h2004};
localparam ME_MODE_REG_COUNT = 4;
localparam ME_MODE_REG_OFF = 9;
assign REGFILE_IDX_READONLY[12:9] = 4'b0000;

localparam [ADDR_WIDTH-1:0] ME_IDX_BASE = {{ADDR_WIDTH{1'b0}}, 32'h2014};
localparam ME_IDX_REG_COUNT = 16;
localparam ME_IDX_REG_OFF = 13;
assign REGFILE_IDX_READONLY[28:13] = 16'b0000000000000000;

localparam [ADDR_WIDTH-1:0] ME_MASK_BASE = {{ADDR_WIDTH{1'b0}}, 32'h2054};
localparam ME_MASK_REG_COUNT = 16;
localparam ME_MASK_REG_OFF = 29;
assign REGFILE_IDX_READONLY[44:29] = 16'b0000000000000000;

localparam [ADDR_WIDTH-1:0] ME_START_BASE = {{ADDR_WIDTH{1'b0}}, 32'h2094};
localparam ME_START_REG_COUNT = 16;
localparam ME_START_REG_OFF = 45;
assign REGFILE_IDX_READONLY[60:45] = 16'b0000000000000000;

localparam [ADDR_WIDTH-1:0] ME_END_BASE = {{ADDR_WIDTH{1'b0}}, 32'h20d4};
localparam ME_END_REG_COUNT = 16;
localparam ME_END_REG_OFF = 61;
assign REGFILE_IDX_READONLY[76:61] = 16'b0000000000000000;


localparam [ADDR_WIDTH-1:0] HER_VALID_BASE = {{ADDR_WIDTH{1'b0}}, 32'h3000};
localparam HER_VALID_REG_COUNT = 1;
localparam HER_VALID_REG_OFF = 77;
assign REGFILE_IDX_READONLY[77:77] = 1'b0;

localparam [ADDR_WIDTH-1:0] HER_CTX_ENABLED_BASE = {{ADDR_WIDTH{1'b0}}, 32'h3004};
localparam HER_CTX_ENABLED_REG_COUNT = 4;
localparam HER_CTX_ENABLED_REG_OFF = 78;
assign REGFILE_IDX_READONLY[81:78] = 4'b0000;


localparam [ADDR_WIDTH-1:0] HER_META_HANDLER_MEM_ADDR_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4000};
localparam HER_META_HANDLER_MEM_ADDR_REG_COUNT = 4;
localparam HER_META_HANDLER_MEM_ADDR_REG_OFF = 82;
assign REGFILE_IDX_READONLY[85:82] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_HANDLER_MEM_SIZE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4010};
localparam HER_META_HANDLER_MEM_SIZE_REG_COUNT = 4;
localparam HER_META_HANDLER_MEM_SIZE_REG_OFF = 86;
assign REGFILE_IDX_READONLY[89:86] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_HOST_MEM_ADDR_0_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4020};
localparam HER_META_HOST_MEM_ADDR_0_REG_COUNT = 4;
localparam HER_META_HOST_MEM_ADDR_0_REG_OFF = 90;
assign REGFILE_IDX_READONLY[93:90] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_HOST_MEM_ADDR_1_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4030};
localparam HER_META_HOST_MEM_ADDR_1_REG_COUNT = 4;
localparam HER_META_HOST_MEM_ADDR_1_REG_OFF = 94;
assign REGFILE_IDX_READONLY[97:94] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_HOST_MEM_SIZE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4040};
localparam HER_META_HOST_MEM_SIZE_REG_COUNT = 4;
localparam HER_META_HOST_MEM_SIZE_REG_OFF = 98;
assign REGFILE_IDX_READONLY[101:98] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_HH_ADDR_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4050};
localparam HER_META_HH_ADDR_REG_COUNT = 4;
localparam HER_META_HH_ADDR_REG_OFF = 102;
assign REGFILE_IDX_READONLY[105:102] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_HH_SIZE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4060};
localparam HER_META_HH_SIZE_REG_COUNT = 4;
localparam HER_META_HH_SIZE_REG_OFF = 106;
assign REGFILE_IDX_READONLY[109:106] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_PH_ADDR_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4070};
localparam HER_META_PH_ADDR_REG_COUNT = 4;
localparam HER_META_PH_ADDR_REG_OFF = 110;
assign REGFILE_IDX_READONLY[113:110] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_PH_SIZE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4080};
localparam HER_META_PH_SIZE_REG_COUNT = 4;
localparam HER_META_PH_SIZE_REG_OFF = 114;
assign REGFILE_IDX_READONLY[117:114] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_TH_ADDR_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4090};
localparam HER_META_TH_ADDR_REG_COUNT = 4;
localparam HER_META_TH_ADDR_REG_OFF = 118;
assign REGFILE_IDX_READONLY[121:118] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_TH_SIZE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h40a0};
localparam HER_META_TH_SIZE_REG_COUNT = 4;
localparam HER_META_TH_SIZE_REG_OFF = 122;
assign REGFILE_IDX_READONLY[125:122] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_SCRATCHPAD_0_ADDR_BASE = {{ADDR_WIDTH{1'b0}}, 32'h40b0};
localparam HER_META_SCRATCHPAD_0_ADDR_REG_COUNT = 4;
localparam HER_META_SCRATCHPAD_0_ADDR_REG_OFF = 126;
assign REGFILE_IDX_READONLY[129:126] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_SCRATCHPAD_0_SIZE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h40c0};
localparam HER_META_SCRATCHPAD_0_SIZE_REG_COUNT = 4;
localparam HER_META_SCRATCHPAD_0_SIZE_REG_OFF = 130;
assign REGFILE_IDX_READONLY[133:130] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_SCRATCHPAD_1_ADDR_BASE = {{ADDR_WIDTH{1'b0}}, 32'h40d0};
localparam HER_META_SCRATCHPAD_1_ADDR_REG_COUNT = 4;
localparam HER_META_SCRATCHPAD_1_ADDR_REG_OFF = 134;
assign REGFILE_IDX_READONLY[137:134] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_SCRATCHPAD_1_SIZE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h40e0};
localparam HER_META_SCRATCHPAD_1_SIZE_REG_COUNT = 4;
localparam HER_META_SCRATCHPAD_1_SIZE_REG_OFF = 138;
assign REGFILE_IDX_READONLY[141:138] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_SCRATCHPAD_2_ADDR_BASE = {{ADDR_WIDTH{1'b0}}, 32'h40f0};
localparam HER_META_SCRATCHPAD_2_ADDR_REG_COUNT = 4;
localparam HER_META_SCRATCHPAD_2_ADDR_REG_OFF = 142;
assign REGFILE_IDX_READONLY[145:142] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_SCRATCHPAD_2_SIZE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4100};
localparam HER_META_SCRATCHPAD_2_SIZE_REG_COUNT = 4;
localparam HER_META_SCRATCHPAD_2_SIZE_REG_OFF = 146;
assign REGFILE_IDX_READONLY[149:146] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_SCRATCHPAD_3_ADDR_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4110};
localparam HER_META_SCRATCHPAD_3_ADDR_REG_COUNT = 4;
localparam HER_META_SCRATCHPAD_3_ADDR_REG_OFF = 150;
assign REGFILE_IDX_READONLY[153:150] = 4'b0000;

localparam [ADDR_WIDTH-1:0] HER_META_SCRATCHPAD_3_SIZE_BASE = {{ADDR_WIDTH{1'b0}}, 32'h4120};
localparam HER_META_SCRATCHPAD_3_SIZE_REG_COUNT = 4;
localparam HER_META_SCRATCHPAD_3_SIZE_REG_OFF = 154;
assign REGFILE_IDX_READONLY[157:154] = 4'b0000;



initial begin
    if (DATA_WIDTH != 32) begin
        $error("Word width mismatch, please re-generate");
        $finish;
    end
end

// register interface
wire [ADDR_WIDTH-1:0] reg_intf_rd_addr;
reg [DATA_WIDTH-1:0] reg_intf_rd_data;
wire reg_intf_rd_en;
reg reg_intf_rd_ack;
wire [ADDR_WIDTH-1:0] reg_intf_wr_addr;
wire [DATA_WIDTH-1:0] reg_intf_wr_data;
wire [STRB_WIDTH-1:0] reg_intf_wr_strb;
wire reg_intf_wr_en;
reg reg_intf_wr_ack;

// address decode
reg [VALID_ADDR_WIDTH-1:0] regfile_idx_wr;
reg [15:0] block_id_wr, block_offset_wr;
always @* begin
    block_id_wr     = reg_intf_wr_addr & 32'hf000;
    block_offset_wr = reg_intf_wr_addr & 32'h0fff;
    case (block_id_wr)
        CL_CTRL_BASE: regfile_idx_wr = CL_CTRL_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        CL_FIFO_BASE: regfile_idx_wr = CL_FIFO_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        STATS_CLUSTER_BASE: regfile_idx_wr = STATS_CLUSTER_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        STATS_MPQ_BASE: regfile_idx_wr = STATS_MPQ_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        STATS_DATAPATH_BASE: regfile_idx_wr = STATS_DATAPATH_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        ME_VALID_BASE: regfile_idx_wr = ME_VALID_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_MODE_BASE: regfile_idx_wr = ME_MODE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_IDX_BASE: regfile_idx_wr = ME_IDX_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_MASK_BASE: regfile_idx_wr = ME_MASK_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_START_BASE: regfile_idx_wr = ME_START_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_END_BASE: regfile_idx_wr = ME_END_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        HER_VALID_BASE: regfile_idx_wr = HER_VALID_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_CTX_ENABLED_BASE: regfile_idx_wr = HER_CTX_ENABLED_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        HER_META_HANDLER_MEM_ADDR_BASE: regfile_idx_wr = HER_META_HANDLER_MEM_ADDR_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HANDLER_MEM_SIZE_BASE: regfile_idx_wr = HER_META_HANDLER_MEM_SIZE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HOST_MEM_ADDR_0_BASE: regfile_idx_wr = HER_META_HOST_MEM_ADDR_0_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HOST_MEM_ADDR_1_BASE: regfile_idx_wr = HER_META_HOST_MEM_ADDR_1_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HOST_MEM_SIZE_BASE: regfile_idx_wr = HER_META_HOST_MEM_SIZE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HH_ADDR_BASE: regfile_idx_wr = HER_META_HH_ADDR_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HH_SIZE_BASE: regfile_idx_wr = HER_META_HH_SIZE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_PH_ADDR_BASE: regfile_idx_wr = HER_META_PH_ADDR_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_PH_SIZE_BASE: regfile_idx_wr = HER_META_PH_SIZE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_TH_ADDR_BASE: regfile_idx_wr = HER_META_TH_ADDR_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_TH_SIZE_BASE: regfile_idx_wr = HER_META_TH_SIZE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_0_ADDR_BASE: regfile_idx_wr = HER_META_SCRATCHPAD_0_ADDR_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_0_SIZE_BASE: regfile_idx_wr = HER_META_SCRATCHPAD_0_SIZE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_1_ADDR_BASE: regfile_idx_wr = HER_META_SCRATCHPAD_1_ADDR_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_1_SIZE_BASE: regfile_idx_wr = HER_META_SCRATCHPAD_1_SIZE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_2_ADDR_BASE: regfile_idx_wr = HER_META_SCRATCHPAD_2_ADDR_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_2_SIZE_BASE: regfile_idx_wr = HER_META_SCRATCHPAD_2_SIZE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_3_ADDR_BASE: regfile_idx_wr = HER_META_SCRATCHPAD_3_ADDR_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_3_SIZE_BASE: regfile_idx_wr = HER_META_SCRATCHPAD_3_SIZE_REG_OFF + (block_offset_wr >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        default:  regfile_idx_wr = `REGFILE_IDX_INVALID;
    endcase
end
reg [VALID_ADDR_WIDTH-1:0] regfile_idx_rd;
reg [15:0] block_id_rd, block_offset_rd;
always @* begin
    block_id_rd     = reg_intf_rd_addr & 32'hf000;
    block_offset_rd = reg_intf_rd_addr & 32'h0fff;
    case (block_id_rd)
        CL_CTRL_BASE: regfile_idx_rd = CL_CTRL_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        CL_FIFO_BASE: regfile_idx_rd = CL_FIFO_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        STATS_CLUSTER_BASE: regfile_idx_rd = STATS_CLUSTER_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        STATS_MPQ_BASE: regfile_idx_rd = STATS_MPQ_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        STATS_DATAPATH_BASE: regfile_idx_rd = STATS_DATAPATH_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        ME_VALID_BASE: regfile_idx_rd = ME_VALID_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_MODE_BASE: regfile_idx_rd = ME_MODE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_IDX_BASE: regfile_idx_rd = ME_IDX_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_MASK_BASE: regfile_idx_rd = ME_MASK_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_START_BASE: regfile_idx_rd = ME_START_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        ME_END_BASE: regfile_idx_rd = ME_END_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        HER_VALID_BASE: regfile_idx_rd = HER_VALID_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_CTX_ENABLED_BASE: regfile_idx_rd = HER_CTX_ENABLED_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        HER_META_HANDLER_MEM_ADDR_BASE: regfile_idx_rd = HER_META_HANDLER_MEM_ADDR_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HANDLER_MEM_SIZE_BASE: regfile_idx_rd = HER_META_HANDLER_MEM_SIZE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HOST_MEM_ADDR_0_BASE: regfile_idx_rd = HER_META_HOST_MEM_ADDR_0_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HOST_MEM_ADDR_1_BASE: regfile_idx_rd = HER_META_HOST_MEM_ADDR_1_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HOST_MEM_SIZE_BASE: regfile_idx_rd = HER_META_HOST_MEM_SIZE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HH_ADDR_BASE: regfile_idx_rd = HER_META_HH_ADDR_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_HH_SIZE_BASE: regfile_idx_rd = HER_META_HH_SIZE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_PH_ADDR_BASE: regfile_idx_rd = HER_META_PH_ADDR_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_PH_SIZE_BASE: regfile_idx_rd = HER_META_PH_SIZE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_TH_ADDR_BASE: regfile_idx_rd = HER_META_TH_ADDR_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_TH_SIZE_BASE: regfile_idx_rd = HER_META_TH_SIZE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_0_ADDR_BASE: regfile_idx_rd = HER_META_SCRATCHPAD_0_ADDR_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_0_SIZE_BASE: regfile_idx_rd = HER_META_SCRATCHPAD_0_SIZE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_1_ADDR_BASE: regfile_idx_rd = HER_META_SCRATCHPAD_1_ADDR_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_1_SIZE_BASE: regfile_idx_rd = HER_META_SCRATCHPAD_1_SIZE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_2_ADDR_BASE: regfile_idx_rd = HER_META_SCRATCHPAD_2_ADDR_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_2_SIZE_BASE: regfile_idx_rd = HER_META_SCRATCHPAD_2_SIZE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_3_ADDR_BASE: regfile_idx_rd = HER_META_SCRATCHPAD_3_ADDR_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        HER_META_SCRATCHPAD_3_SIZE_BASE: regfile_idx_rd = HER_META_SCRATCHPAD_3_SIZE_REG_OFF + (block_offset_rd >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
    
        default:  regfile_idx_rd = `REGFILE_IDX_INVALID;
    endcase
end

integer i;
// register output
always @* begin
    cl_fetch_en_o = ctrl_regs[CL_CTRL_REG_OFF];
    aux_rst_o = ctrl_regs[CL_CTRL_REG_OFF + 1][0];

    // Matching engine
    for (i = 0; i < 1; i = i + 1)
        `SLICE(match_valid, i, 1) = ctrl_regs[ME_VALID_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(match_mode, i, 1) = ctrl_regs[ME_MODE_REG_OFF + i];
    for (i = 0; i < 16; i = i + 1)
        `SLICE(match_idx, i, 32) = ctrl_regs[ME_IDX_REG_OFF + i];
    for (i = 0; i < 16; i = i + 1)
        `SLICE(match_mask, i, 32) = ctrl_regs[ME_MASK_REG_OFF + i];
    for (i = 0; i < 16; i = i + 1)
        `SLICE(match_start, i, 32) = ctrl_regs[ME_START_REG_OFF + i];
    for (i = 0; i < 16; i = i + 1)
        `SLICE(match_end, i, 32) = ctrl_regs[ME_END_REG_OFF + i];

    // HER generator execution context
    for (i = 0; i < 1; i = i + 1)
        `SLICE(her_gen_valid, i, 1) = ctrl_regs[HER_VALID_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_ctx_enabled, i, 1) = ctrl_regs[HER_CTX_ENABLED_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_handler_mem_addr, i, 32) = ctrl_regs[HER_META_HANDLER_MEM_ADDR_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_handler_mem_size, i, 32) = ctrl_regs[HER_META_HANDLER_MEM_SIZE_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_host_mem_addr, i, 64) = {
            ctrl_regs[HER_META_HOST_MEM_ADDR_1_REG_OFF + i],
            ctrl_regs[HER_META_HOST_MEM_ADDR_0_REG_OFF + i]
        };
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_host_mem_size, i, 32) = ctrl_regs[HER_META_HOST_MEM_SIZE_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_hh_addr, i, 32) = ctrl_regs[HER_META_HH_ADDR_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_hh_size, i, 32) = ctrl_regs[HER_META_HH_SIZE_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_ph_addr, i, 32) = ctrl_regs[HER_META_PH_ADDR_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_ph_size, i, 32) = ctrl_regs[HER_META_PH_SIZE_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_th_addr, i, 32) = ctrl_regs[HER_META_TH_ADDR_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_th_size, i, 32) = ctrl_regs[HER_META_TH_SIZE_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_scratchpad_0_addr, i, 32) = ctrl_regs[HER_META_SCRATCHPAD_0_ADDR_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_scratchpad_0_size, i, 32) = ctrl_regs[HER_META_SCRATCHPAD_0_SIZE_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_scratchpad_1_addr, i, 32) = ctrl_regs[HER_META_SCRATCHPAD_1_ADDR_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_scratchpad_1_size, i, 32) = ctrl_regs[HER_META_SCRATCHPAD_1_SIZE_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_scratchpad_2_addr, i, 32) = ctrl_regs[HER_META_SCRATCHPAD_2_ADDR_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_scratchpad_2_size, i, 32) = ctrl_regs[HER_META_SCRATCHPAD_2_SIZE_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_scratchpad_3_addr, i, 32) = ctrl_regs[HER_META_SCRATCHPAD_3_ADDR_REG_OFF + i];
    for (i = 0; i < 4; i = i + 1)
        `SLICE(her_gen_scratchpad_3_size, i, 32) = ctrl_regs[HER_META_SCRATCHPAD_3_SIZE_REG_OFF + i];
end

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < NUM_REGS; i = i + 1) begin
            if (i == CL_CTRL_REG_OFF + 1)
                ctrl_regs[i] = {DATA_WIDTH{1'b1}};
            else
                ctrl_regs[i] = {DATA_WIDTH{1'b0}};
        end
        reg_intf_rd_data <= {DATA_WIDTH{1'h0}};
        reg_intf_rd_ack <= 1'b0;
        reg_intf_wr_ack <= 1'b0;
    end else begin
        // read
        if (reg_intf_rd_en) begin
            if (reg_intf_rd_addr == CL_FIFO_BASE) begin
                if (!stdout_data_valid) begin
                    // FIFO data not valid, give garbage data
                    reg_intf_rd_data <= {DATA_WIDTH{1'b1}};
                end else begin
                    stdout_rd_en <= 'b1;
                    reg_intf_rd_data <= stdout_dout;
                end
            end else begin
                if (regfile_idx_rd != `REGFILE_IDX_INVALID)
                    reg_intf_rd_data <= ctrl_regs[regfile_idx_rd];
                else
                    reg_intf_rd_data <= {DATA_WIDTH{1'b1}};
            end
            reg_intf_rd_ack <= 'b1;
        end

        if (reg_intf_rd_ack) begin
            reg_intf_rd_ack <= 'b0;
            stdout_rd_en <= 'b0;
        end

        // write
        for (i = 0; i < STRB_WIDTH; i = i + 1) begin
            if (reg_intf_wr_en && reg_intf_wr_strb[i]) begin
                if (regfile_idx_wr != `REGFILE_IDX_INVALID && !REGFILE_IDX_READONLY[regfile_idx_wr]) begin
                    `SLICE(ctrl_regs[regfile_idx_wr], i, WORD_SIZE) <= `SLICE(reg_intf_wr_data, i, WORD_SIZE);
                end
                reg_intf_wr_ack <= 'b1;
            end

            if (reg_intf_wr_ack) begin
                reg_intf_wr_ack <= 'b0;
            end
        end

        // register input
        ctrl_regs[STATS_CLUSTER_REG_OFF]     <= cl_eoc_i;   // eoc
        ctrl_regs[STATS_CLUSTER_REG_OFF + 1] <= cl_busy_i;  // busy

        // we only have 16 MPQs
        ctrl_regs[STATS_MPQ_REG_OFF] <= {{DATA_WIDTH - NUM_MPQ{1'b0}}, mpq_full_i};

        ctrl_regs[STATS_DATAPATH_REG_OFF] <= alloc_dropped_pkts;
        ctrl_regs[STATS_DATAPATH_REG_OFF + 1] <= {28'b0, egress_dma_last_error};
    end
end

axil_reg_if #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
) ctrl_reg_inst (
    .clk(clk),
    .rst(rst),

    .s_axil_awaddr          (s_axil_awaddr),
    .s_axil_awprot          (s_axil_awprot),
    .s_axil_awvalid         (s_axil_awvalid),
    .s_axil_awready         (s_axil_awready),
    .s_axil_wdata           (s_axil_wdata),
    .s_axil_wstrb           (s_axil_wstrb),
    .s_axil_wvalid          (s_axil_wvalid),
    .s_axil_wready          (s_axil_wready),
    .s_axil_bresp           (s_axil_bresp),
    .s_axil_bvalid          (s_axil_bvalid),
    .s_axil_bready          (s_axil_bready),
    .s_axil_araddr          (s_axil_araddr),
    .s_axil_arprot          (s_axil_arprot),
    .s_axil_arvalid         (s_axil_arvalid),
    .s_axil_arready         (s_axil_arready),
    .s_axil_rdata           (s_axil_rdata),
    .s_axil_rresp           (s_axil_rresp),
    .s_axil_rvalid          (s_axil_rvalid),
    .s_axil_rready          (s_axil_rready),

    .reg_rd_addr            (reg_intf_rd_addr),
    .reg_rd_en              (reg_intf_rd_en),
    .reg_rd_data            (reg_intf_rd_data),
    .reg_rd_ack             (reg_intf_rd_ack),
    .reg_rd_wait            (1'b0),

    .reg_wr_addr            (reg_intf_wr_addr),
    .reg_wr_strb            (reg_intf_wr_strb),
    .reg_wr_en              (reg_intf_wr_en),
    .reg_wr_data            (reg_intf_wr_data),
    .reg_wr_ack             (reg_intf_wr_ack),
    .reg_wr_wait            (1'b0)
);

endmodule