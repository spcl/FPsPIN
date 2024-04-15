{% import "verilog-macros.j2" as m with context -%}

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
{{- m.call_group("me", m.declare_out, "match") }}

    // HER generator execution context
{{- m.call_group("her", m.declare_out, "her_gen") }}
{{- m.call_group("her_meta", m.declare_out, "her_gen") }}

    // egress datapath
    input  wire [3:0]                                       egress_dma_last_error
);

{{ m.declare_params() }}

localparam VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
localparam WORD_WIDTH = STRB_WIDTH;
localparam WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

localparam NUM_REGS = {{ num_regs }};

reg [DATA_WIDTH-1:0] ctrl_regs [NUM_REGS-1:0];

`define REGFILE_IDX_INVALID {VALID_ADDR_WIDTH{1'b1}}
wire [NUM_REGS-1:0] REGFILE_IDX_READONLY;

{%- for rg in groups.values() %}
{%- for sg in rg.expanded %}
{%- set name = sg.get_signal_name() %}
localparam [ADDR_WIDTH-1:0] {{ name }}_BASE = {{ "{{" }}ADDR_WIDTH{1'b0}}, 32'h{{ "%x"|format(sg.get_base_addr()) }}};
localparam {{ name }}_REG_COUNT = {{ sg.count }};
localparam {{ name }}_REG_OFF = {{ sg.glb_idx }};
assign REGFILE_IDX_READONLY[{{ sg.glb_idx + sg.count - 1 }}:{{ sg.glb_idx }}] = {{ "%d'b%s" | format(sg.count, (sg.readonly|int|string) * sg.count) }};
{% endfor %}
{% endfor %}

initial begin
    if (DATA_WIDTH != {{ args.word_size * 8 }}) begin
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
{% macro decode(op) -%}
reg [VALID_ADDR_WIDTH-1:0] regfile_idx_{{ op }};
reg [15:0] block_id_{{ op }}, block_offset_{{ op }};
always @* begin
    block_id_{{ op }}     = reg_intf_{{ op }}_addr & 32'hf000;
    block_offset_{{ op }} = reg_intf_{{ op }}_addr & 32'h0fff;
    case (block_id_{{ op }})
    {%- for rg in groups.values() %}
        {%- for sg in rg.expanded %}
        {%- set name = sg.get_signal_name() %}
        {{ name }}_BASE: regfile_idx_{{ op }} = {{ name }}_REG_OFF + (block_offset_{{ op }} >> (ADDR_WIDTH - VALID_ADDR_WIDTH));
        {%- endfor %}
    {% endfor %}
        default:  regfile_idx_{{ op }} = `REGFILE_IDX_INVALID;
    endcase
end
{%- endmacro -%}

{{ decode("wr") }}
{{ decode("rd") }}

integer i;
// register output
always @* begin
    cl_fetch_en_o = ctrl_regs[CL_CTRL_REG_OFF];
    aux_rst_o = ctrl_regs[CL_CTRL_REG_OFF + 1][0];

{%- macro assign_out(signal_name, sg) %}
    for (i = 0; i < {{ sg.count }}; i = i + 1)
        `SLICE({{ signal_name }}_{{ sg.name }}, i, {{ sg.signal_width }}) =
    {%- if sg.is_extended() %} {
        {%- for child in sg.expanded | reverse %}
            ctrl_regs[{{ child.get_signal_name() }}_REG_OFF + i]{{ "," if loop.index + 1 == sg.expanded | length }}
        {%- endfor %}
        };
    {%- else %} ctrl_regs[{{ sg.get_signal_name() }}_REG_OFF + i];
    {%- endif %}
{%- endmacro %}

    // Matching engine
{{- m.call_group("me", assign_out, "match") }}

    // HER generator execution context
{{- m.call_group("her", assign_out, "her_gen") }}
{{- m.call_group("her_meta", assign_out, "her_gen") }}
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
        {% raw -%}
        ctrl_regs[STATS_MPQ_REG_OFF] <= {{DATA_WIDTH - NUM_MPQ{1'b0}}, mpq_full_i};
        {%- endraw %}

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