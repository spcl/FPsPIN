// Copyright (c) 2020 ETH Zurich and University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module soc_ctrl_regs #(
  parameter int unsigned  N_CORES     = 0,
  parameter int unsigned  N_CLUSTERS  = 0,
  parameter int unsigned  ADDR_WIDTH  = 0,
  parameter int unsigned  DATA_WIDTH  = 0
) (
  input  logic  clk_i,
  input  logic  rst_ni,
  APB_BUS.Slave apb
);

  localparam int unsigned N_SLV = 5;

  APB_BUS #(
    .APB_ADDR_WIDTH (ADDR_WIDTH),
    .APB_DATA_WIDTH (DATA_WIDTH)
  ) apb_bus[N_SLV-1:0] ();

  apb_bus_wrap #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .N_SLV      (N_SLV),
    .ADDR_BEGIN ({32'h0000_0090, 32'h0000_0080, 32'h0000_0014, 32'h0000_0010, 32'h0000_0000}),
    .ADDR_END   ({32'h0000_0FFF, 32'h0000_008F, 32'h0000_007F, 32'h0000_0013, 32'h0000_000F})
  ) i_apb_bus (
    .inp  (apb),
    .oup  (apb_bus)
  );

  apb_ro_regs #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .N_REGS     (4)
  ) i_zero_0 (
    .apb    (apb_bus[0]),
    .reg_i  ('0)
  );

  logic [DATA_WIDTH-1:0] info_reg;
  assign info_reg = {N_CORES, N_CLUSTERS};
  apb_ro_regs #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .N_REGS     (1)
  ) i_info (
    .apb    (apb_bus[1]),
    .reg_i  (info_reg)
  );

  apb_ro_regs #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .N_REGS     (27)
  ) i_zero_1 (
    .apb    (apb_bus[2]),
    .reg_i  ('0)
  );

  apb_rw_regs #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .N_REGS     (4) // TODO: Why 4 and not the actual number of cores? Are these regs even needed?
  ) i_core_res (
    .clk_i,
    .rst_ni,
    .apb    (apb_bus[3]),
    .init_i ('0),
    .q_o    ()
  );

  apb_ro_regs #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .N_REGS     (988)
  ) i_zero_2 (
    .apb    (apb_bus[4]),
    /* verilator lint_off WIDTHCONCAT */
    .reg_i  ('0)
    /* verilator lint_on WIDTHCONCAT */
  );

endmodule
