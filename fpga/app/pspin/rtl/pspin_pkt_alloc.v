/**
 * PsPIN Packet Allocator
 *
 * Allocate buffer for incoming packets.  Incoming packet take free space from
 * SLOT0 (large slot) or SLOT1 (small slot); the exact division of the buffer
 * is configurable.
 */

`timescale 1ns / 1ps

module pspin_pkt_alloc #
(
    parameter LEN_WIDTH = 20,
    parameter TAG_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter MSGID_WIDTH = 10,
    // spin_hw_conf.h: L2_PKT_BUFF_START
    parameter [ADDR_WIDTH-1:0] BUF_START = 32'h1c100000,
    // spin_hw_conf.h: L2_PKT_BUFF_SIZE
    parameter [ADDR_WIDTH-1:0] BUF_SIZE = 1*1024*1024,
    // large packets: Ethernet frame max 1518 (rounded to ALIGNMENT)
    parameter [LEN_WIDTH-1:0] SLOT0_SIZE = 1536,   
    parameter [LEN_WIDTH-1:0] SLOT0_COUNT = 1024,
    // small packets
    parameter [LEN_WIDTH-1:0] SLOT1_SIZE = 64,
    parameter [LEN_WIDTH-1:0] SLOT1_COUNT = 8192,
    // pspin_cfg_pkg::MEM_PKT_CUT_DW, in bytes
    parameter [LEN_WIDTH-1:0] PKT_MEM_ALIGNMENT = 64
) (
    input  wire clk,
    input  wire rstn,

    // from matching engine
    input  wire [TAG_WIDTH-1:0] pkt_tag_i,
    input  wire [LEN_WIDTH-1:0] pkt_len_i,
    input  wire pkt_valid_i,
    output wire pkt_ready_o,

    // from PsPIN
    output wire feedback_ready_o,
    input  wire feedback_valid_i,
    input  wire [ADDR_WIDTH-1:0] feedback_her_addr_i,
    input  wire [LEN_WIDTH-1:0] feedback_her_size_i,
    input  wire [MSGID_WIDTH-1:0] feedback_msgid_i,

    // to AXI DMA
    output reg  [ADDR_WIDTH-1:0] write_addr_o,
    output reg  [LEN_WIDTH-1:0] write_len_o,
    output reg  [TAG_WIDTH-1:0] write_tag_o,
    output reg  write_valid_o,
    input  wire write_ready_i,

    // statistics
    output reg  [31:0] dropped_pkts_o
);

function [LEN_WIDTH-1:0] size_roundup;
    input [LEN_WIDTH-1:0] pkt_size, alignment;
    reg [LEN_WIDTH-1:0] segments;
    begin
        segments = (pkt_size + alignment - 1) >> $clog2(alignment);
        size_roundup = segments << $clog2(alignment);
    end
endfunction

localparam SLOT0_START = BUF_START;
localparam SLOT1_START = SLOT0_START + SLOT0_COUNT * SLOT0_SIZE;

localparam aligned_slot0_size = size_roundup(SLOT0_SIZE, PKT_MEM_ALIGNMENT);
localparam aligned_slot1_size = size_roundup(SLOT1_SIZE, PKT_MEM_ALIGNMENT);
localparam total_size = SLOT0_SIZE * SLOT0_COUNT + SLOT1_SIZE * SLOT1_COUNT;

// size & alignment assertions
initial begin
    if (aligned_slot0_size != SLOT0_SIZE) begin
        $error("Error: SLOT0 size not aligned: %d vs %d", aligned_slot0_size, SLOT0_SIZE);
        $finish;
    end

    if (aligned_slot1_size != SLOT1_SIZE) begin
        $error("Error: SLOT1 size not aligned: %d vs %d", aligned_slot1_size, SLOT1_SIZE);
        $finish;
    end

    if (total_size > BUF_SIZE) begin
        $error("Error: total size from slot 0 and 1 exceeds total size: %d vs %d", total_size, BUF_SIZE);
        $finish;
    end

    $display("Slot 0 has %d slots of %d bytes, starting at 0x%0h", SLOT0_COUNT, SLOT0_SIZE, SLOT0_START);
    $display("Slot 1 has %d slots of %d bytes, starting at 0x%0h", SLOT1_COUNT, SLOT1_SIZE, SLOT1_START);
end

reg [31:0] dropped_pkts_d;

// free item
reg initialised_q, initialised_d;

wire slot0_enq_ready, slot1_enq_ready;
wire slot0_enq_valid, slot1_enq_valid;
wire [ADDR_WIDTH-1:0] slot0_enq_data, slot1_enq_data;

reg [ADDR_WIDTH-1:0] slot0_init_enq_data, slot1_init_enq_data;
reg [ADDR_WIDTH-1:0] slot0_free_enq_data, slot1_free_enq_data;
reg slot0_init_enq_valid, slot1_init_enq_valid;
reg slot0_free_enq_valid, slot1_free_enq_valid;

assign slot0_enq_valid = initialised_q ? slot0_free_enq_valid : slot0_init_enq_valid;
assign slot0_enq_data = initialised_q ? slot0_free_enq_data : slot0_init_enq_data;
assign slot1_enq_valid = initialised_q ? slot1_free_enq_valid : slot1_init_enq_valid;
assign slot1_enq_data = initialised_q ? slot1_free_enq_data : slot1_init_enq_data;

wire slot0_deq_valid, slot1_deq_valid;
wire [ADDR_WIDTH-1:0] slot0_deq_data, slot1_deq_data;
reg slot0_deq_ready, slot1_deq_ready;

reg [31:0] slot0_free_count_q, slot1_free_count_q;
reg [31:0] slot0_free_count_d, slot1_free_count_d;

// free FIFO
axis_fifo #(
    .DEPTH(SLOT0_COUNT),
    .DATA_WIDTH(ADDR_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .USER_ENABLE(0)
) i_fifo_slot0 (
    .clk(clk),
    .rst(!rstn),

    .s_axis_tdata       (slot0_enq_data),
    .s_axis_tvalid      (slot0_enq_valid),
    .s_axis_tready      (slot0_enq_ready),

    .m_axis_tdata       (slot0_deq_data),
    .m_axis_tvalid      (slot0_deq_valid),
    .m_axis_tready      (slot0_deq_ready)
);

axis_fifo #(
    .DEPTH(SLOT1_COUNT),
    .DATA_WIDTH(ADDR_WIDTH),
    .KEEP_ENABLE(0),
    .LAST_ENABLE(0),
    .USER_ENABLE(0)
) i_fifo_slot1 (
    .clk(clk),
    .rst(!rstn),

    .s_axis_tdata       (slot1_enq_data),
    .s_axis_tvalid      (slot1_enq_valid),
    .s_axis_tready      (slot1_enq_ready),

    .m_axis_tdata       (slot1_deq_data),
    .m_axis_tvalid      (slot1_deq_valid),
    .m_axis_tready      (slot1_deq_ready)
);

assign pkt_ready_o = write_ready_i && initialised_q && slot0_free_count_q > 0 && slot1_free_count_q > 0;
assign feedback_ready_o = slot0_enq_ready && slot1_enq_ready;

always @(posedge clk) begin
    if (!rstn) begin
        initialised_q <= 1'b0;
        slot0_free_count_q <= 32'h0;
        slot1_free_count_q <= 32'h0;
        dropped_pkts_o <= 32'h0;
    end else begin
        initialised_q <= initialised_d;
        slot0_free_count_q <= slot0_free_count_d;
        slot1_free_count_q <= slot1_free_count_d;
        dropped_pkts_o <= dropped_pkts_d;
    end
end

always @* begin
    initialised_d = initialised_q;
    slot0_free_count_d = slot0_free_count_q;
    slot1_free_count_d = slot1_free_count_q;
    dropped_pkts_d = dropped_pkts_o;

    slot0_init_enq_valid = 1'b0;
    slot1_init_enq_valid = 1'b0;
    slot0_init_enq_data  = {ADDR_WIDTH{1'b0}};
    slot1_init_enq_data  = {ADDR_WIDTH{1'b0}};

    slot0_free_enq_valid = 1'b0;
    slot1_free_enq_valid = 1'b0;
    slot0_free_enq_data  = {ADDR_WIDTH{1'b0}};
    slot1_free_enq_data  = {ADDR_WIDTH{1'b0}};

    slot0_deq_ready = 1'b0;
    slot1_deq_ready = 1'b0;

    write_addr_o = {ADDR_WIDTH{1'b0}};
    write_len_o = {LEN_WIDTH{1'b0}};
    write_tag_o = {TAG_WIDTH{1'b0}};
    write_valid_o = 1'b0;

    if (!initialised_d) begin
        if (slot0_free_count_d < SLOT0_COUNT) begin
            slot0_init_enq_valid = 1'b1;
            slot0_init_enq_data = SLOT0_START + SLOT0_SIZE * slot0_free_count_d;
            if (slot0_enq_ready)
                slot0_free_count_d = slot0_free_count_d + 1;
        end

        if (slot1_free_count_d < SLOT1_COUNT) begin
            slot1_init_enq_valid = 1'b1;
            slot1_init_enq_data = SLOT1_START + SLOT1_SIZE * slot1_free_count_d;
            if (slot1_enq_ready)
                slot1_free_count_d = slot1_free_count_d + 1;
        end
        
        if (slot0_free_count_d == SLOT0_COUNT && slot1_free_count_d == SLOT1_COUNT)
            initialised_d = 1'b1;
    end

    if (pkt_valid_i && pkt_ready_o) begin
        write_tag_o = pkt_tag_i;
        if (SLOT0_SIZE >= pkt_len_i && pkt_len_i > SLOT1_SIZE) begin
            slot0_deq_ready    = 1'b1;
            slot0_free_count_d = slot0_free_count_d - 1;
            write_valid_o      = slot0_deq_valid;
            write_addr_o       = slot0_deq_data;
            // we should pass the packet length
            write_len_o        = pkt_len_i;
        end else if (SLOT1_SIZE >= pkt_len_i) begin
            slot1_deq_ready    = 1'b1;
            slot1_free_count_d = slot1_free_count_d - 1;
            write_valid_o      = slot1_deq_valid;
            write_addr_o       = slot1_deq_data;
            // we should pass the packet length
            write_len_o        = pkt_len_i;
        end else begin
            // packet too big, dropping
            $display("Packet of size %d too big, dropped", pkt_len_i);
            dropped_pkts_d = dropped_pkts_d + 1;
        end
    end

    if (feedback_valid_i && feedback_ready_o) begin
        if (SLOT0_SIZE >= feedback_her_size_i && feedback_her_size_i > SLOT1_SIZE) begin
            slot0_free_enq_valid = 1'b1;
            slot0_free_enq_data  = feedback_her_addr_i;
            slot0_free_count_d   = slot0_free_count_d + 1;
        end else if (SLOT1_SIZE >= feedback_her_size_i) begin
            slot1_free_enq_valid = 1'b1;
            slot1_free_enq_data  = feedback_her_addr_i;
            slot1_free_count_d   = slot1_free_count_d + 1;
        end else begin
            // bad size
            $display("Feedback of size %d unrecognised", feedback_her_size_i);
        end
    end
end

endmodule