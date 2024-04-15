// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/*
 * periph_demux.sv
 * Davide Rossi <davide.rossi@unibo.it>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 * Igor Loi <igor.loi@unibo.it>
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 */

module periph_demux
#(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int BE_WIDTH = DATA_WIDTH/8,
  parameter bit DEM_PER_BEFORE_TCDM_TS = 1'b0
)
(
  input  logic                    clk,
  input  logic                    rst_ni,

  // CORE SIDE
  input  logic                    data_req_i,
  input  logic [ADDR_WIDTH - 1:0] data_add_i,
  input  logic                    data_wen_i,
  input  logic [DATA_WIDTH - 1:0] data_wdata_i,
  input  logic [BE_WIDTH - 1:0]   data_be_i,
  output logic                    data_gnt_o,

  output logic                    data_r_valid_o, // Data Response Valid (For LOAD/STORE commands)
  output logic [DATA_WIDTH - 1:0] data_r_rdata_o, // Data Response DATA (For LOAD commands)
  output logic                    data_r_opc_o,   // Data Response Error

  // Low Latency log interconnect SIDE
  output logic                    data_req_o_MH,
  output logic [ADDR_WIDTH - 1:0] data_add_o_MH,
  output logic                    data_wen_o_MH,
  output logic [DATA_WIDTH - 1:0] data_wdata_o_MH,
  output logic [BE_WIDTH - 1:0]   data_be_o_MH,
  input  logic                    data_gnt_i_MH,
  input  logic                    data_r_valid_i_MH,
  input  logic [DATA_WIDTH - 1:0] data_r_rdata_i_MH,
  input  logic                    data_r_opc_i_MH,

  //low latency event unit access, sleep_req,clear buffer_req
  output logic                    data_req_o_EU,
  output logic [ADDR_WIDTH - 1:0] data_add_o_EU,
  output logic                    data_wen_o_EU,
  output logic [DATA_WIDTH - 1:0] data_wdata_o_EU,
  output logic [BE_WIDTH - 1:0]   data_be_o_EU,
  input  logic                    data_gnt_i_EU,
  input  logic                    data_r_valid_i_EU,
  input  logic [DATA_WIDTH - 1:0] data_r_rdata_i_EU,
  input  logic                    data_r_opc_i_EU,

  // my FIFO
  output logic                    data_req_o_MYF,
  output logic [ADDR_WIDTH - 1:0] data_add_o_MYF,
  output logic                    data_wen_o_MYF,
  output logic [DATA_WIDTH - 1:0] data_wdata_o_MYF,
  output logic [BE_WIDTH - 1:0]   data_be_o_MYF,
  input  logic                    data_gnt_i_MYF,
  input  logic                    data_r_valid_i_MYF,
  input  logic [DATA_WIDTH - 1:0] data_r_rdata_i_MYF,
  input  logic                    data_r_opc_i_MYF,

  // neighbor FIFO
  output logic                    data_req_o_NBF,
  output logic [ADDR_WIDTH - 1:0] data_add_o_NBF,
  output logic                    data_wen_o_NBF,
  output logic [DATA_WIDTH - 1:0] data_wdata_o_NBF,
  output logic [BE_WIDTH - 1:0]   data_be_o_NBF,
  input  logic                    data_gnt_i_NBF,
  input  logic                    data_r_valid_i_NBF,
  input  logic [DATA_WIDTH - 1:0] data_r_rdata_i_NBF,
  input  logic                    data_r_opc_i_NBF,

  // HPU driver
  output logic                    data_req_o_HDRV,
  output logic [ADDR_WIDTH - 1:0] data_add_o_HDRV,
  output logic                    data_wen_o_HDRV,
  output logic [DATA_WIDTH - 1:0] data_wdata_o_HDRV,
  output logic [BE_WIDTH - 1:0]   data_be_o_HDRV,
  input  logic                    data_gnt_i_HDRV,
  input  logic                    data_r_valid_i_HDRV,
  input  logic [DATA_WIDTH - 1:0] data_r_rdata_i_HDRV,
  input  logic                    data_r_opc_i_HDRV
);

  enum logic [2:0] {MH, EU, MYF, NBF, HDRV, UNMAPPED } request_destination;

  always_ff @(posedge clk, negedge rst_ni) begin : _UPDATE_RESPONSE_DESTINATION_
    if(rst_ni == 1'b0) begin
      request_destination <= MH;
    end
    else begin
      if (data_req_i) begin
        if (DEM_PER_BEFORE_TCDM_TS) begin
          case(data_add_i[13:10])
            4'b1111 : begin : _DPBTT_EVENT_UNIT_REGS
              request_destination <= EU;
            end
            4'b1110 : begin : _DPBTT_MCHAN_REGISTERS_
              request_destination <= MH;
            end
            default: begin : _DPBTT_UNMAPPED_REGION_
              request_destination <= UNMAPPED;
            end
          endcase // data_add_i[13:10]
        end else begin
          if( (data_add_i[19:14] == 6'b000001 ) ) begin // this means 0x1020_4000 to 1020_7FFF
            case(data_add_i[13:10])
              0 : begin : _EVENT_UNIT_REGS
                request_destination <= EU;
              end
              1 : begin : _MCHAN_REGISTERS_
                request_destination <= MH;
              end
              2 : begin
                request_destination <= MYF;
              end
              3 : begin
                request_destination <= NBF;
              end
              4 : begin
                request_destination <= HDRV;
              end
              default : begin : _UNMAPPED_REGION_
                request_destination <= UNMAPPED;
              end
            endcase // data_add_i[10:13]
          end
        end
      end
    end
  end

  assign data_add_o_MH    = data_add_i;
  assign data_wen_o_MH    = data_wen_i;
  assign data_wdata_o_MH  = data_wdata_i;
  assign data_be_o_MH     = data_be_i;

  assign data_add_o_EU    = data_add_i;
  assign data_wen_o_EU    = data_wen_i;
  assign data_wdata_o_EU  = data_wdata_i;
  assign data_be_o_EU     = data_be_i;

  assign data_add_o_MYF   = data_add_i;
  assign data_wen_o_MYF   = data_wen_i;
  assign data_wdata_o_MYF = data_wdata_i;
  assign data_be_o_MYF    = data_be_i;

  assign data_add_o_NBF   = data_add_i;
  assign data_wen_o_NBF   = data_wen_i;
  assign data_wdata_o_NBF = data_wdata_i;
  assign data_be_o_NBF    = data_be_i;

  assign data_add_o_HDRV   = data_add_i;
  assign data_wen_o_HDRV   = data_wen_i;
  assign data_wdata_o_HDRV = data_wdata_i;
  assign data_be_o_HDRV    = data_be_i;

  always_comb
  begin : _HANDLE_REQ_
    data_req_o_MH     = 1'b0;
    data_req_o_EU     = 1'b0;
    data_req_o_MYF    = 1'b0;
    data_req_o_NBF    = 1'b0;
    data_req_o_HDRV  = 1'b0;
    data_gnt_o        = 1'b0;
    if (DEM_PER_BEFORE_TCDM_TS) begin
      case(data_add_i[13:10])
        4'b1111 : begin
          data_req_o_EU = data_req_i;
          data_gnt_o    = data_gnt_i_EU;
        end
        4'b1110 : begin
          data_req_o_MH = data_req_i;
          data_gnt_o    = data_gnt_i_MH;
        end
        default : begin : _TO_UNMAPPED_REGION_
          data_req_o_MH = 1'b0;
          data_req_o_EU = 1'b0;
          data_gnt_o    = 1'b0;
        end
      endcase // data_add_i[13:10]
    end else begin
      if( (data_add_i[19:14] == 6'b000001 ) ) begin // this means 0x1020_4000 to 1020_7FFF
        case(data_add_i[13:10])
          0 : begin
            data_req_o_EU     = data_req_i;
            data_gnt_o        = data_gnt_i_EU;
          end
          1 : begin
            data_req_o_MH     = data_req_i;
            data_gnt_o        = data_gnt_i_MH;
          end
          2 : begin
            data_req_o_MYF    = data_req_i;
            data_gnt_o        = data_gnt_i_MYF;
          end
          3 : begin
            data_req_o_NBF    = data_req_i;
            data_gnt_o        = data_gnt_i_NBF;
          end
          4 : begin
            data_req_o_HDRV = data_req_i;
            data_gnt_o        = data_gnt_i_HDRV;
          end
          default : begin
            data_req_o_MH     = 1'b0;
            data_req_o_EU     = 1'b0;
            data_req_o_MYF    = 1'b0;
            data_req_o_NBF    = 1'b0;
            data_req_o_HDRV   = 1'b0;
            data_gnt_o        = 1'b0;
          end
        endcase // data_add_i[10:13]
      end
    end
  end

  always_comb
  begin : _HANDLE_RESP_
    case(request_destination)
      MH : begin : _RESP_FROM_MCHAN_
        data_r_valid_o = data_r_valid_i_MH;
        data_r_rdata_o = data_r_rdata_i_MH;
        data_r_opc_o   = 1'b0;
      end
      EU : begin : _RESP_FROM_EVENT_UNIT_
        data_r_valid_o = data_r_valid_i_EU;
        data_r_rdata_o = data_r_rdata_i_EU;
        data_r_opc_o   = 1'b0;
      end
      MYF: begin
        data_r_valid_o = data_r_valid_i_MYF;
        data_r_rdata_o = data_r_rdata_i_MYF;
        data_r_opc_o   = 1'b0;
      end
      NBF: begin
        data_r_valid_o = data_r_valid_i_NBF;
        data_r_rdata_o = data_r_rdata_i_NBF;
        data_r_opc_o   = 1'b0;
      end
      HDRV: begin
        data_r_valid_o = data_r_valid_i_HDRV;
        data_r_rdata_o = data_r_rdata_i_HDRV;
        data_r_opc_o   = 1'b0;
      end
      default : begin : _UNMAPPED_RESP_
        data_r_valid_o = 1'b0;
        data_r_rdata_o = '0;
        data_r_opc_o   = 1'b0;
      end
    endcase
  end

endmodule
