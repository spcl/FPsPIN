/* Generated on 2023-08-27 16:16:25.283867 with: ./regs-compiler.py --all v ../rtl */

/**
 * PsPIN Packet Match Engine
 *
 * Match against a total of UMATCH_ENTRIES number of packets.  For each rule:
 *     matched == (start <= packet[idx] & mask <= end)
 * Multiple rules are combined based on match_mode.  Currently supported
 * modes:
 *     0: AND of all rules
 *     1: OR of all rules
 * To disable a rule, put UMATCH_WIDTH{1'b0} in mask.  The rule would generate
 * the respective unit value in the combining modes.
 *
 * The matcher only inspects packets for matching up to UMATCH_MATCHER_LEN for
 * making the decision if a packet matched or not.  The matchers with an index
 * over this limit are turned off (same as with mask == 0).
 *
 * The size and index of the packets are also reported with a simple valid
 * interface.  This should be available for at least one cycle (the IDLE state)
 * before the sending of the next packet takes place.  The DMA engine will need
 * to have an AXI FIFO to delay the stream sufficiently for address generation.
 *
 * The matching unit has multiple rulesets, each of which corresponds to one
 * handler execution context later in the HER generator.  The ID of which ruleset
 * matched is selected via a priority encoder (lower has higher priority) and
 * then passed in the packet tag to the allocator.  The allocator forwards this
 * tag to the HER generator.
 *
 * The end-of-message bit is generated from the last rule in the ruleset.
 */

`timescale 1ns / 1ps
`define SLICE(arr, idx, width) arr[(idx)*(width) +: width]

module pspin_pkt_match #(
    parameter UMATCH_MATCHER_LEN = 66, // TCP + IP + ETH
    parameter UMATCH_MTU = 1500,       // Ethernet MTU - set to 9000 for jumbo frames
    parameter UMATCH_BUF_FRAMES = 3,

    parameter AXIS_IF_DATA_WIDTH = 512,
    parameter AXIS_IF_KEEP_WIDTH = AXIS_IF_DATA_WIDTH/8,
    parameter AXIS_IF_RX_ID_WIDTH = 1,
    parameter AXIS_IF_RX_DEST_WIDTH = 8,
    parameter AXIS_IF_RX_USER_WIDTH = 16,

    parameter TAG_WIDTH = 64,
    parameter MSG_ID_WIDTH = 32
) (
    input wire clk,
    input wire rstn,

    // from NIC
    input  wire [AXIS_IF_DATA_WIDTH-1:0]         s_axis_nic_rx_tdata,
    input  wire [AXIS_IF_KEEP_WIDTH-1:0]         s_axis_nic_rx_tkeep,
    input  wire                                  s_axis_nic_rx_tvalid,
    output wire                                  s_axis_nic_rx_tready,
    input  wire                                  s_axis_nic_rx_tlast,
    input  wire [AXIS_IF_RX_ID_WIDTH-1:0]        s_axis_nic_rx_tid,
    input  wire [AXIS_IF_RX_DEST_WIDTH-1:0]      s_axis_nic_rx_tdest,
    input  wire [AXIS_IF_RX_USER_WIDTH-1:0]      s_axis_nic_rx_tuser,

    // to NIC - unmatched
    output wire [AXIS_IF_DATA_WIDTH-1:0]         m_axis_nic_rx_tdata,
    output wire [AXIS_IF_KEEP_WIDTH-1:0]         m_axis_nic_rx_tkeep,
    output wire                                  m_axis_nic_rx_tvalid,
    input  wire                                  m_axis_nic_rx_tready,
    output wire                                  m_axis_nic_rx_tlast,
    output wire [AXIS_IF_RX_ID_WIDTH-1:0]        m_axis_nic_rx_tid,
    output wire [AXIS_IF_RX_DEST_WIDTH-1:0]      m_axis_nic_rx_tdest,
    output wire [AXIS_IF_RX_USER_WIDTH-1:0]      m_axis_nic_rx_tuser,

    // to PsPIN - matched
    output wire [AXIS_IF_DATA_WIDTH-1:0]         m_axis_pspin_rx_tdata,
    output wire [AXIS_IF_KEEP_WIDTH-1:0]         m_axis_pspin_rx_tkeep,
    output wire                                  m_axis_pspin_rx_tvalid,
    input  wire                                  m_axis_pspin_rx_tready,
    output wire                                  m_axis_pspin_rx_tlast,
    output wire [AXIS_IF_RX_ID_WIDTH-1:0]        m_axis_pspin_rx_tid,
    output wire [AXIS_IF_RX_DEST_WIDTH-1:0]      m_axis_pspin_rx_tdest,
    output wire [AXIS_IF_RX_USER_WIDTH-1:0]      m_axis_pspin_rx_tuser,

    // matching rules
    input wire [0:0] match_valid,
    input wire [3:0] match_mode,
    input wire [511:0] match_idx,
    input wire [511:0] match_mask,
    input wire [511:0] match_start,
    input wire [511:0] match_end,

    // packet metadata - size and index
    output wire [TAG_WIDTH-1:0]                  packet_meta_tag,
    output reg  [31:0]                           packet_meta_size,
    output reg                                   packet_meta_valid,
    input  wire                                  packet_meta_ready
);


