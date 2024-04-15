/* Generated on 2023-08-27 16:16:25.269225 with: ./regs-compiler.py --all v ../rtl */

/**
 * PsPIN Handler Execution Request (HER) Generator
 *
 * The HER generator decodes metadata from the completion notification
 * from the ingress DMA to generate HERs for PsPIN.  The required metadata
 * is passed from the matching engine over the allocator, encoded in the tag
 * as an index for the execution contexts.
 *
 * The control registers interface programs the execution contexts enabled
 * for HER generation.  Packets that come with an invalid (disabled)
 * execution context will be dispatched to the default handler (id 0).  This
 * should always be set up before enabling the matching engine.
 */

`timescale 1ns / 1ps
`define SLICE(arr, idx, width) arr[(idx)*(width) +: width]

module pspin_her_gen #(
    parameter C_MSGID_WIDTH = 10,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_HOST_ADDR_WIDTH = 64,
    parameter LEN_WIDTH = 20,
    parameter TAG_WIDTH = 32
) (
    input                                   clk,
    input                                   rstn,

    // HER to PsPIN wrapper
    input  wire                             her_ready,
    output reg                              her_valid,
    output reg  [C_MSGID_WIDTH-1:0]         her_msgid,
    output reg                              her_is_eom,
    output reg  [AXI_ADDR_WIDTH-1:0]        her_addr,
    output reg  [AXI_ADDR_WIDTH-1:0]        her_size,
    output reg  [AXI_ADDR_WIDTH-1:0]        her_xfer_size,
    output reg  [31:0] her_meta_handler_mem_addr,
    output reg  [31:0] her_meta_handler_mem_size,
    output reg  [63:0] her_meta_host_mem_addr,
    output reg  [31:0] her_meta_host_mem_size,
    output reg  [31:0] her_meta_hh_addr,
    output reg  [31:0] her_meta_hh_size,
    output reg  [31:0] her_meta_ph_addr,
    output reg  [31:0] her_meta_ph_size,
    output reg  [31:0] her_meta_th_addr,
    output reg  [31:0] her_meta_th_size,
    output reg  [31:0] her_meta_scratchpad_0_addr,
    output reg  [31:0] her_meta_scratchpad_0_size,
    output reg  [31:0] her_meta_scratchpad_1_addr,
    output reg  [31:0] her_meta_scratchpad_1_size,
    output reg  [31:0] her_meta_scratchpad_2_addr,
    output reg  [31:0] her_meta_scratchpad_2_size,
    output reg  [31:0] her_meta_scratchpad_3_addr,
    output reg  [31:0] her_meta_scratchpad_3_size,

    // execution context from ctrl regs
    input wire [127:0] conf_handler_mem_addr,
    input wire [127:0] conf_handler_mem_size,
    input wire [255:0] conf_host_mem_addr,
    input wire [127:0] conf_host_mem_size,
    input wire [127:0] conf_hh_addr,
    input wire [127:0] conf_hh_size,
    input wire [127:0] conf_ph_addr,
    input wire [127:0] conf_ph_size,
    input wire [127:0] conf_th_addr,
    input wire [127:0] conf_th_size,
    input wire [127:0] conf_scratchpad_0_addr,
    input wire [127:0] conf_scratchpad_0_size,
    input wire [127:0] conf_scratchpad_1_addr,
    input wire [127:0] conf_scratchpad_1_size,
    input wire [127:0] conf_scratchpad_2_addr,
    input wire [127:0] conf_scratchpad_2_size,
    input wire [127:0] conf_scratchpad_3_addr,
    input wire [127:0] conf_scratchpad_3_size,
    input wire [0:0] conf_valid,
    input wire [3:0] conf_ctx_enabled,

    // completion from ingress DMA
    input  wire [AXI_ADDR_WIDTH-1:0]        gen_addr,
    input  wire [LEN_WIDTH-1:0]             gen_len,
    input  wire [TAG_WIDTH-1:0]             gen_tag,
    input  wire                             gen_valid,
    output reg                              gen_ready
);


localparam UMATCH_WIDTH = 32;
localparam UMATCH_ENTRIES = 4;
localparam UMATCH_RULESETS = 4;
localparam UMATCH_MODES = 2;
localparam HER_NUM_HANDLER_CTX = 4;

