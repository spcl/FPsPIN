{% import "verilog-macros.j2" as m with context -%}
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
{{- m.call_group_single("her_meta", m.declare_out, "her_meta") }}

    // execution context from ctrl regs
{{- m.call_group("her_meta", m.declare_in, "conf")}}
{{- m.call_group("her", m.declare_in, "conf")}}

    // completion from ingress DMA
    input  wire [AXI_ADDR_WIDTH-1:0]        gen_addr,
    input  wire [LEN_WIDTH-1:0]             gen_len,
    input  wire [TAG_WIDTH-1:0]             gen_tag,
    input  wire                             gen_valid,
    output reg                              gen_ready
);

{{ m.declare_params() }}

localparam CTX_ID_WIDTH = $clog2(HER_NUM_HANDLER_CTX);
`define DEFAULT_CTX_ID {CTX_ID_WIDTH{1'b0}}

{{- m.call_group("her_meta", m.declare_store, None) }}
{{- m.call_group("her", m.declare_store, None) }}

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
{{- m.call_group("her_meta", m.dump_store, None) }}
{{- m.call_group("her", m.dump_store, None) }}
end

// latch the config
always @(posedge clk) begin
    if (!rstn) begin
{{- m.call_group("her_meta", m.reset_store, None) }}
{{- m.call_group("her", m.reset_store, None) }}
    end else if (conf_valid) begin
{{- m.call_group("her_meta", m.update_store, "conf") }}
{{- m.call_group("her", m.update_store, "conf") }}
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
{%- macro assign_her(_, sg) %}
    her_meta_{{ sg.name }} = store_{{ sg.name }}[store_ctx_enabled[decode_ctx_id] ? decode_ctx_id : `DEFAULT_CTX_ID];
{%- endmacro %}
{{ m.call_group("her_meta", assign_her, None) }}
    her_valid = gen_valid;

    // default context set & PsPIN ready
    gen_ready = store_ctx_enabled[`DEFAULT_CTX_ID] && her_ready;
end

endmodule