localparam UMATCH_WIDTH = 32;
localparam UMATCH_ENTRIES = 4;
localparam UMATCH_RULESETS = 4;
localparam UMATCH_MODES = 2;
localparam HER_NUM_HANDLER_CTX = 4;

localparam MATCHER_BEATS = (UMATCH_MATCHER_LEN * 8 + AXIS_IF_DATA_WIDTH - 1) / (AXIS_IF_DATA_WIDTH);
localparam MATCHER_WIDTH = MATCHER_BEATS * AXIS_IF_DATA_WIDTH;
localparam MATCHER_IDX_WIDTH = $clog2(MATCHER_WIDTH / UMATCH_WIDTH);
localparam NUM_MATCHERS = UMATCH_ENTRIES * UMATCH_RULESETS;
localparam PACKET_BEATS = (UMATCH_MTU * 8 + AXIS_IF_DATA_WIDTH - 1) / (AXIS_IF_DATA_WIDTH);
localparam BUFFER_FIFO_DEPTH = UMATCH_BUF_FRAMES * PACKET_BEATS * AXIS_IF_KEEP_WIDTH;

wire [AXIS_IF_DATA_WIDTH-1:0]         buffered_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0]         buffered_tkeep;
wire                                  buffered_tvalid;
reg                                   buffered_tready;
wire                                  buffered_tlast;
wire [AXIS_IF_RX_ID_WIDTH-1:0]        buffered_tid;
wire [AXIS_IF_RX_DEST_WIDTH-1:0]      buffered_tdest;
wire [AXIS_IF_RX_USER_WIDTH-1:0]      buffered_tuser;
wire                                  buffered_overflow;
wire                                  buffered_good_frame;
wire                                  buffered_bad_frame;

reg [AXIS_IF_DATA_WIDTH-1:0]          send_tdata;
reg [AXIS_IF_KEEP_WIDTH-1:0]          send_tkeep;
reg                                   send_tvalid;
wire                                  send_tready;
reg                                   send_tlast;
reg [AXIS_IF_RX_ID_WIDTH-1:0]         send_tid;
reg [AXIS_IF_RX_DEST_WIDTH-1:0]       send_tdest;
reg [AXIS_IF_RX_USER_WIDTH-1:0]       send_tuser;

wire [AXIS_IF_DATA_WIDTH-1:0]         send_comb_tdata;
wire [AXIS_IF_KEEP_WIDTH-1:0]         send_comb_tkeep;
wire                                  send_comb_tvalid;
wire                                  send_comb_tready;
wire                                  send_comb_tlast;
wire [AXIS_IF_RX_ID_WIDTH-1:0]        send_comb_tid;
wire [AXIS_IF_RX_DEST_WIDTH-1:0]      send_comb_tdest;
wire [AXIS_IF_RX_USER_WIDTH-1:0]      send_comb_tuser;

