// Copyright (c) 2020 ETH Zurich and University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Thomas Benz <tbenz@ethz.ch>

// register file for one pe in the pulp_cluster_frontend
// strictly 32 bit on TCDM side.

module pulp_cluster_frontend_regs #(
    parameter type transf_descr_t = logic
)(
    input  logic          clk_i,
    input  logic          rst_ni,
    // tcdm forwards channel
    input  logic          ctrl_req_i,
    input  logic          ctrl_type_i,
    input  logic [3:0]    ctrl_be_i,
    input  logic [31:0]   ctrl_add_i,
    input  logic [31:0]   ctrl_data_i,
    output logic          ctrl_gnt_o,
    // return channel
    output logic          ctrl_valid_o,
    output logic [31:0]   ctrl_data_o,
    // transfer ids
    input  logic [31:0]   next_id_i,
    input  logic [31:0]   done_id_i,
    // backend handshake
    input  logic          be_ready_i,
    output logic          be_valid_o,
    input  logic          be_busy_i,
    output transf_descr_t transf_descr_o
);

    // DMA transfer descriptor
    typedef struct packed {
        logic [31:0] num_bytes;
        logic [31:0] dst_addr;
        logic [31:0] src_addr;
    } transf_descr_regular_t;

    // data stored
    typedef union packed {
        logic [2:0][31:0]      words;
        logic [2:0][ 3:0][7:0] bytes;
        transf_descr_regular_t transfer;
    } dma_data_store_t;

    // have 8 registers per PE
    logic [5:0] reg_addr;
    // 6 registers are r/w so we need to keep a state
    dma_data_store_t data_store_d, data_store_q;
    logic [2:0]      conf_store_d, conf_store_q;
    // data is delayed one cycle
    logic [31:0] rdata_d, rdata_q;
    logic        valid_d, valid_q;

    // assign address to register address
    assign reg_addr = ctrl_add_i[5:0];

    // address decode
    always_comb begin : proc_address_decode

        // defaults
        ctrl_gnt_o   = 1'b0;
        rdata_d      =   '0;
        valid_d      = 1'b0;
        be_valid_o   = 1'b0;
        data_store_d = data_store_q;
        conf_store_d = conf_store_q;

        // if we have access
        if (ctrl_req_i) begin

            // only grant if a request is here
            ctrl_gnt_o = 1'b1;

            // address decoding
            case(reg_addr)
                // source address (low)
                6'h00 : begin
                    valid_d = 1'b1;
                    if (ctrl_type_i) begin // read
                        rdata_d = data_store_q.words[0];
                    end else begin // write
                        for (int i = 0; i < 4; i++) begin
                            if (ctrl_be_i[i])
                                data_store_d.bytes[0][i] = ctrl_data_i[8 * i +: 8];
                        end
                    end
                end
                //// source address (high)
                //6'h04 : begin
                //    valid_d = 1'b1;
                //    if (ctrl_type_i) begin // read
                //        rdata_d = data_store_q.words[1];
                //    end else begin // write
                //        for (int i = 0; i < 4; i++) begin
                //            if (ctrl_be_i[i])
                //                data_store_d.bytes[1][i] = ctrl_data_i[8 * i +: 8];
                //        end
                //    end
                //end
                // destination address (low)
                6'h08 : begin
                    valid_d = 1'b1;
                    if (ctrl_type_i) begin // read
                        rdata_d = data_store_q.words[1];
                    end else begin // write
                        for (int i = 0; i < 4; i++) begin
                            if (ctrl_be_i[i])
                                data_store_d.bytes[1][i] = ctrl_data_i[8 * i +: 8];
                        end
                    end
                end
                //// destination address (high)
                //6'h0c : begin
                //    valid_d = 1'b1;
                //    if (ctrl_type_i) begin // read
                //        rdata_d = data_store_q.words[3];
                //    end else begin // write
                //        for (int i = 0; i < 4; i++) begin
                //            if (ctrl_be_i[i])
                //                data_store_d.bytes[3][i] = ctrl_data_i[8 * i +: 8];
                //        end
                //    end
                //end
                // num bytes
                6'h10 : begin
                    valid_d = 1'b1;
                    if (ctrl_type_i) begin // read
                        rdata_d = data_store_q.words[2];
                    end else begin // write
                        for (int i = 0; i < 4; i++) begin
                            if (ctrl_be_i[i])
                                data_store_d.bytes[2][i] = ctrl_data_i[8 * i +: 8];
                        end
                    end
                end
                // next_id
                6'h18 : begin
                    valid_d    = be_ready_i;
                    if (ctrl_type_i) begin // read
                        ctrl_gnt_o = be_ready_i;
                        rdata_d    = next_id_i;
                        be_valid_o = 1'b1;
                    end
                end
                // completed id
                6'h20 : begin
                    valid_d = 1'b1;
                    if (ctrl_type_i) begin // read
                        rdata_d = done_id_i;
                    end
                end
                // status / conf
                6'h28 : begin
                    valid_d = 1'b1;
                    if (ctrl_type_i) begin // read
                        rdata_d = {15'h0000, be_busy_i, 13'h0000, conf_store_q};
                    end else begin // write
                        conf_store_d = ctrl_data_i[2:0];
                    end
                end
                // default case
                default : begin
                    rdata_d = '0;
                    valid_d = 1'b1;
                end
            endcase
        end
    end

    // data store
    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_data_store
        if(~rst_ni) begin
            data_store_q <= '0;
            conf_store_q <= 3'b001;
            rdata_q      <= '0;
            valid_q      <= '0;
        end else begin
            data_store_q <= data_store_d;
            conf_store_q <= conf_store_d;
            rdata_q      <= rdata_d;
            valid_q      <= valid_d;
        end
    end

    assign ctrl_valid_o = valid_q;
    assign ctrl_data_o  = rdata_q;

    assign transf_descr_o.num_bytes = data_store_q.transfer.num_bytes;
    assign transf_descr_o.dst_addr  = data_store_q.transfer.dst_addr;
    assign transf_descr_o.src_addr  = data_store_q.transfer.src_addr;
    assign transf_descr_o.decouple  = conf_store_q[0];
    assign transf_descr_o.deburst   = conf_store_q[1];
    assign transf_descr_o.serialize = conf_store_q[2];

endmodule : pulp_cluster_frontend_regs