localparam CTX_ID_WIDTH = $clog2(HER_NUM_HANDLER_CTX);
`define DEFAULT_CTX_ID {CTX_ID_WIDTH{1'b0}}
reg [31:0] store_handler_mem_addr [3:0];
reg [31:0] store_handler_mem_size [3:0];
reg [63:0] store_host_mem_addr [3:0];
reg [31:0] store_host_mem_size [3:0];
reg [31:0] store_hh_addr [3:0];
reg [31:0] store_hh_size [3:0];
reg [31:0] store_ph_addr [3:0];
reg [31:0] store_ph_size [3:0];
reg [31:0] store_th_addr [3:0];
reg [31:0] store_th_size [3:0];
reg [31:0] store_scratchpad_0_addr [3:0];
reg [31:0] store_scratchpad_0_size [3:0];
reg [31:0] store_scratchpad_1_addr [3:0];
reg [31:0] store_scratchpad_1_size [3:0];
reg [31:0] store_scratchpad_2_addr [3:0];
reg [31:0] store_scratchpad_2_size [3:0];
reg [31:0] store_scratchpad_3_addr [3:0];
reg [31:0] store_scratchpad_3_size [3:0];
reg [0:0] store_ctx_enabled [3:0];

wire [C_MSGID_WIDTH-1:0] decode_msgid;
wire decode_is_eom;
wire [CTX_ID_WIDTH-1:0] decode_ctx_id;

integer idx;
initial begin
    if (C_MSGID_WIDTH + 1 + CTX_ID_WIDTH > TAG_WIDTH) begin
        $error("TAG_WIDTH = %d too small for C_MSGID_WIDTH = %d and CTX_ID_WIDTH = %d",
            TAG_WIDTH, C_MSGID_WIDTH, CTX_ID_WIDTH);
        $finish;
    end

    // dump for icarus verilog
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_handler_mem_addr[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_handler_mem_size[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_host_mem_addr[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_host_mem_size[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_hh_addr[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_hh_size[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_ph_addr[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_ph_size[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_th_addr[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_th_size[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_scratchpad_0_addr[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_scratchpad_0_size[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_scratchpad_1_addr[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_scratchpad_1_size[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_scratchpad_2_addr[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_scratchpad_2_size[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_scratchpad_3_addr[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_scratchpad_3_size[idx]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_ctx_enabled[idx]);
end

// latch the config
always @(posedge clk) begin
    if (!rstn) begin
for (idx = 0; idx < 4; idx = idx + 1)
    store_handler_mem_addr[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_handler_mem_size[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_host_mem_addr[idx] <= 64'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_host_mem_size[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_hh_addr[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_hh_size[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_ph_addr[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_ph_size[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_th_addr[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_th_size[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_0_addr[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_0_size[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_1_addr[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_1_size[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_2_addr[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_2_size[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_3_addr[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_3_size[idx] <= 32'h0;
for (idx = 0; idx < 4; idx = idx + 1)
    store_ctx_enabled[idx] <= 1'h0;
    end else if (conf_valid) begin
for (idx = 0; idx < 4; idx = idx + 1)
    store_handler_mem_addr[idx] <= `SLICE(conf_handler_mem_addr, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_handler_mem_size[idx] <= `SLICE(conf_handler_mem_size, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_host_mem_addr[idx] <= `SLICE(conf_host_mem_addr, idx, 64);
for (idx = 0; idx < 4; idx = idx + 1)
    store_host_mem_size[idx] <= `SLICE(conf_host_mem_size, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_hh_addr[idx] <= `SLICE(conf_hh_addr, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_hh_size[idx] <= `SLICE(conf_hh_size, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_ph_addr[idx] <= `SLICE(conf_ph_addr, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_ph_size[idx] <= `SLICE(conf_ph_size, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_th_addr[idx] <= `SLICE(conf_th_addr, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_th_size[idx] <= `SLICE(conf_th_size, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_0_addr[idx] <= `SLICE(conf_scratchpad_0_addr, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_0_size[idx] <= `SLICE(conf_scratchpad_0_size, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_1_addr[idx] <= `SLICE(conf_scratchpad_1_addr, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_1_size[idx] <= `SLICE(conf_scratchpad_1_size, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_2_addr[idx] <= `SLICE(conf_scratchpad_2_addr, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_2_size[idx] <= `SLICE(conf_scratchpad_2_size, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_3_addr[idx] <= `SLICE(conf_scratchpad_3_addr, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_scratchpad_3_size[idx] <= `SLICE(conf_scratchpad_3_size, idx, 32);
for (idx = 0; idx < 4; idx = idx + 1)
    store_ctx_enabled[idx] <= `SLICE(conf_ctx_enabled, idx, 1);
    end
end

// decode tag => msgid, is_eom, ctx_id
assign {decode_msgid, decode_is_eom, decode_ctx_id} = gen_tag;

// generate HER on completion - combinatorial
// FIXME: use a skid buffer if timing becomes an issue
always @* begin
    her_msgid = decode_msgid;
    her_is_eom = decode_is_eom;
    her_addr = gen_addr;
    her_size = gen_len;
    // TODO: determine ratio of DMA to L1
    her_xfer_size = gen_len;

    her_meta_handler_mem_addr = store_handler_mem_addr[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_handler_mem_size = store_handler_mem_size[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_host_mem_addr = store_host_mem_addr[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_host_mem_size = store_host_mem_size[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_hh_addr = store_hh_addr[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_hh_size = store_hh_size[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_ph_addr = store_ph_addr[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_ph_size = store_ph_size[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_th_addr = store_th_addr[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_th_size = store_th_size[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_scratchpad_0_addr = store_scratchpad_0_addr[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_scratchpad_0_size = store_scratchpad_0_size[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_scratchpad_1_addr = store_scratchpad_1_addr[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_scratchpad_1_size = store_scratchpad_1_size[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_scratchpad_2_addr = store_scratchpad_2_addr[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_scratchpad_2_size = store_scratchpad_2_size[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_scratchpad_3_addr = store_scratchpad_3_addr[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_meta_scratchpad_3_size = store_scratchpad_3_size[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
    her_valid = gen_valid;

    // default context set & PsPIN ready
    gen_ready = store_ctx_enabled[`DEFAULT_CTX_ID] && her_ready;
end

endmodule