// state
localparam [3:0]
    IDLE = 4'h0,            // waiting for incoming packet
    RECV = 4'h1,            // recv into matcher
    RECV_WAIT = 4'h2,       // wait for upstream
    RECV_LAST = 4'h3,       // recv last beat of matcher
    MATCH = 4'h4,           // match against matcher
    SEND = 4'h5,            // send from matcher
    SEND_WAIT = 4'h6,       // wait for downstream
    SEND_LAST = 4'h7,       // send last beat of matcher
    PASSTHROUGH = 4'h8,     // pass through pending data
    META = 4'h9;            // wait for metadata transmit
reg [3:0] state_q, state_d;
reg passthrough_q, passthrough_d;

// outputs
reg [MATCHER_WIDTH-1:0] matcher;
reg [MATCHER_IDX_WIDTH-1:0] matcher_idx;
reg [MATCHER_IDX_WIDTH-1:0] last_idx;
localparam
    MATCH_AND = 1'b0,
    MATCH_OR = 1'b1;

// saved axis metadata
reg [AXIS_IF_KEEP_WIDTH-1:0] saved_tkeep [MATCHER_BEATS-1:0];
reg [AXIS_IF_RX_USER_WIDTH-1:0] saved_tuser [MATCHER_BEATS-1:0];
reg [AXIS_IF_RX_ID_WIDTH-1:0] saved_tid [MATCHER_BEATS-1:0];
reg [AXIS_IF_RX_DEST_WIDTH-1:0] saved_tdest [MATCHER_BEATS-1:0];

// saved matching rules - only updated when in IDLE
reg [0:0] store_mode [3:0];
reg [31:0] store_idx [15:0];
reg [31:0] store_mask [15:0];
reg [31:0] store_start [15:0];
reg [31:0] store_end [15:0];

// matching units, in rulesets
reg [UMATCH_WIDTH-1:0]      mu_data  [UMATCH_RULESETS-1:0][UMATCH_ENTRIES-1:0];
reg [UMATCH_WIDTH-1:0]      mu_mask  [UMATCH_RULESETS-1:0][UMATCH_ENTRIES-1:0];
reg [UMATCH_WIDTH-1:0]      mu_start [UMATCH_RULESETS-1:0][UMATCH_ENTRIES-1:0];
reg [UMATCH_WIDTH-1:0]      mu_end   [UMATCH_RULESETS-1:0][UMATCH_ENTRIES-1:0];
reg [MATCHER_IDX_WIDTH-1:0] mu_idx   [UMATCH_RULESETS-1:0][UMATCH_ENTRIES-1:0];
reg [UMATCH_ENTRIES-1:0] mu_matched  [UMATCH_RULESETS-1:0];

reg [UMATCH_RULESETS-1:0] and_matched;
reg [UMATCH_RULESETS-1:0] or_matched;
reg [UMATCH_RULESETS-1:0] ruleset_matched;
reg [UMATCH_RULESETS-1:0] ruleset_eom;
reg matched_d, matched_q;
reg [$clog2(UMATCH_RULESETS)-1:0] matched_ruleset_id_d, matched_ruleset_id_q;
reg matched_ruleset_eom_d, matched_ruleset_eom_q;

// tag output
wire [MSG_ID_WIDTH-1:0] slmp_msg_id = `SLICE(matcher, 11, 32); // 11th 32-bit word in ETH+IP+UDP+SLMP
reg  [MSG_ID_WIDTH-1:0] slmp_msg_id_q;

integer idx;
always @* begin
    for (idx = 0; idx < UMATCH_RULESETS; idx = idx + 1) begin
        and_matched[idx] = &mu_matched[idx][UMATCH_ENTRIES-2:0];
        or_matched [idx] = |mu_matched[idx][UMATCH_ENTRIES-2:0];
        ruleset_matched[idx] = store_mode[idx] == MATCH_AND ? and_matched[idx] : or_matched[idx];
        ruleset_eom[idx] = mu_matched[idx][UMATCH_ENTRIES-1];
    end

    matched_d = 1'b0;
    matched_ruleset_id_d = {$clog2(UMATCH_RULESETS){1'b0}};
    matched_ruleset_eom_d = 1'b0;
    // priority encoder
    for (idx = UMATCH_RULESETS-1; idx >= 0; idx = idx - 1) begin
        if (ruleset_matched[idx]) begin
            matched_ruleset_eom_d = ruleset_eom[idx];
            matched_ruleset_id_d = idx;
            matched_d = 1'b1;
        end
    end
end

initial begin
    if (UMATCH_MODES != 2) begin
        $error("Error: exactly 2 modes supported: AND and OR");
        $finish;
    end
    if (TAG_WIDTH < MSG_ID_WIDTH + 1 + $clog2(UMATCH_RULESETS)) begin
        $error("Error: TAG_WIDTH (%d) cannot fit packet id, EOM, and ruleset id", TAG_WIDTH);
        $finish;
    end

    // matcher should be at least as wide to include SLMP message ID
    if (UMATCH_MATCHER_LEN < 48) begin
        $error("Error: matcher too narrow for SLMP message ID (%d vs 48)", UMATCH_MATCHER_LEN);
        $finish;
    end

    $display("Pkt match engine:");
    $display("\t%d rules per ruleset", UMATCH_ENTRIES);
    $display("\t%d rulesets", UMATCH_RULESETS);
    $display("\t%d bit beat width", AXIS_IF_DATA_WIDTH);
    $display("\t%d bytes max matching length", UMATCH_MATCHER_LEN);
    $display("\t%d bytes mtu", UMATCH_MTU);
    $display("\t%d frames buffered", UMATCH_BUF_FRAMES);
end

generate
genvar i, j;
// per matching unit
for (j = 0; j < UMATCH_RULESETS; j = j + 1) begin
    initial $dumpvars(0, mu_matched[j]);

    for (i = 0; i < UMATCH_ENTRIES; i = i + 1) begin
        // dumping multi-dimensional arrays needs generate block
        // https://github.com/steveicarus/iverilog/issues/75#issuecomment-129031448
        initial begin
            $dumpvars(0, mu_data [j][i]);
            $dumpvars(0, mu_mask [j][i]);
            $dumpvars(0, mu_idx  [j][i]);
            $dumpvars(0, mu_start[j][i]);
            $dumpvars(0, mu_end  [j][i]);
for (idx = 0; idx < 4; idx = idx + 1)
    $dumpvars(0, store_mode[idx]);
for (idx = 0; idx < 16; idx = idx + 1)
    $dumpvars(0, store_idx[idx]);
for (idx = 0; idx < 16; idx = idx + 1)
    $dumpvars(0, store_mask[idx]);
for (idx = 0; idx < 16; idx = idx + 1)
    $dumpvars(0, store_start[idx]);
for (idx = 0; idx < 16; idx = idx + 1)
    $dumpvars(0, store_end[idx]);
        end

        always @* begin
            mu_idx  [j][i] = store_idx[j * UMATCH_RULESETS + i];
            mu_mask [j][i] = store_mask[j * UMATCH_RULESETS + i];
            mu_start[j][i] = store_start[j * UMATCH_RULESETS + i];
            mu_end  [j][i] = store_end[j * UMATCH_RULESETS + i];

            mu_data [j][i] = `SLICE(matcher, mu_idx[j][i], UMATCH_WIDTH) & mu_mask[j][i];

            mu_matched[j][i] =
                mu_start[j][i] <= mu_data[j][i] && mu_end[j][i] >= mu_data[j][i];
        end
    end
end
endgenerate

// packet metadata
always @(posedge clk) begin
    if (send_comb_tvalid && send_tready) begin
        packet_meta_size <= packet_meta_size + AXIS_IF_DATA_WIDTH / 8;
        if (send_comb_tlast) begin
            // we should still be in PASSTHROUGH / SEND_TLAST, so capture matched_q
            // we should only output meta if matched
            packet_meta_valid <= matched_q;
        end
    end

    if (packet_meta_ready && packet_meta_valid)
        packet_meta_valid <= 1'b0;

    // if IDLE, meta must have been successfully transmitted
    // (otherwise in META)
    if (state_q == IDLE) begin
        packet_meta_size <= 32'b0;
        packet_meta_valid <= 1'b0;
    end

    if (!rstn) begin
        packet_meta_size <= 32'b0;
        packet_meta_valid <= 1'b0;
    end
end
// TODO: match for end-of-message properly
assign packet_meta_tag = {slmp_msg_id_q, matched_ruleset_eom_q, matched_ruleset_id_q};

always @(posedge clk) begin
    if (!rstn) begin
        state_q <= IDLE;
        passthrough_q <= 1'b0;
    end else begin
        state_q <= state_d;
        passthrough_q <= passthrough_d;
    end
end

// state transition
always @* begin
    state_d = state_q;
    passthrough_d = passthrough_q;

    case (state_q)
        IDLE: if (buffered_tvalid && buffered_tready) begin
            if (buffered_tlast) // only one beat
                state_d = RECV_LAST;
            else
                state_d = RECV;
            if (matcher_idx == MATCHER_BEATS - 1) begin
                state_d = RECV_LAST;
                passthrough_d = 1'b1;
            end
        end
        RECV, RECV_WAIT: if (buffered_tvalid && buffered_tready) begin
            if (buffered_tlast)
                state_d = RECV_LAST;
            else if (matcher_idx == MATCHER_BEATS - 1) begin
                state_d = RECV_LAST;
                passthrough_d = 1'b1;
            end else
                state_d = RECV;
        end else
            state_d = RECV_WAIT;
        RECV_LAST: state_d = MATCH;
        MATCH: if (last_idx == matcher_idx) // only one beat
            state_d = SEND_LAST;
        else
            state_d = SEND;
        SEND, SEND_WAIT: if (send_tvalid && send_tready) begin
            if (last_idx == matcher_idx)
                state_d = SEND_LAST;
            else
                state_d = SEND;
        end else
            state_d = SEND_WAIT;
        SEND_LAST: if (send_tvalid && send_tready)
            if (passthrough_q)
                state_d = PASSTHROUGH;
            else if (!matched_q)
                state_d = IDLE;
            else
                state_d = META;
        PASSTHROUGH: if (send_comb_tvalid && send_comb_tready && send_comb_tlast) begin
            if (!matched_q)
                state_d = IDLE;
            else
                state_d = META;
            passthrough_d = 1'b0;
        end
        META: if (packet_meta_ready && packet_meta_valid)
            state_d = IDLE;
        default: state_d = IDLE;
    endcase
end

// state-machine output
integer k;
always @(posedge clk) begin
    case (state_d) // next state
        META, IDLE: begin
            matcher <= {MATCHER_WIDTH{1'b0}};
            matcher_idx <= {MATCHER_IDX_WIDTH{1'b0}};
            last_idx <= {MATCHER_IDX_WIDTH{1'b0}};
            matched_q <= 1'b0;
            send_tdata <= {AXIS_IF_DATA_WIDTH{1'b0}};
            send_tvalid <= 1'b0;
            send_tlast <= 1'b0;
            send_tkeep <= {AXIS_IF_KEEP_WIDTH{1'b0}};
            // wait until META finished
            buffered_tready <= state_d == IDLE;

            for (k = 0; k < MATCHER_BEATS; k = k + 1) begin
                saved_tkeep[k] <= {AXIS_IF_KEEP_WIDTH{1'b0}};
                saved_tuser[k] <= {AXIS_IF_RX_USER_WIDTH{1'b0}};
                saved_tid[k] <= {AXIS_IF_RX_ID_WIDTH{1'b0}};
                saved_tdest[k] <= {AXIS_IF_RX_DEST_WIDTH{1'b0}};
            end

            if (match_valid) begin
for (idx = 0; idx < 4; idx = idx + 1)
    store_mode[idx] <= `SLICE(match_mode, idx, 1);
for (idx = 0; idx < 16; idx = idx + 1)
    store_idx[idx] <= `SLICE(match_idx, idx, 32);
for (idx = 0; idx < 16; idx = idx + 1)
    store_mask[idx] <= `SLICE(match_mask, idx, 32);
for (idx = 0; idx < 16; idx = idx + 1)
    store_start[idx] <= `SLICE(match_start, idx, 32);
for (idx = 0; idx < 16; idx = idx + 1)
    store_end[idx] <= `SLICE(match_end, idx, 32);
            end else begin
for (idx = 0; idx < 4; idx = idx + 1)
    store_mode[idx] <= 1'h0;
for (idx = 0; idx < 16; idx = idx + 1)
    store_idx[idx] <= 32'h0;
for (idx = 0; idx < 16; idx = idx + 1)
    store_mask[idx] <= 32'h0;
for (idx = 0; idx < 16; idx = idx + 1)
    store_start[idx] <= 32'h1;
for (idx = 0; idx < 16; idx = idx + 1)
    store_end[idx] <= 32'h0;
            end

            matched_q <= 1'b0;
        end
        RECV: begin
            // FIXME: handle tkeep correctly
            `SLICE(matcher, matcher_idx, AXIS_IF_DATA_WIDTH) <= buffered_tdata;
            matcher_idx <= matcher_idx + 1;
            saved_tkeep[matcher_idx] <= buffered_tkeep;
            saved_tuser[matcher_idx] <= buffered_tuser;
            saved_tid[matcher_idx] <= buffered_tid;
            saved_tdest[matcher_idx] <= buffered_tdest;

            // update message ID reg
            slmp_msg_id_q <= slmp_msg_id;
        end
        // RECV_WAIT: nothing
        RECV_LAST: begin
            `SLICE(matcher, matcher_idx, AXIS_IF_DATA_WIDTH) <= buffered_tdata;
            matcher_idx <= {MATCHER_IDX_WIDTH{1'b0}};
            last_idx <= matcher_idx;
            saved_tkeep[matcher_idx] <= buffered_tkeep;
            saved_tuser[matcher_idx] <= buffered_tuser;
            saved_tid[matcher_idx] <= buffered_tid;
            saved_tdest[matcher_idx] <= buffered_tdest;
            buffered_tready <= 1'b0;

            // update message ID reg
            slmp_msg_id_q <= slmp_msg_id;
        end
        MATCH: begin
            matched_ruleset_id_q <= matched_ruleset_id_d;
            matched_ruleset_eom_q <= matched_ruleset_eom_d;
            matched_q <= matched_d;

            // update message ID reg - one cycle latency from matcher
            slmp_msg_id_q <= slmp_msg_id;
        end
        SEND: begin
            send_tdata <= `SLICE(matcher, matcher_idx, AXIS_IF_DATA_WIDTH);
            matcher_idx <= matcher_idx + 1;
            send_tvalid <= 1'b1;
            send_tkeep <= saved_tkeep[matcher_idx];
            send_tuser <= saved_tuser[matcher_idx];
            send_tid <= saved_tid[matcher_idx];
            send_tdest <= saved_tdest[matcher_idx];
        end
        // SEND_WAIT: nothing
        SEND_LAST: begin
            send_tdata <= `SLICE(matcher, matcher_idx, AXIS_IF_DATA_WIDTH);
            send_tvalid <= 1'b1;
            send_tkeep <= saved_tkeep[matcher_idx];
            send_tuser <= saved_tuser[matcher_idx];
            send_tid <= saved_tid[matcher_idx];
            send_tdest <= saved_tdest[matcher_idx];
            if (!passthrough_d)
                send_tlast <= 1'b1;
        end
        // PASSTHROUGH: nothing
        default: begin /* nothing */ end
    endcase

    if (!rstn) begin
        matched_ruleset_id_q <= {$clog2(UMATCH_RULESETS){1'b0}};
        matched_ruleset_eom_q <= 1'b0;

        slmp_msg_id_q <= {MSG_ID_WIDTH{1'b0}};
    end
end
assign send_tready = matched_q ? m_axis_pspin_rx_tready : m_axis_nic_rx_tready;

// passthrough logic
wire do_pass = state_q == PASSTHROUGH;
assign send_comb_tready = !do_pass ? buffered_tready : send_tready;
assign send_comb_tdata = do_pass ? buffered_tdata : send_tdata;
assign send_comb_tkeep = do_pass ? buffered_tkeep : send_tkeep;
assign send_comb_tvalid = do_pass ? buffered_tvalid : send_tvalid;
assign send_comb_tlast = do_pass ? buffered_tlast : send_tlast;
assign send_comb_tid = do_pass ? buffered_tid : send_tid;
assign send_comb_tdest = do_pass ? buffered_tdest : send_tdest;
assign send_comb_tuser = do_pass ? buffered_tuser : send_tuser;

assign m_axis_nic_rx_tdata = !matched_q ? send_comb_tdata : {AXIS_IF_DATA_WIDTH{1'b0}};
assign m_axis_nic_rx_tkeep = !matched_q ? send_comb_tkeep : {AXIS_IF_KEEP_WIDTH{1'b0}};
assign m_axis_nic_rx_tvalid = !matched_q ? send_comb_tvalid : 1'b0;
assign m_axis_nic_rx_tlast = !matched_q ? send_comb_tlast : 1'b0;
assign m_axis_nic_rx_tid = !matched_q ? send_comb_tid : {AXIS_IF_RX_ID_WIDTH{1'b0}};
assign m_axis_nic_rx_tdest = !matched_q ? send_comb_tdest : {AXIS_IF_RX_DEST_WIDTH{1'b0}};
assign m_axis_nic_rx_tuser = !matched_q ? send_comb_tuser : {AXIS_IF_RX_USER_WIDTH{1'b0}};

assign m_axis_pspin_rx_tdata = matched_q ? send_comb_tdata : {AXIS_IF_DATA_WIDTH{1'b0}};
assign m_axis_pspin_rx_tkeep = matched_q ? send_comb_tkeep : {AXIS_IF_KEEP_WIDTH{1'b0}};
assign m_axis_pspin_rx_tvalid = matched_q ? send_comb_tvalid : 1'b0;
assign m_axis_pspin_rx_tlast = matched_q ? send_comb_tlast : 1'b0;
assign m_axis_pspin_rx_tid = matched_q ? send_comb_tid : {AXIS_IF_RX_ID_WIDTH{1'b0}};
assign m_axis_pspin_rx_tdest = matched_q ? send_comb_tdest : {AXIS_IF_RX_DEST_WIDTH{1'b0}};
assign m_axis_pspin_rx_tuser = matched_q ? send_comb_tuser : {AXIS_IF_RX_USER_WIDTH{1'b0}};

if (BUFFER_FIFO_DEPTH != 0) begin
// FIFO to buffer input packets
axis_fifo #(
    .DEPTH(BUFFER_FIFO_DEPTH),
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
) i_fifo_rx (
    .clk             (clk),
    .rst             (!rstn),

    .s_axis_tdata    (s_axis_nic_rx_tdata),
    .s_axis_tkeep    (s_axis_nic_rx_tkeep),
    .s_axis_tvalid   (s_axis_nic_rx_tvalid),
    .s_axis_tready   (s_axis_nic_rx_tready),
    .s_axis_tlast    (s_axis_nic_rx_tlast),
    .s_axis_tid      (s_axis_nic_rx_tid),
    .s_axis_tdest    (s_axis_nic_rx_tdest),
    .s_axis_tuser    (s_axis_nic_rx_tuser),

    .m_axis_tdata    (buffered_tdata),
    .m_axis_tkeep    (buffered_tkeep),
    .m_axis_tvalid   (buffered_tvalid),
    .m_axis_tready   (send_comb_tready),
    .m_axis_tlast    (buffered_tlast),
    .m_axis_tid      (buffered_tid),
    .m_axis_tdest    (buffered_tdest),
    .m_axis_tuser    (buffered_tuser),

    .status_overflow    (buffered_overflow),
    .status_bad_frame   (buffered_bad_frame),
    .status_good_frame  (buffered_good_frame)
);
end else begin

assign buffered_tdata   = s_axis_nic_rx_tdata;
assign buffered_tkeep   = s_axis_nic_rx_tkeep;
assign buffered_tvalid  = s_axis_nic_rx_tvalid;
assign s_axis_nic_rx_tready = send_comb_tready;
assign buffered_tlast   = s_axis_nic_rx_tlast;
assign buffered_tid     = s_axis_nic_rx_tid;
assign buffered_tdest   = s_axis_nic_rx_tdest;
assign buffered_tuser   = s_axis_nic_rx_tuser;

end

endmodule