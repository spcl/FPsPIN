// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Engineer:       Sven Stucki - svstucki@student.ethz.ch                     //
//                                                                            //
// Additional contributions by:                                               //
//                 Andreas Traber - atraber@iis.ee.ethz.ch                    //
//                 Michael Gautschi - gautschi@iis.ee.ethz.ch                 //
//                 Davide Schiavone - pschiavo@iis.ee.ethz.ch                 //
//                 Andrea Bettati - andrea.bettati@studenti.unipr.it          //
//                                                                            //
// Design Name:    Control and Status Registers                               //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Control and Status Registers (CSRs) loosely following the  //
//                 RiscV draft priviledged instruction set spec (v1.9)        //
//                 Added Floating point support                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

import riscv_defines::*;

`ifndef PULP_FPGA_EMUL
 `ifdef SYNTHESIS
  `define ASIC_SYNTHESIS
 `endif
`endif

module riscv_cs_registers
#(
  parameter N_HWLP           = 2,
  parameter N_HWLP_BITS      = $clog2(N_HWLP),
  parameter APU              = 0,
  parameter A_EXTENSION      = 0,
  parameter FPU              = 0,
  parameter PULP_SECURE      = 0,
  parameter USE_PMP          = 0,
  parameter N_PMP_ENTRIES    = 16,
  parameter NUM_MHPMCOUNTERS = 1,
  parameter PULP_HWLP        = 0,
  parameter DEBUG_TRIGGER_EN = 1
)
(
  // Clock and Reset
  input  logic            clk,
  input  logic            rst_n,

  // Hart ID
  input  logic [31:0]     hart_id_i,
  output logic [23:0]     mtvec_o,
  output logic [23:0]     utvec_o,
  output logic  [1:0]     mtvec_mode_o,
  output logic  [1:0]     utvec_mode_o,

  // Used for boot address
  input  logic [30:0]     boot_addr_i,

  // Interface to registers (SRAM like)
  input  logic                    csr_access_i,
  input  riscv_defines::csr_num_e csr_addr_i,
  input  logic [31:0]             csr_wdata_i,
  input  logic  [1:0]             csr_op_i,
  output logic [31:0]             csr_rdata_o,

  output logic [2:0]         frm_o,
  output logic [C_PC-1:0]    fprec_o,
  input  logic [C_FFLAG-1:0] fflags_i,
  input  logic               fflags_we_i,

  // Interrupts
  // IRQ lines from int_controller
  input  logic            irq_software_i,
  input  logic            irq_timer_i,
  input  logic            irq_external_i,
  input  logic [47:0]     irq_fast_i,

  output logic            m_irq_enable_o,
  output logic            u_irq_enable_o,
  // IRQ req to ID/controller
  output logic            irq_pending_o,    //used to wake up the WFI and to signal interrupts to controller
  output logic [5:0]      irq_id_o,

  //csr_irq_sec_i is always 0 if PULP_SECURE is zero
  input  logic            csr_irq_sec_i,
  output logic            sec_lvl_o,
  output logic [31:0]     mepc_o,
  output logic [31:0]     uepc_o,

  // debug
  input  logic            debug_mode_i,
  input  logic  [2:0]     debug_cause_i,
  input  logic            debug_csr_save_i,
  output logic [31:0]     depc_o,
  output logic            debug_single_step_o,
  output logic            debug_ebreakm_o,
  output logic            debug_ebreaku_o,
  output logic            trigger_match_o,


  output logic  [N_PMP_ENTRIES-1:0] [31:0] pmp_addr_o,
  output logic  [N_PMP_ENTRIES-1:0] [7:0]  pmp_cfg_o,

  output PrivLvl_t        priv_lvl_o,

  input  logic [31:0]     pc_if_i,
  input  logic [31:0]     pc_id_i,
  input  logic [31:0]     pc_ex_i,

  input  logic            csr_save_if_i,
  input  logic            csr_save_id_i,
  input  logic            csr_save_ex_i,

  input  logic            csr_restore_mret_i,
  input  logic            csr_restore_uret_i,

  input  logic            csr_restore_dret_i,
  //coming from controller
  input  logic [6:0]      csr_cause_i,
  //coming from controller
  input  logic            csr_save_cause_i,
  // Hardware loops
  input  logic [N_HWLP-1:0] [31:0] hwlp_start_i,
  input  logic [N_HWLP-1:0] [31:0] hwlp_end_i,
  input  logic [N_HWLP-1:0] [31:0] hwlp_cnt_i,

  output logic [31:0]              hwlp_data_o,
  output logic [N_HWLP_BITS-1:0]   hwlp_regid_o,
  output logic [2:0]               hwlp_we_o,

  // Stack Protection
  output logic [31:0]     stack_base_o,
  output logic [31:0]     stack_limit_o,

  // Performance Counters
  input  logic                 id_valid_i,        // ID stage is done
  input  logic                 is_compressed_i,   // compressed instruction in ID
  input  logic                 is_decoding_i,     // controller is in DECODE state

  input  logic                 imiss_i,           // instruction fetch
  input  logic                 pc_set_i,          // pc was set to a new value
  input  logic                 jump_i,            // jump instruction seen   (j, jr, jal, jalr)
  input  logic                 branch_i,          // branch instruction seen (bf, bnf)
  input  logic                 branch_taken_i,    // branch was taken
  input  logic                 ld_stall_i,        // load use hazard
  input  logic                 jr_stall_i,        // jump register use hazard
  input  logic                 pipeline_stall_i,  // extra cycles from elw

  input  logic                 apu_typeconflict_i,
  input  logic                 apu_contention_i,
  input  logic                 apu_dep_i,
  input  logic                 apu_wb_i,

  input  logic                 mem_load_i,        // load from memory in this cycle
  input  logic                 mem_store_i        // store to memory in this cycle

);

  localparam NUM_HPM_EVENTS  =   16;

  localparam MTVEC_MODE      = 2'b01;

  localparam MAX_N_PMP_ENTRIES = 16;
  localparam MAX_N_PMP_CFG     =  4;
  localparam N_PMP_CFG         = N_PMP_ENTRIES % 4 == 0 ? N_PMP_ENTRIES/4 : N_PMP_ENTRIES/4 + 1;


  `define MSTATUS_UIE_BITS        0
  `define MSTATUS_SIE_BITS        1
  `define MSTATUS_MIE_BITS        3
  `define MSTATUS_UPIE_BITS       4
  `define MSTATUS_SPIE_BITS       5
  `define MSTATUS_MPIE_BITS       7
  `define MSTATUS_SPP_BITS        8
  `define MSTATUS_MPP_BITS    12:11
  `define MSTATUS_MPRV_BITS      17

  // misa
  localparam logic [1:0] MXL = 2'd1; // M-XLEN: XLEN in M-Mode for RV32
  localparam logic [31:0] MISA_VALUE =
      (32'(A_EXTENSION) <<  0)  // A - Atomic Instructions extension
    | (1                <<  2)  // C - Compressed extension
    | (0                <<  3)  // D - Double precision floating-point extension
    | (0                <<  4)  // E - RV32E base ISA
    | (32'(FPU)         <<  5)  // F - Single precision floating-point extension
    | (1                <<  8)  // I - RV32I/64I/128I base ISA
    | (1                << 12)  // M - Integer Multiply/Divide extension
    | (0                << 13)  // N - User level interrupts supported
    | (0                << 18)  // S - Supervisor mode implemented
    | (32'(PULP_SECURE) << 20)  // U - User mode implemented
    | (1                << 23)  // X - Non-standard extensions present
    | (32'(MXL)         << 30); // M-XLEN

  typedef struct packed {
    logic uie;
    // logic sie;      - unimplemented, hardwired to '0
    // logic hie;      - unimplemented, hardwired to '0
    logic mie;
    logic upie;
    // logic spie;     - unimplemented, hardwired to '0
    // logic hpie;     - unimplemented, hardwired to '0
    logic mpie;
    // logic spp;      - unimplemented, hardwired to '0
    // logic[1:0] hpp; - unimplemented, hardwired to '0
    PrivLvl_t mpp;
    logic mprv;
  } Status_t;

  typedef struct packed{
      logic [31:28] xdebugver;
      logic [27:16] zero2;
      logic         ebreakm;
      logic         zero1;
      logic         ebreaks;
      logic         ebreaku;
      logic         stepie;
      logic         stopcount;
      logic         stoptime;
      logic [8:6]   cause;
      logic         zero0;
      logic         mprven;
      logic         nmip;
      logic         step;
      PrivLvl_t     prv;
  } Dcsr_t;

`ifndef SYNTHESIS
  initial
  begin
    $display("[CORE] Core settings: PULP_SECURE = %d, N_PMP_ENTRIES = %d, N_PMP_CFG %d",PULP_SECURE, N_PMP_ENTRIES, N_PMP_CFG);
  end
`endif

  typedef struct packed {
   logic  [MAX_N_PMP_ENTRIES-1:0] [31:0] pmpaddr;
   //logic  [MAX_N_PMP_CFG-1:0]     [31:0] pmpcfg_packed;
   logic  [MAX_N_PMP_ENTRIES-1:0] [ 7:0] pmpcfg;
  } Pmp_t;

  typedef logic [MAX_N_PMP_CFG-1:0][31:0] pmpcfg_packed_t;

  // CSR update logic
  logic [31:0] csr_wdata_int;
  logic [31:0] csr_rdata_int;
  logic        csr_we_int;
  logic [C_RM-1:0]     frm_q, frm_n;
  logic [C_FFLAG-1:0]  fflags_q, fflags_n;
  logic [C_PC-1:0]     fprec_q, fprec_n;

  // Interrupt control signals
  logic [31:0] mepc_q, mepc_n;
  logic [31:0] uepc_q, uepc_n;
  // Trigger
  logic [31:0] tmatch_control_rdata;
  logic [31:0] tmatch_value_rdata;
  // Debug
  Dcsr_t       dcsr_q, dcsr_n;
  logic [31:0] depc_q, depc_n;
  logic [31:0] dscratch0_q, dscratch0_n;
  logic [31:0] dscratch1_q, dscratch1_n;
  logic [31:0] mscratch_q, mscratch_n;

  logic [31:0] exception_pc;
  Status_t mstatus_q, mstatus_n;
  logic [ 6:0] mcause_q, mcause_n;
  logic [ 6:0] ucause_q, ucause_n;
  logic [31:0] stack_base_q, stack_base_n,
               stack_size_q, stack_size_n;
  //not implemented yet
  logic [23:0] mtvec_n, mtvec_q;
  logic [23:0] utvec_n, utvec_q;
  logic [ 1:0] mtvec_mode_n, mtvec_mode_q;
  logic [ 1:0] utvec_mode_n, utvec_mode_q;

  Interrupts_t mip;
  logic [31:0] mip1;
  Interrupts_t mie_q, mie_n;
  logic [31:0] mie1_q, mie1_n;
  //machine enabled interrupt pending
  Interrupts_t menip;
  logic [31:0] menip1;

  logic is_irq;
  PrivLvl_t priv_lvl_n, priv_lvl_q;
  
  Pmp_t pmp_reg_q;
  Pmp_t pmp_reg_n;
  pmpcfg_packed_t pmpcfg_packed_q;
  pmpcfg_packed_t pmpcfg_packed_n;

  //clock gating for pmp regs
  logic [MAX_N_PMP_ENTRIES-1:0] pmpaddr_we;
  logic [MAX_N_PMP_ENTRIES-1:0] pmpcfg_we;

  // Performance Counter Signals
  logic                      id_valid_q;

  
  // performance counters
  logic [31:0] [63:0]        mhpmcounter_q;   
  logic [31:0] [63:0]        mhpmcounter_n;

  // event enable
  logic [31:0] [31:0]        mhpmevent_q;
  logic [31:0] [31:0]        mhpmevent_n;     

  // performance counter enable
  logic [31:0]               mcountinhibit_q;
  logic [31:0]               mcountinhibit_n;

  logic [NUM_HPM_EVENTS-1:0] hpm_events;                       // events for performance counters

  Interrupts_t                   irq_req;
  logic [31:0]                   irq_req1;

  assign is_irq = csr_cause_i[6];

  assign irq_req.irq_software = irq_software_i;
  assign irq_req.irq_timer    = irq_timer_i;
  assign irq_req.irq_external = irq_external_i;
  assign irq_req.irq_fast     = irq_fast_i[15:0];
  assign irq_req1             = irq_fast_i[47:16];

  // mip CSR is purely combintational
  // must be able to re-enable the clock upon WFI
  assign mip.irq_software   = irq_req.irq_software;
  assign mip.irq_timer      = irq_req.irq_timer;
  assign mip.irq_external   = irq_req.irq_external;
  assign mip.irq_fast       = irq_req.irq_fast;
  assign mip1               = irq_req1;

  // menip signal the controller
  assign menip.irq_software = irq_req.irq_software & mie_q.irq_software;
  assign menip.irq_timer    = irq_req.irq_timer    & mie_q.irq_timer;
  assign menip.irq_external = irq_req.irq_external & mie_q.irq_external;
  assign menip.irq_fast     = irq_req.irq_fast     & mie_q.irq_fast;
  assign menip1             = irq_req1             & mie1_q;



  ////////////////////////////////////////////
  //   ____ ____  ____    ____              //
  //  / ___/ ___||  _ \  |  _ \ ___  __ _   //
  // | |   \___ \| |_) | | |_) / _ \/ _` |  //
  // | |___ ___) |  _ <  |  _ <  __/ (_| |  //
  //  \____|____/|_| \_\ |_| \_\___|\__, |  //
  //                                |___/   //
  ////////////////////////////////////////////

  // NOTE!!!: Any new CSR register added in this file must also be
  //   added to the valid CSR register list riscv_decoder.v

   genvar j;


if(PULP_SECURE==1) begin
  // read logic
  always_comb
  begin
    casex (csr_addr_i)
      // fcsr: Floating-Point Control and Status Register (frm + fflags).
      CSR_FFLAGS : csr_rdata_int = (FPU == 1) ? {27'b0, fflags_q}        : '0;
      CSR_FRM    : csr_rdata_int = (FPU == 1) ? {29'b0, frm_q}           : '0;
      CSR_FCSR   : csr_rdata_int = (FPU == 1) ? {24'b0, frm_q, fflags_q} : '0;
      FPREC      : csr_rdata_int = (FPU == 1) ? {27'b0, fprec_q}         : '0; // Optional precision control for FP DIV/SQRT Unit

      // mstatus
      CSR_MSTATUS: csr_rdata_int = {
                                  14'b0,
                                  mstatus_q.mprv,
                                  4'b0,
                                  mstatus_q.mpp,
                                  3'b0,
                                  mstatus_q.mpie,
                                  2'h0,
                                  mstatus_q.upie,
                                  mstatus_q.mie,
                                  2'h0,
                                  mstatus_q.uie
                                };

      // misa: machine isa register
      CSR_MISA: csr_rdata_int = MISA_VALUE;

      // mie: machine interrupt enable
      CSR_MIE: begin
        csr_rdata_int                                     = '0;
        csr_rdata_int[CSR_MSIX_BIT]                       = mie_q.irq_software;
        csr_rdata_int[CSR_MTIX_BIT]                       = mie_q.irq_timer;
        csr_rdata_int[CSR_MEIX_BIT]                       = mie_q.irq_external;
        csr_rdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW] = mie_q.irq_fast;
      end

      // mie1: machine interrupt enable for fast interrupt extension (irq_fast_i[47:16])
      CSR_MIE1: csr_rdata_int = mie1_q;

      // mtvec: machine trap-handler base address
      CSR_MTVEC: csr_rdata_int = {mtvec_q, 6'h0, mtvec_mode_q};
      // mscratch: machine scratch
      CSR_MSCRATCH: csr_rdata_int = mscratch_q;
      // mepc: exception program counter
      CSR_MEPC: csr_rdata_int = mepc_q;
      // mcause: exception cause
      CSR_MCAUSE: csr_rdata_int = {mcause_q[6], 25'b0, mcause_q[5:0]};
      // mip: interrupt pending
      CSR_MIP: begin
        csr_rdata_int                                     = '0;
        csr_rdata_int[CSR_MSIX_BIT]                       = mip.irq_software;
        csr_rdata_int[CSR_MTIX_BIT]                       = mip.irq_timer;
        csr_rdata_int[CSR_MEIX_BIT]                       = mip.irq_external;
        csr_rdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW] = mip.irq_fast;
      end

      // mip1: machine interrupt pending for fast interrupt extension (irq_fast_i[47:16])
      CSR_MIP1: csr_rdata_int = mip1;

      // mhartid: unique hardware thread id
      CSR_MHARTID: csr_rdata_int = hart_id_i;

      // unimplemented, read 0 CSRs
      CSR_MVENDORID,
        CSR_MARCHID,
        CSR_MIMPID,
        CSR_MTVAL,
        CSR_MCOUNTEREN :
          csr_rdata_int = 'b0;

      CSR_TSELECT,
        CSR_TDATA3,
        CSR_MCONTEXT,
        CSR_SCONTEXT:
               csr_rdata_int = 'b0; // Always read 0
      CSR_TDATA1:
               csr_rdata_int = tmatch_control_rdata;
      CSR_TDATA2:
               csr_rdata_int = tmatch_value_rdata;

      CSR_DCSR:
               csr_rdata_int = dcsr_q;//
      CSR_DPC:
               csr_rdata_int = depc_q;
      CSR_DSCRATCH0:
               csr_rdata_int = dscratch0_q;//
      CSR_DSCRATCH1:
               csr_rdata_int = dscratch1_q;//

      // Hardware Performance Monitor
      CSR_MCYCLE,
      CSR_MINSTRET,
      CSR_MHPMCOUNTER3,
      CSR_MHPMCOUNTER4,  CSR_MHPMCOUNTER5,  CSR_MHPMCOUNTER6,  CSR_MHPMCOUNTER7,
      CSR_MHPMCOUNTER8,  CSR_MHPMCOUNTER9,  CSR_MHPMCOUNTER10, CSR_MHPMCOUNTER11,
      CSR_MHPMCOUNTER12, CSR_MHPMCOUNTER13, CSR_MHPMCOUNTER14, CSR_MHPMCOUNTER15,
      CSR_MHPMCOUNTER16, CSR_MHPMCOUNTER17, CSR_MHPMCOUNTER18, CSR_MHPMCOUNTER19,
      CSR_MHPMCOUNTER20, CSR_MHPMCOUNTER21, CSR_MHPMCOUNTER22, CSR_MHPMCOUNTER23,
      CSR_MHPMCOUNTER24, CSR_MHPMCOUNTER25, CSR_MHPMCOUNTER26, CSR_MHPMCOUNTER27,
      CSR_MHPMCOUNTER28, CSR_MHPMCOUNTER29, CSR_MHPMCOUNTER30, CSR_MHPMCOUNTER31:
        csr_rdata_int = mhpmcounter_q[csr_addr_i[4:0]][31:0];

      CSR_MCYCLEH,
      CSR_MINSTRETH,
      CSR_MHPMCOUNTER3H,
      CSR_MHPMCOUNTER4H,  CSR_MHPMCOUNTER5H,  CSR_MHPMCOUNTER6H,  CSR_MHPMCOUNTER7H,
      CSR_MHPMCOUNTER8H,  CSR_MHPMCOUNTER9H,  CSR_MHPMCOUNTER10H, CSR_MHPMCOUNTER11H,
      CSR_MHPMCOUNTER12H, CSR_MHPMCOUNTER13H, CSR_MHPMCOUNTER14H, CSR_MHPMCOUNTER15H,
      CSR_MHPMCOUNTER16H, CSR_MHPMCOUNTER17H, CSR_MHPMCOUNTER18H, CSR_MHPMCOUNTER19H,
      CSR_MHPMCOUNTER20H, CSR_MHPMCOUNTER21H, CSR_MHPMCOUNTER22H, CSR_MHPMCOUNTER23H,
      CSR_MHPMCOUNTER24H, CSR_MHPMCOUNTER25H, CSR_MHPMCOUNTER26H, CSR_MHPMCOUNTER27H,
      CSR_MHPMCOUNTER28H, CSR_MHPMCOUNTER29H, CSR_MHPMCOUNTER30H, CSR_MHPMCOUNTER31H:
        csr_rdata_int = mhpmcounter_q[csr_addr_i[4:0]][63:32];

      CSR_MCOUNTINHIBIT: csr_rdata_int = mcountinhibit_q;

      CSR_MHPMEVENT3,
      CSR_MHPMEVENT4,  CSR_MHPMEVENT5,  CSR_MHPMEVENT6,  CSR_MHPMEVENT7,
      CSR_MHPMEVENT8,  CSR_MHPMEVENT9,  CSR_MHPMEVENT10, CSR_MHPMEVENT11,
      CSR_MHPMEVENT12, CSR_MHPMEVENT13, CSR_MHPMEVENT14, CSR_MHPMEVENT15,
      CSR_MHPMEVENT16, CSR_MHPMEVENT17, CSR_MHPMEVENT18, CSR_MHPMEVENT19,
      CSR_MHPMEVENT20, CSR_MHPMEVENT21, CSR_MHPMEVENT22, CSR_MHPMEVENT23,
      CSR_MHPMEVENT24, CSR_MHPMEVENT25, CSR_MHPMEVENT26, CSR_MHPMEVENT27,
      CSR_MHPMEVENT28, CSR_MHPMEVENT29, CSR_MHPMEVENT30, CSR_MHPMEVENT31:
        csr_rdata_int = mhpmevent_q[csr_addr_i[4:0]];

      // hardware loops  (not official)
      HWLoop0_START  : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_start_i[0];
      HWLoop0_END    : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_end_i[0]  ;
      HWLoop0_COUNTER: csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_cnt_i[0]  ;
      HWLoop1_START  : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_start_i[1];
      HWLoop1_END    : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_end_i[1]  ;
      HWLoop1_COUNTER: csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_cnt_i[1]  ;

      // PMP config registers
      CSR_PMPCFG0: csr_rdata_int = USE_PMP ? pmpcfg_packed_q[0] : '0;
      CSR_PMPCFG1: csr_rdata_int = USE_PMP ? pmpcfg_packed_q[1] : '0;
      CSR_PMPCFG2: csr_rdata_int = USE_PMP ? pmpcfg_packed_q[2] : '0;
      CSR_PMPCFG3: csr_rdata_int = USE_PMP ? pmpcfg_packed_q[3] : '0;

      CSR_PMPADDR_RANGE_X :
          csr_rdata_int = USE_PMP ? pmp_reg_q.pmpaddr[csr_addr_i[3:0]] : '0;

      /* USER CSR */
      // ustatus
      CSR_USTATUS: csr_rdata_int = {
                                  27'b0,
                                  mstatus_q.upie,
                                  3'h0,
                                  mstatus_q.uie
                                };
      // utvec: user trap-handler base address
      CSR_UTVEC: csr_rdata_int = {utvec_q, 6'h0, utvec_mode_q};
      // duplicated mhartid: unique hardware thread id (not official)
      UHARTID: csr_rdata_int = hart_id_i;
      // uepc: exception program counter
      CSR_UEPC: csr_rdata_int = uepc_q;
      // ucause: exception cause
      CSR_UCAUSE: csr_rdata_int = {ucause_q[6], 25'h0, ucause_q[5:0]};

      // current priv level (not official)
      PRIVLV: csr_rdata_int = {30'h0, priv_lvl_q};

      default:
        csr_rdata_int = '0;
    endcase
  end
end else begin //PULP_SECURE == 0
  // read logic
  always_comb
  begin

    case (csr_addr_i)
      // fcsr: Floating-Point Control and Status Register (frm + fflags).
      CSR_FFLAGS : csr_rdata_int = (FPU == 1) ? {27'b0, fflags_q}        : '0;
      CSR_FRM    : csr_rdata_int = (FPU == 1) ? {29'b0, frm_q}           : '0;
      CSR_FCSR   : csr_rdata_int = (FPU == 1) ? {24'b0, frm_q, fflags_q} : '0;
      FPREC      : csr_rdata_int = (FPU == 1) ? {27'b0, fprec_q}         : '0; // Optional precision control for FP DIV/SQRT Unit
      // mstatus: always M-mode, contains IE bit
      CSR_MSTATUS: csr_rdata_int = {
                                  14'b0,
                                  mstatus_q.mprv,
                                  4'b0,
                                  mstatus_q.mpp,
                                  3'b0,
                                  mstatus_q.mpie,
                                  2'h0,
                                  mstatus_q.upie,
                                  mstatus_q.mie,
                                  2'h0,
                                  mstatus_q.uie
                                };
      // misa: machine isa register
      CSR_MISA: csr_rdata_int = MISA_VALUE;
      // mie: machine interrupt enable
      CSR_MIE: begin
        csr_rdata_int                                     = '0;
        csr_rdata_int[CSR_MSIX_BIT]                       = mie_q.irq_software;
        csr_rdata_int[CSR_MTIX_BIT]                       = mie_q.irq_timer;
        csr_rdata_int[CSR_MEIX_BIT]                       = mie_q.irq_external;
        csr_rdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW] = mie_q.irq_fast;
      end

      // mie1: machine interrupt enable for fast interrupt extension (irq_fast_i[47:16])
      CSR_MIE1: csr_rdata_int = mie1_q;
      // mtvec: machine trap-handler base address
      CSR_MTVEC: csr_rdata_int = {mtvec_q, 6'h0, mtvec_mode_q};
      // mscratch: machine scratch
      CSR_MSCRATCH: csr_rdata_int = mscratch_q;
      // mepc: exception program counter
      CSR_MEPC: csr_rdata_int = mepc_q;
      // mcause: exception cause
      CSR_MCAUSE: csr_rdata_int = {mcause_q[6], 25'b0, mcause_q[5:0]};
      // mip: interrupt pending
      CSR_MIP: begin
        csr_rdata_int                                     = '0;
        csr_rdata_int[CSR_MSIX_BIT]                       = mip.irq_software;
        csr_rdata_int[CSR_MTIX_BIT]                       = mip.irq_timer;
        csr_rdata_int[CSR_MEIX_BIT]                       = mip.irq_external;
        csr_rdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW] = mip.irq_fast;
      end
      // mip1: machine interrupt pending for fast interrupt extension (irq_fast_i[47:16])
      CSR_MIP1: csr_rdata_int = mip1;
      // mhartid: unique hardware thread id
      CSR_MHARTID: csr_rdata_int = hart_id_i;

      // unimplemented, read 0 CSRs
      CSR_MVENDORID,
        CSR_MARCHID,
        CSR_MIMPID,
        CSR_MTVAL,
        CSR_MCOUNTEREN :
          csr_rdata_int = 'b0;

      CSR_TSELECT,
        CSR_TDATA3,
        CSR_MCONTEXT,
        CSR_SCONTEXT:
               csr_rdata_int = 'b0; // Always read 0
      CSR_TDATA1:
               csr_rdata_int = tmatch_control_rdata;
      CSR_TDATA2:
               csr_rdata_int = tmatch_value_rdata;

      CSR_DCSR:
               csr_rdata_int = dcsr_q;//
      CSR_DPC:
               csr_rdata_int = depc_q;
      CSR_DSCRATCH0:
               csr_rdata_int = dscratch0_q;//
      CSR_DSCRATCH1:
               csr_rdata_int = dscratch1_q;//

      // Hardware Performance Monitor
      CSR_MCYCLE,
      CSR_MINSTRET,
      CSR_MHPMCOUNTER3,
      CSR_MHPMCOUNTER4,  CSR_MHPMCOUNTER5,  CSR_MHPMCOUNTER6,  CSR_MHPMCOUNTER7,
      CSR_MHPMCOUNTER8,  CSR_MHPMCOUNTER9,  CSR_MHPMCOUNTER10, CSR_MHPMCOUNTER11,
      CSR_MHPMCOUNTER12, CSR_MHPMCOUNTER13, CSR_MHPMCOUNTER14, CSR_MHPMCOUNTER15,
      CSR_MHPMCOUNTER16, CSR_MHPMCOUNTER17, CSR_MHPMCOUNTER18, CSR_MHPMCOUNTER19,
      CSR_MHPMCOUNTER20, CSR_MHPMCOUNTER21, CSR_MHPMCOUNTER22, CSR_MHPMCOUNTER23,
      CSR_MHPMCOUNTER24, CSR_MHPMCOUNTER25, CSR_MHPMCOUNTER26, CSR_MHPMCOUNTER27,
      CSR_MHPMCOUNTER28, CSR_MHPMCOUNTER29, CSR_MHPMCOUNTER30, CSR_MHPMCOUNTER31:
        csr_rdata_int = mhpmcounter_q[csr_addr_i[4:0]][31:0];

      CSR_MCYCLEH,
      CSR_MINSTRETH,
      CSR_MHPMCOUNTER3H,
      CSR_MHPMCOUNTER4H,  CSR_MHPMCOUNTER5H,  CSR_MHPMCOUNTER6H,  CSR_MHPMCOUNTER7H,
      CSR_MHPMCOUNTER8H,  CSR_MHPMCOUNTER9H,  CSR_MHPMCOUNTER10H, CSR_MHPMCOUNTER11H,
      CSR_MHPMCOUNTER12H, CSR_MHPMCOUNTER13H, CSR_MHPMCOUNTER14H, CSR_MHPMCOUNTER15H,
      CSR_MHPMCOUNTER16H, CSR_MHPMCOUNTER17H, CSR_MHPMCOUNTER18H, CSR_MHPMCOUNTER19H,
      CSR_MHPMCOUNTER20H, CSR_MHPMCOUNTER21H, CSR_MHPMCOUNTER22H, CSR_MHPMCOUNTER23H,
      CSR_MHPMCOUNTER24H, CSR_MHPMCOUNTER25H, CSR_MHPMCOUNTER26H, CSR_MHPMCOUNTER27H,
      CSR_MHPMCOUNTER28H, CSR_MHPMCOUNTER29H, CSR_MHPMCOUNTER30H, CSR_MHPMCOUNTER31H:
        csr_rdata_int = mhpmcounter_q[csr_addr_i[4:0]][63:32];

      CSR_MCOUNTINHIBIT: csr_rdata_int = mcountinhibit_q;

      CSR_MHPMEVENT3,
      CSR_MHPMEVENT4,  CSR_MHPMEVENT5,  CSR_MHPMEVENT6,  CSR_MHPMEVENT7,
      CSR_MHPMEVENT8,  CSR_MHPMEVENT9,  CSR_MHPMEVENT10, CSR_MHPMEVENT11,
      CSR_MHPMEVENT12, CSR_MHPMEVENT13, CSR_MHPMEVENT14, CSR_MHPMEVENT15,
      CSR_MHPMEVENT16, CSR_MHPMEVENT17, CSR_MHPMEVENT18, CSR_MHPMEVENT19,
      CSR_MHPMEVENT20, CSR_MHPMEVENT21, CSR_MHPMEVENT22, CSR_MHPMEVENT23,
      CSR_MHPMEVENT24, CSR_MHPMEVENT25, CSR_MHPMEVENT26, CSR_MHPMEVENT27,
      CSR_MHPMEVENT28, CSR_MHPMEVENT29, CSR_MHPMEVENT30, CSR_MHPMEVENT31:
        csr_rdata_int = mhpmevent_q[csr_addr_i[4:0]];

      // hardware loops  (not official)
      HWLoop0_START   : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_start_i[0] ;
      HWLoop0_END     : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_end_i[0]   ;
      HWLoop0_COUNTER : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_cnt_i[0]   ;
      HWLoop1_START   : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_start_i[1] ;
      HWLoop1_END     : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_end_i[1]   ;
      HWLoop1_COUNTER : csr_rdata_int = !PULP_HWLP ? 'b0 : hwlp_cnt_i[1]   ;

      /* USER CSR */
      // dublicated mhartid: unique hardware thread id (not official)
      UHARTID: csr_rdata_int = hart_id_i;
      // current priv level (not official)
      PRIVLV: csr_rdata_int = {30'h0, priv_lvl_q};
      default:
        csr_rdata_int = '0;
    endcase
  end
end //PULP_SECURE

if(PULP_SECURE==1) begin
  // write logic
  always_comb
  begin
    fflags_n                 = fflags_q;
    frm_n                    = frm_q;
    fprec_n                  = fprec_q;
    mscratch_n               = mscratch_q;
    mepc_n                   = mepc_q;
    uepc_n                   = uepc_q;
    depc_n                   = depc_q;
    dcsr_n                   = dcsr_q;
    dscratch0_n              = dscratch0_q;
    dscratch1_n              = dscratch1_q;

    mstatus_n                = mstatus_q;
    mcause_n                 = mcause_q;
    ucause_n                 = ucause_q;
    hwlp_we_o                = '0;
    hwlp_regid_o             = '0;
    exception_pc             = pc_id_i;
    priv_lvl_n               = priv_lvl_q;
    mtvec_n                  = mtvec_q;
    utvec_n                  = utvec_q;
    mtvec_mode_n             = mtvec_mode_q;
    utvec_mode_n             = utvec_mode_q;
    pmp_reg_n.pmpaddr        = pmp_reg_q.pmpaddr;
    pmpcfg_packed_n          = pmpcfg_packed_q;
    pmpaddr_we               = '0;
    pmpcfg_we                = '0;

    mie_n                    = mie_q;
    mie1_n                   = mie1_q;

    if (FPU == 1) if (fflags_we_i) fflags_n = fflags_i | fflags_q;

    casex (csr_addr_i)
      // fcsr: Floating-Point Control and Status Register (frm, fflags, fprec).
      CSR_FFLAGS : if (csr_we_int) fflags_n = (FPU == 1) ? csr_wdata_int[C_FFLAG-1:0] : '0;
      CSR_FRM    : if (csr_we_int) frm_n    = (FPU == 1) ? csr_wdata_int[C_RM-1:0]    : '0;
      CSR_FCSR   : if (csr_we_int) begin
         fflags_n = (FPU == 1) ? csr_wdata_int[C_FFLAG-1:0]            : '0;
         frm_n    = (FPU == 1) ? csr_wdata_int[C_RM+C_FFLAG-1:C_FFLAG] : '0;
      end
      FPREC      : if (csr_we_int) fprec_n = (FPU == 1) ? csr_wdata_int[C_PC-1:0]    : '0;

      // mstatus: IE bit
      CSR_MSTATUS: if (csr_we_int) begin
        mstatus_n = '{
          uie:  csr_wdata_int[`MSTATUS_UIE_BITS],
          mie:  csr_wdata_int[`MSTATUS_MIE_BITS],
          upie: csr_wdata_int[`MSTATUS_UPIE_BITS],
          mpie: csr_wdata_int[`MSTATUS_MPIE_BITS],
          mpp:  PrivLvl_t'(csr_wdata_int[`MSTATUS_MPP_BITS]),
          mprv: csr_wdata_int[`MSTATUS_MPRV_BITS]
        };
      end
      // mie: machine interrupt enable
      CSR_MIE: if (csr_we_int) begin
        mie_n.irq_software = csr_wdata_int[CSR_MSIX_BIT];
        mie_n.irq_timer    = csr_wdata_int[CSR_MTIX_BIT];
        mie_n.irq_external = csr_wdata_int[CSR_MEIX_BIT];
        mie_n.irq_fast     = csr_wdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW];
      end
      // mie1: machine interrupt enable for fast interrupt extension (irq_fast_i[47:16])
      CSR_MIE1: if (csr_we_int) begin
        mie1_n = csr_wdata_int;
      end
      // mtvec: machine trap-handler base address
      CSR_MTVEC: if (csr_we_int) begin
        mtvec_n      = csr_wdata_int[31:8];
        mtvec_mode_n = {1'b0, csr_wdata_int[0]}; // Only direct and vectored mode are supported
      end
      // mscratch: machine scratch
      CSR_MSCRATCH: if (csr_we_int) begin
        mscratch_n = csr_wdata_int;
      end
      // mepc: exception program counter
      CSR_MEPC: if (csr_we_int) begin
        mepc_n = csr_wdata_int & ~32'b1; // force 16-bit alignment
      end
      // mcause
      CSR_MCAUSE: if (csr_we_int) mcause_n = {csr_wdata_int[31], csr_wdata_int[5:0]};

      // Debug
      CSR_DCSR:
               if (csr_we_int)
               begin
                    dcsr_n = csr_wdata_int;
                    //31:28 xdebuger = 4 -> debug is implemented
                    dcsr_n.xdebugver=4'h4;
                    //privilege level: 0-> U;1-> S; 3->M.
                    dcsr_n.prv=priv_lvl_q;
                    //currently not supported:
                    dcsr_n.nmip=1'b0;   //nmip
                    dcsr_n.mprven=1'b0; //mprven
                    dcsr_n.stopcount=1'b0;   //stopcount
                    dcsr_n.stoptime=1'b0;  //stoptime
               end
      CSR_DPC:
               if (csr_we_int)
               begin
                    depc_n = csr_wdata_int & ~32'b1; // force 16-bit alignment
               end

      CSR_DSCRATCH0:
               if (csr_we_int)
               begin
                    dscratch0_n = csr_wdata_int;
               end

      CSR_DSCRATCH1:
               if (csr_we_int)
               begin
                    dscratch1_n = csr_wdata_int;
               end

      // hardware loops
      HWLoop0_START:   if (csr_we_int) begin hwlp_we_o = 3'b001; hwlp_regid_o = 1'b0; end
      HWLoop0_END:     if (csr_we_int) begin hwlp_we_o = 3'b010; hwlp_regid_o = 1'b0; end
      HWLoop0_COUNTER: if (csr_we_int) begin hwlp_we_o = 3'b100; hwlp_regid_o = 1'b0; end
      HWLoop1_START:   if (csr_we_int) begin hwlp_we_o = 3'b001; hwlp_regid_o = 1'b1; end
      HWLoop1_END:     if (csr_we_int) begin hwlp_we_o = 3'b010; hwlp_regid_o = 1'b1; end
      HWLoop1_COUNTER: if (csr_we_int) begin hwlp_we_o = 3'b100; hwlp_regid_o = 1'b1; end


      // PMP config registers
      CSR_PMPCFG0: if (csr_we_int) begin pmpcfg_packed_n[0] = csr_wdata_int; pmpcfg_we[3:0]   = 4'b1111; end
      CSR_PMPCFG1: if (csr_we_int) begin pmpcfg_packed_n[1] = csr_wdata_int; pmpcfg_we[7:4]   = 4'b1111; end
      CSR_PMPCFG2: if (csr_we_int) begin pmpcfg_packed_n[2] = csr_wdata_int; pmpcfg_we[11:8]  = 4'b1111; end
      CSR_PMPCFG3: if (csr_we_int) begin pmpcfg_packed_n[3] = csr_wdata_int; pmpcfg_we[15:12] = 4'b1111; end

      CSR_PMPADDR_RANGE_X :
          if (csr_we_int) begin pmp_reg_n.pmpaddr[csr_addr_i[3:0]]   = csr_wdata_int; pmpaddr_we[csr_addr_i[3:0]] = 1'b1;  end


      /* USER CSR */
      // ucause: exception cause
      CSR_USTATUS: if (csr_we_int) begin
        mstatus_n = '{
          uie:  csr_wdata_int[`MSTATUS_UIE_BITS],
          mie:  mstatus_q.mie,
          upie: csr_wdata_int[`MSTATUS_UPIE_BITS],
          mpie: mstatus_q.mpie,
          mpp:  mstatus_q.mpp,
          mprv: mstatus_q.mprv
        };
      end
      // utvec: user trap-handler base address
      CSR_UTVEC: if (csr_we_int) begin
        utvec_n      = csr_wdata_int[31:8];
        utvec_mode_n = {1'b0, csr_wdata_int[0]}; // Only direct and vectored mode are supported
      end
      // uepc: exception program counter
      CSR_UEPC: if (csr_we_int) begin
        uepc_n     = csr_wdata_int;
      end
      // ucause: exception cause
      CSR_UCAUSE: if (csr_we_int) ucause_n = {csr_wdata_int[31], csr_wdata_int[5:0]};
    endcase

    // exception controller gets priority over other writes
    unique case (1'b1)

      csr_save_cause_i: begin

        unique case (1'b1)
          csr_save_if_i:
            exception_pc = pc_if_i;
          csr_save_id_i:
            exception_pc = pc_id_i;
          csr_save_ex_i:
            exception_pc = pc_ex_i;
          default:;
        endcase

        unique case (priv_lvl_q)

          PRIV_LVL_U: begin
            if(~is_irq) begin
              //Exceptions, Ecall U --> M
              priv_lvl_n     = PRIV_LVL_M;
              mstatus_n.mpie = mstatus_q.uie;
              mstatus_n.mie  = 1'b0;
              mstatus_n.mpp  = PRIV_LVL_U;
              // TODO: correctly handled?
              if (debug_csr_save_i)
                  depc_n = exception_pc;
              else
                  mepc_n = exception_pc;
              mcause_n       = csr_cause_i;

            end
            else begin
              if(~csr_irq_sec_i) begin
              //U --> U
                priv_lvl_n     = PRIV_LVL_U;
                mstatus_n.upie = mstatus_q.uie;
                mstatus_n.uie  = 1'b0;
                // TODO: correctly handled?
                if (debug_csr_save_i)
                    depc_n = exception_pc;
                else
                    uepc_n = exception_pc;
                ucause_n       = csr_cause_i;

              end else begin
              //U --> M
                priv_lvl_n     = PRIV_LVL_M;
                mstatus_n.mpie = mstatus_q.uie;
                mstatus_n.mie  = 1'b0;
                mstatus_n.mpp  = PRIV_LVL_U;
                // TODO: correctly handled?
                if (debug_csr_save_i)
                    depc_n = exception_pc;
                else
                    mepc_n = exception_pc;
                mcause_n       = csr_cause_i;
              end
            end
          end //PRIV_LVL_U

          PRIV_LVL_M: begin
            if (debug_csr_save_i) begin
                // all interrupts are masked, don't update cause, epc, tval dpc
                // and mpstatus
                dcsr_n.prv   = PRIV_LVL_M;
                dcsr_n.cause = debug_cause_i;
                depc_n       = exception_pc;
            end else begin
                //Exceptions or Interrupts from PRIV_LVL_M always do M --> M
                priv_lvl_n     = PRIV_LVL_M;
                mstatus_n.mpie = mstatus_q.mie;
                mstatus_n.mie  = 1'b0;
                mstatus_n.mpp  = PRIV_LVL_M;
                mepc_n         = exception_pc;
                mcause_n       = csr_cause_i;
            end
          end //PRIV_LVL_M
          default:;

        endcase

      end //csr_save_cause_i

      csr_restore_uret_i: begin //URET
        //mstatus_q.upp is implicitly 0, i.e PRIV_LVL_U
        mstatus_n.uie  = mstatus_q.upie;
        priv_lvl_n     = PRIV_LVL_U;
        mstatus_n.upie = 1'b1;
      end //csr_restore_uret_i

      csr_restore_mret_i: begin //MRET
        unique case (mstatus_q.mpp)
          PRIV_LVL_U: begin
            mstatus_n.uie  = mstatus_q.mpie;
            priv_lvl_n     = PRIV_LVL_U;
            mstatus_n.mpie = 1'b1;
            mstatus_n.mpp  = PRIV_LVL_U;
          end
          PRIV_LVL_M: begin
            mstatus_n.mie  = mstatus_q.mpie;
            priv_lvl_n     = PRIV_LVL_M;
            mstatus_n.mpie = 1'b1;
            mstatus_n.mpp  = PRIV_LVL_U;
          end
          default:;
        endcase
      end //csr_restore_mret_i


      csr_restore_dret_i: begin //DRET
          // restore to the recorded privilege level
          // TODO: prevent illegal values, see riscv-debug p.44
          priv_lvl_n = dcsr_q.prv;

      end //csr_restore_dret_i

      default:;
    endcase
  end
end else begin //PULP_SECURE == 0
  // write logic
  always_comb
  begin
    fflags_n                 = fflags_q;
    frm_n                    = frm_q;
    fprec_n                  = fprec_q;
    mscratch_n               = mscratch_q;
    mepc_n                   = mepc_q;
    uepc_n                   = 'b0;             // Not used if PULP_SECURE == 0
    depc_n                   = depc_q;
    dcsr_n                   = dcsr_q;
    dscratch0_n              = dscratch0_q;
    dscratch1_n              = dscratch1_q;

    mstatus_n                = mstatus_q;
    mcause_n                 = mcause_q;
    ucause_n                 = '0;              // Not used if PULP_SECURE == 0
    hwlp_we_o                = '0;
    hwlp_regid_o             = '0;
    exception_pc             = pc_id_i;
    priv_lvl_n               = priv_lvl_q;
    mtvec_n                  = mtvec_q;
    utvec_n                  = '0;              // Not used if PULP_SECURE == 0
    pmp_reg_n.pmpaddr        = '0;              // Not used if PULP_SECURE == 0
    pmpcfg_packed_n          = '0;              // Not used if PULP_SECURE == 0
    pmp_reg_n.pmpcfg         = '0;              // Not used if PULP_SECURE == 0
    pmpaddr_we               = '0;
    pmpcfg_we                = '0;

    mie_n                    = mie_q;
    mie1_n                   = mie1_q;
    mtvec_mode_n             = mtvec_mode_q;
    utvec_mode_n             = '0;              // Not used if PULP_SECURE == 0

    if (FPU == 1) if (fflags_we_i) fflags_n = fflags_i | fflags_q;

    case (csr_addr_i)
      // fcsr: Floating-Point Control and Status Register (frm, fflags, fprec).
      CSR_FFLAGS : if (csr_we_int) fflags_n = (FPU == 1) ? csr_wdata_int[C_FFLAG-1:0] : '0;
      CSR_FRM    : if (csr_we_int) frm_n    = (FPU == 1) ? csr_wdata_int[C_RM-1:0]    : '0;
      CSR_FCSR   : if (csr_we_int) begin
         fflags_n = (FPU == 1) ? csr_wdata_int[C_FFLAG-1:0]            : '0;
         frm_n    = (FPU == 1) ? csr_wdata_int[C_RM+C_FFLAG-1:C_FFLAG] : '0;
      end
      FPREC      : if (csr_we_int) fprec_n = (FPU == 1) ? csr_wdata_int[C_PC-1:0]    : '0;

      // mstatus: IE bit
      CSR_MSTATUS: if (csr_we_int) begin
        mstatus_n = '{
          uie:  csr_wdata_int[`MSTATUS_UIE_BITS],
          mie:  csr_wdata_int[`MSTATUS_MIE_BITS],
          upie: csr_wdata_int[`MSTATUS_UPIE_BITS],
          mpie: csr_wdata_int[`MSTATUS_MPIE_BITS],
          mpp:  PrivLvl_t'(csr_wdata_int[`MSTATUS_MPP_BITS]),
          mprv: csr_wdata_int[`MSTATUS_MPRV_BITS]
        };
      end
      // mie: machine interrupt enable
      CSR_MIE: if(csr_we_int) begin
        mie_n.irq_software = csr_wdata_int[CSR_MSIX_BIT];
        mie_n.irq_timer    = csr_wdata_int[CSR_MTIX_BIT];
        mie_n.irq_external = csr_wdata_int[CSR_MEIX_BIT];
        mie_n.irq_fast     = csr_wdata_int[CSR_MFIX_BIT_HIGH:CSR_MFIX_BIT_LOW];
      end
      // mie1: machine interrupt enable for fast interrupt extension (irq_fast_i[47:16])
      CSR_MIE1: if (csr_we_int) begin
        mie1_n = csr_wdata_int;
      end
      // mtvec: machine trap-handler base address
      CSR_MTVEC: if (csr_we_int) begin
        mtvec_n    = csr_wdata_int[31:8];
      end
      // mscratch: machine scratch
      CSR_MSCRATCH: if (csr_we_int) begin
        mscratch_n = csr_wdata_int;
      end
      // mepc: exception program counter
      CSR_MEPC: if (csr_we_int) begin
        mepc_n = csr_wdata_int & ~32'b1; // force 16-bit alignment
      end
      // mcause
      CSR_MCAUSE: if (csr_we_int) mcause_n = {csr_wdata_int[31], csr_wdata_int[5:0]};

      CSR_DCSR:
               if (csr_we_int)
               begin
                    dcsr_n = csr_wdata_int;
                    //31:28 xdebuger = 4 -> debug is implemented
                    dcsr_n.xdebugver=4'h4;
                    //privilege level: 0-> U;1-> S; 3->M.
                    dcsr_n.prv=priv_lvl_q;
                    //currently not supported:
                    dcsr_n.nmip=1'b0;   //nmip
                    dcsr_n.mprven=1'b0; //mprven
                    dcsr_n.stopcount=1'b0;   //stopcount
                    dcsr_n.stoptime=1'b0;  //stoptime
               end
      CSR_DPC:
               if (csr_we_int)
               begin
                    depc_n = csr_wdata_int & ~32'b1; // force 16-bit alignment
               end

      CSR_DSCRATCH0:
               if (csr_we_int)
               begin
                    dscratch0_n = csr_wdata_int;
               end

      CSR_DSCRATCH1:
               if (csr_we_int)
               begin
                    dscratch1_n = csr_wdata_int;
               end

      // hardware loops
      HWLoop0_START:   if (csr_we_int) begin hwlp_we_o = 3'b001; hwlp_regid_o = 1'b0; end
      HWLoop0_END:     if (csr_we_int) begin hwlp_we_o = 3'b010; hwlp_regid_o = 1'b0; end
      HWLoop0_COUNTER: if (csr_we_int) begin hwlp_we_o = 3'b100; hwlp_regid_o = 1'b0; end
      HWLoop1_START:   if (csr_we_int) begin hwlp_we_o = 3'b001; hwlp_regid_o = 1'b1; end
      HWLoop1_END:     if (csr_we_int) begin hwlp_we_o = 3'b010; hwlp_regid_o = 1'b1; end
      HWLoop1_COUNTER: if (csr_we_int) begin hwlp_we_o = 3'b100; hwlp_regid_o = 1'b1; end
    endcase

    // exception controller gets priority over other writes
    unique case (1'b1)

      csr_save_cause_i: begin
        unique case (1'b1)
          csr_save_if_i:
            exception_pc = pc_if_i;
          csr_save_id_i:
            exception_pc = pc_id_i;
          default:;
        endcase

        if (debug_csr_save_i) begin
            // all interrupts are masked, don't update cause, epc, tval dpc and
            // mpstatus
            dcsr_n.prv   = PRIV_LVL_M;
            dcsr_n.cause = debug_cause_i;
            depc_n       = exception_pc;
        end else begin
            priv_lvl_n     = PRIV_LVL_M;
            mstatus_n.mpie = mstatus_q.mie;
            mstatus_n.mie  = 1'b0;
            mstatus_n.mpp  = PRIV_LVL_M;
            mepc_n = exception_pc;
            mcause_n       = csr_cause_i;
        end
      end //csr_save_cause_i

      csr_restore_mret_i: begin //MRET
        mstatus_n.mie  = mstatus_q.mpie;
        priv_lvl_n     = PRIV_LVL_M;
        mstatus_n.mpie = 1'b1;
        mstatus_n.mpp  = PRIV_LVL_M;
      end //csr_restore_mret_i

      csr_restore_dret_i: begin //DRET
        // restore to the recorded privilege level
        // TODO: prevent illegal values, see riscv-debug p.44
        priv_lvl_n = dcsr_q.prv;
      end //csr_restore_dret_i

      default:;
    endcase
  end
end //PULP_SECURE

  assign hwlp_data_o = csr_wdata_int;

  // CSR operation logic
  always_comb
  begin
    csr_wdata_int = csr_wdata_i;
    csr_we_int    = 1'b1;

    unique case (csr_op_i)
      CSR_OP_WRITE: csr_wdata_int = csr_wdata_i;
      CSR_OP_SET:   csr_wdata_int = csr_wdata_i | csr_rdata_o;
      CSR_OP_CLEAR: csr_wdata_int = (~csr_wdata_i) & csr_rdata_o;

      CSR_OP_READ: begin
        csr_wdata_int = csr_wdata_i;
        csr_we_int    = 1'b0;
      end

      default:;
    endcase
  end

  assign csr_rdata_o = csr_rdata_int;

  // Interrupt Encoder:
  // - sets correct id to request to ID
  // - encodes priority order
  always_comb
  begin

    if (menip1[31])              irq_id_o = 6'd63;
    else if (menip1[30])         irq_id_o = 6'd62;
    else if (menip1[29])         irq_id_o = 6'd61;
    else if (menip1[28])         irq_id_o = 6'd60;
    else if (menip1[27])         irq_id_o = 6'd59;
    else if (menip1[26])         irq_id_o = 6'd58;
    else if (menip1[25])         irq_id_o = 6'd57;
    else if (menip1[24])         irq_id_o = 6'd56;
    else if (menip1[23])         irq_id_o = 6'd55;
    else if (menip1[22])         irq_id_o = 6'd54;
    else if (menip1[21])         irq_id_o = 6'd53;
    else if (menip1[20])         irq_id_o = 6'd52;
    else if (menip1[19])         irq_id_o = 6'd51;
    else if (menip1[18])         irq_id_o = 6'd50;
    else if (menip1[17])         irq_id_o = 6'd49;
    else if (menip1[16])         irq_id_o = 6'd48;
    else if (menip1[15])         irq_id_o = 6'd47;
    else if (menip1[14])         irq_id_o = 6'd46;
    else if (menip1[13])         irq_id_o = 6'd45;
    else if (menip1[12])         irq_id_o = 6'd44;
    else if (menip1[11])         irq_id_o = 6'd43;
    else if (menip1[10])         irq_id_o = 6'd42;
    else if (menip1[ 9])         irq_id_o = 6'd41;
    else if (menip1[ 8])         irq_id_o = 6'd40;
    else if (menip1[ 7])         irq_id_o = 6'd39;
    else if (menip1[ 6])         irq_id_o = 6'd38;
    else if (menip1[ 5])         irq_id_o = 6'd37;
    else if (menip1[ 4])         irq_id_o = 6'd36;
    else if (menip1[ 3])         irq_id_o = 6'd35;
    else if (menip1[ 2])         irq_id_o = 6'd34;
    else if (menip1[ 1])         irq_id_o = 6'd33;
    else if (menip1[ 0])         irq_id_o = 6'd32;
    else if (menip.irq_fast[15]) irq_id_o = 6'd31;
    else if (menip.irq_fast[14]) irq_id_o = 6'd30;
    else if (menip.irq_fast[13]) irq_id_o = 6'd29;
    else if (menip.irq_fast[12]) irq_id_o = 6'd28;
    else if (menip.irq_fast[11]) irq_id_o = 6'd27;
    else if (menip.irq_fast[10]) irq_id_o = 6'd26;
    else if (menip.irq_fast[ 9]) irq_id_o = 6'd25;
    else if (menip.irq_fast[ 8]) irq_id_o = 6'd24;
    else if (menip.irq_fast[ 7]) irq_id_o = 6'd23;
    else if (menip.irq_fast[ 6]) irq_id_o = 6'd22;
    else if (menip.irq_fast[ 5]) irq_id_o = 6'd21;
    else if (menip.irq_fast[ 4]) irq_id_o = 6'd20;
    else if (menip.irq_fast[ 3]) irq_id_o = 6'd19;
    else if (menip.irq_fast[ 2]) irq_id_o = 6'd18;
    else if (menip.irq_fast[ 1]) irq_id_o = 6'd17;
    else if (menip.irq_fast[ 0]) irq_id_o = 6'd16;
    else if (menip.irq_external) irq_id_o = CSR_MEIX_BIT;
    else if (menip.irq_software) irq_id_o = CSR_MSIX_BIT;
    else if (menip.irq_timer)    irq_id_o = CSR_MTIX_BIT;
    else                         irq_id_o = CSR_MTIX_BIT;
  end


  // directly output some registers
  assign m_irq_enable_o  = mstatus_q.mie & priv_lvl_q == PRIV_LVL_M;
  assign u_irq_enable_o  = mstatus_q.uie & priv_lvl_q == PRIV_LVL_U;
  assign priv_lvl_o      = priv_lvl_q;
  assign sec_lvl_o       = priv_lvl_q[0];
  assign frm_o           = (FPU == 1) ? frm_q : '0;
  assign fprec_o         = (FPU == 1) ? fprec_q : '0;

  assign mtvec_o         = mtvec_q;
  assign utvec_o         = utvec_q;
  assign mtvec_mode_o    = mtvec_mode_q;
  assign utvec_mode_o    = utvec_mode_q;

  assign mepc_o          = mepc_q;
  assign uepc_o          = uepc_q;

  assign depc_o          = depc_q;

  assign pmp_addr_o     = pmp_reg_q.pmpaddr;
  assign pmp_cfg_o      = pmp_reg_q.pmpcfg;

  assign debug_single_step_o  = dcsr_q.step;
  assign debug_ebreakm_o      = dcsr_q.ebreakm;
  assign debug_ebreaku_o      = dcsr_q.ebreaku;

  // Output interrupt pending to ID/Controller and to clock gating (WFI)
  assign irq_pending_o = menip.irq_software | menip.irq_timer | menip.irq_external | (|menip.irq_fast) | (|menip1);

  generate
  if (PULP_SECURE == 1)
  begin

    for(j=0;j<N_PMP_ENTRIES;j++)
    begin : CS_PMP_CFG
      assign pmp_reg_n.pmpcfg[j]                                 = pmpcfg_packed_n[j/4][8*((j%4)+1)-1:8*(j%4)];
      assign pmpcfg_packed_q[j/4][8*((j%4)+1)-1:8*(j%4)]         = pmp_reg_q.pmpcfg[j];
    end

    for(j=0;j<N_PMP_ENTRIES;j++)
    begin : CS_PMP_REGS_FF
      always_ff @(posedge clk, negedge rst_n)
      begin
          if (rst_n == 1'b0)
          begin
            pmp_reg_q.pmpcfg[j]   <= '0;
            pmp_reg_q.pmpaddr[j]  <= '0;
          end
          else
          begin
            if(pmpcfg_we[j])
              pmp_reg_q.pmpcfg[j]    <= USE_PMP ? pmp_reg_n.pmpcfg[j]  : '0;
            if(pmpaddr_we[j])
              pmp_reg_q.pmpaddr[j]   <= USE_PMP ? pmp_reg_n.pmpaddr[j] : '0;
          end
        end
      end //CS_PMP_REGS_FF

      always_ff @(posedge clk, negedge rst_n)
      begin
          if (rst_n == 1'b0)
          begin
            uepc_q         <= '0;
            ucause_q       <= '0;
            utvec_q        <= '0;
            utvec_mode_q   <= MTVEC_MODE;
            priv_lvl_q     <= PRIV_LVL_M;
          end
          else
          begin
            uepc_q         <= uepc_n;
            ucause_q       <= ucause_n;
            utvec_q        <= utvec_n;
            utvec_mode_q   <= utvec_mode_n;
            priv_lvl_q     <= priv_lvl_n;
          end
        end

  end
  else begin
        assign pmp_reg_q    = '0;
        assign uepc_q       = '0;
        assign ucause_q     = '0;
        assign utvec_q      = '0;
        assign utvec_mode_q = '0;
        assign priv_lvl_q   = PRIV_LVL_M;

  end
  endgenerate


  // actual registers
  always_ff @(posedge clk, negedge rst_n)
  begin
    if (rst_n == 1'b0)
    begin
      frm_q      <= '0;
      fflags_q   <= '0;
      fprec_q    <= '0;
      mstatus_q  <= '{
              uie:  1'b0,
              mie:  1'b0,
              upie: 1'b0,
              mpie: 1'b0,
              mpp:  PRIV_LVL_M,
              mprv: 1'b0
            };
      mepc_q      <= '0;
      mcause_q    <= '0;

      depc_q      <= '0;
      dcsr_q         <= '{
          xdebugver: XDEBUGVER_STD,
          cause:     DBG_CAUSE_NONE, // 3'h0
          prv:       PRIV_LVL_M,
          default:   '0
      };
      dscratch0_q  <= '0;
      dscratch1_q  <= '0;
      mscratch_q   <= '0;
      mie_q        <= '0;
      mie1_q       <= '0;
      mtvec_q      <= '0;
      mtvec_mode_q <= MTVEC_MODE;
      stack_base_q <= '0;
      stack_size_q <= '0;
    end
    else
    begin
      // update CSRs
      if(FPU == 1) begin
        frm_q      <= frm_n;
        fflags_q   <= fflags_n;
        fprec_q    <= fprec_n;
      end else begin
        frm_q      <= 'b0;
        fflags_q   <= 'b0;
        fprec_q    <= 'b0;
      end
      if (PULP_SECURE == 1) begin
        mstatus_q      <= mstatus_n ;
      end else begin
        mstatus_q  <= '{
                uie:  1'b0,
                mie:  mstatus_n.mie,
                upie: 1'b0,
                mpie: mstatus_n.mpie,
                mpp:  PRIV_LVL_M,
                mprv: 1'b0
              };
      end
      mepc_q       <= mepc_n;
      mcause_q     <= mcause_n;
      depc_q       <= depc_n;
      dcsr_q       <= dcsr_n;
      dscratch0_q  <= dscratch0_n;
      dscratch1_q  <= dscratch1_n;
      mscratch_q   <= mscratch_n;
      mie_q        <= mie_n;
      mie1_q       <= mie1_n;
      mtvec_q      <= mtvec_n;
      mtvec_mode_q <= mtvec_mode_n;
      stack_base_q <= stack_base_n;
      stack_size_q <= stack_size_n;
    end
  end
  assign stack_base_o = stack_base_q;
  assign stack_limit_o = stack_base_q - stack_size_q;

 ////////////////////////////////////////////////////////////////////////
 //  ____       _                   _____     _                        //
 // |  _ \  ___| |__  _   _  __ _  |_   _| __(_) __ _  __ _  ___ _ __  //
 // | | | |/ _ \ '_ \| | | |/ _` |   | || '__| |/ _` |/ _` |/ _ \ '__| //
 // | |_| |  __/ |_) | |_| | (_| |   | || |  | | (_| | (_| |  __/ |    //
 // |____/ \___|_.__/ \__,_|\__, |   |_||_|  |_|\__, |\__, |\___|_|    //
 //                         |___/               |___/ |___/            //
 ////////////////////////////////////////////////////////////////////////

  if (DEBUG_TRIGGER_EN) begin : gen_trigger_regs
    // Register values
    logic        tmatch_control_exec_n, tmatch_control_exec_q;
    logic [31:0] tmatch_value_n       , tmatch_value_q;
    // Write enables
    logic tmatch_control_we;
    logic tmatch_value_we;

    // Write select
    assign tmatch_control_we = csr_we_int & debug_mode_i & (csr_addr_i == CSR_TDATA1);
    assign tmatch_value_we   = csr_we_int & debug_mode_i & (csr_addr_i == CSR_TDATA2);


    // Registers
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        tmatch_control_exec_q <= 'b0;
        tmatch_value_q        <= 'b0;
      end else begin
        if(tmatch_control_we)
          tmatch_control_exec_q <= csr_wdata_int[2];
        if(tmatch_value_we)
          tmatch_value_q        <= csr_wdata_int[31:0];
     end
    end

    // Assign read data
    // TDATA0 - only support simple address matching
    assign tmatch_control_rdata =
               {
                4'h2,                  // type    : address/data match
                1'b1,                  // dmode   : access from D mode only
                6'h00,                 // maskmax : exact match only
                1'b0,                  // hit     : not supported
                1'b0,                  // select  : address match only
                1'b0,                  // timing  : match before execution
                2'b00,                 // sizelo  : match any access
                4'h1,                  // action  : enter debug mode
                1'b0,                  // chain   : not supported
                4'h0,                  // match   : simple match
                1'b1,                  // m       : match in m-mode
                1'b0,                  // 0       : zero
                1'b0,                  // s       : not supported
                PULP_SECURE==1,        // u       : match in u-mode
                tmatch_control_exec_q, // execute : match instruction address
                1'b0,                  // store   : not supported
                1'b0};                 // load    : not supported

    // TDATA1 - address match value only
    assign tmatch_value_rdata = tmatch_value_q;

    // Breakpoint matching
    // We match against the next address, as the breakpoint must be taken before execution
    assign trigger_match_o = tmatch_control_exec_q &
                              (pc_id_i[31:0] == tmatch_value_q[31:0]);

  end else begin : gen_no_trigger_regs
    assign tmatch_control_rdata = 'b0;
    assign tmatch_value_rdata   = 'b0;
    assign trigger_match_o      = 'b0;
  end

  /////////////////////////////////////////////////////////////////
  //   ____            __     ____                  _            //
  // |  _ \ ___ _ __ / _|   / ___|___  _   _ _ __ | |_ ___ _ __  //
  // | |_) / _ \ '__| |_   | |   / _ \| | | | '_ \| __/ _ \ '__| //
  // |  __/  __/ |  |  _|  | |__| (_) | |_| | | | | ||  __/ |    //
  // |_|   \___|_|  |_|(_)  \____\___/ \__,_|_| |_|\__\___|_|    //
  //                                                             //
  /////////////////////////////////////////////////////////////////

  // ------------------------
  // Events to count

  assign hpm_events[0]  = 1'b1;                                          // cycle counter
  assign hpm_events[1]  = id_valid_i & is_decoding_i;                    // instruction counter
  assign hpm_events[2]  = ld_stall_i & id_valid_q;                       // nr of load use hazards
  assign hpm_events[3]  = jr_stall_i & id_valid_q;                       // nr of jump register hazards
  assign hpm_events[4]  = imiss_i & (~pc_set_i);                         // cycles waiting for instruction fetches, excluding jumps and branches
  assign hpm_events[5]  = mem_load_i;                                    // nr of loads
  assign hpm_events[6]  = mem_store_i;                                   // nr of stores
  assign hpm_events[7]  = jump_i                     & id_valid_q;       // nr of jumps (unconditional)
  assign hpm_events[8]  = branch_i                   & id_valid_q;       // nr of branches (conditional)
  assign hpm_events[9]  = branch_i & branch_taken_i  & id_valid_q;       // nr of taken branches (conditional)
  assign hpm_events[10] = id_valid_i & is_decoding_i & is_compressed_i;  // compressed instruction counter
  assign hpm_events[11] = pipeline_stall_i;                              // extra cycles from elw

  assign hpm_events[12] = !APU ? 1'b0 : apu_typeconflict_i & ~apu_dep_i;
  assign hpm_events[13] = !APU ? 1'b0 : apu_contention_i;
  assign hpm_events[14] = !APU ? 1'b0 : apu_dep_i & ~apu_contention_i;
  assign hpm_events[15] = !APU ? 1'b0 : apu_wb_i;

  // ------------------------
  // address decoder for performance counter registers
  logic mcountinhibit_we ;
  logic mhpmevent_we     ;

  assign mcountinhibit_we = csr_we_int & (  csr_addr_i == CSR_MCOUNTINHIBIT);
  assign mhpmevent_we     = csr_we_int & ( (csr_addr_i == CSR_MHPMEVENT3  )||
                                           (csr_addr_i == CSR_MHPMEVENT4  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT5  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT6  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT7  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT8  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT9  ) ||
                                           (csr_addr_i == CSR_MHPMEVENT10 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT11 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT12 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT13 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT14 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT15 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT16 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT17 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT18 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT19 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT20 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT21 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT22 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT23 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT24 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT25 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT26 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT27 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT28 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT29 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT30 ) ||
                                           (csr_addr_i == CSR_MHPMEVENT31 ) );

  // ------------------------
  // next value for performance counters and control registers
  always_comb
    begin
      mcountinhibit_n = mcountinhibit_q;
      mhpmevent_n     = mhpmevent_q    ;
      mhpmcounter_n   = mhpmcounter_q  ;

      // Inhibit Control
      if(mcountinhibit_we)
        mcountinhibit_n = csr_wdata_int;

      // Event Control
      if(mhpmevent_we)
        mhpmevent_n[csr_addr_i[4:0]] = csr_wdata_int;

      // Counters
      for(int cnt_idx=0; cnt_idx<32; cnt_idx++)

        if( csr_we_int & ( csr_addr_i == (CSR_MCYCLE + cnt_idx) ) )
          // write lower counter bits
          mhpmcounter_n[cnt_idx][31:0]  = csr_wdata_int;

        else if( csr_we_int & ( csr_addr_i == (CSR_MCYCLEH + cnt_idx) ) )
          // write upper counter bits
          mhpmcounter_n[cnt_idx][63:32]  = csr_wdata_int;

        else
          if(!mcountinhibit_q[cnt_idx])
            // If not inhibitted, increment on appropriate condition

            if( cnt_idx == 0)
              // mcycle = mhpmcounter[0] : count every cycle (if not inhibited)
              mhpmcounter_n[cnt_idx] = mhpmcounter_n[cnt_idx] + 1;

            else if(cnt_idx == 2)
              // minstret = mhpmcounter[2]  : count every retired instruction (if not inhibited)
              mhpmcounter_n[cnt_idx] = mhpmcounter_n[cnt_idx] + hpm_events[1];

            else if( (cnt_idx>2) && (cnt_idx<(NUM_MHPMCOUNTERS+3)))
              // add +1 if any event is enabled and active
              mhpmcounter_n[cnt_idx] = mhpmcounter_q[cnt_idx] +
                                       |(hpm_events & mhpmevent_q[cnt_idx][NUM_HPM_EVENTS-1:0]) ;
    end

  // ------------------------
  // HPM Registers
  //  Counter Registers: mhpcounter_q[]
  genvar cnt_gidx;
  generate
    for(cnt_gidx = 0; cnt_gidx < 32; cnt_gidx++) begin : g_mhpmcounter
      // mcyclce  is located at index 0
      // there is no counter at index 1
      // minstret is located at index 2
      // Programable HPM counters start at index 3
      
`ifdef VERILATOR
      always_ff @(posedge clk, negedge rst_n) begin
        if( (cnt_gidx == 1) || (cnt_gidx >= (NUM_MHPMCOUNTERS+3) ) ) begin : g_non_implemented
          mhpmcounter_q[cnt_gidx] <= 'b0;
        end else begin : g_implemented
            if (!rst_n) begin
                mhpmcounter_q[cnt_gidx] <= 'b0;
            end else begin
                mhpmcounter_q[cnt_gidx] <= mhpmcounter_n[cnt_gidx];
            end
        end
      end
`else
      if( (cnt_gidx == 1) || (cnt_gidx >= (NUM_MHPMCOUNTERS+3) ) ) begin : g_non_implemented
        always_ff @(posedge clk) begin
          mhpmcounter_q[cnt_gidx] <= 'b0;
        end
      end else begin : g_implemented
        always_ff @(posedge clk, negedge rst_n) begin
            if (!rst_n) begin
                mhpmcounter_q[cnt_gidx] <= 'b0;
            end else begin
                mhpmcounter_q[cnt_gidx] <= mhpmcounter_n[cnt_gidx];
            end
        end
      end
`endif
    end
  endgenerate

  //  Event Register: mhpevent_q[]
  genvar evt_gidx;
  generate
    for(evt_gidx = 0; evt_gidx < 32; evt_gidx++) begin : g_mhpmevent
      // programable HPM events start at index3
      if( (evt_gidx < 3) || (evt_gidx >= (NUM_MHPMCOUNTERS+3) ) ) begin : g_non_implemented
        always_ff @(posedge clk) begin
          mhpmevent_q[evt_gidx] <= 'b0;
        end
      end else begin : g_implemented
        if(NUM_HPM_EVENTS < 32) begin
          always_ff @(posedge clk) begin
            mhpmevent_q[evt_gidx][31:NUM_HPM_EVENTS] <= 'b0;
          end
        end else begin
          always_ff @(posedge clk, negedge rst_n) begin
            if (!rst_n) begin
                mhpmevent_q[evt_gidx][NUM_HPM_EVENTS-1:0]  <= 'b0;
            end else begin
                mhpmevent_q[evt_gidx][NUM_HPM_EVENTS-1:0]  <= mhpmevent_n[evt_gidx][NUM_HPM_EVENTS-1:0];
            end
          end
        end
      end
    end
  endgenerate

  //  Inhibit Regsiter: mcountinhibit_q
  //  Note: implemented counters are disabled out of reset to save power
  genvar inh_gidx;
  generate
    for(inh_gidx = 0; inh_gidx < 32; inh_gidx++) begin : g_mcountinhibit
`ifdef VERILATOR
      always_ff @(posedge clk, negedge rst_n) begin
        if( (inh_gidx == 1) || (inh_gidx >= (NUM_MHPMCOUNTERS+3) ) ) begin : g_non_implemented
          mcountinhibit_q[inh_gidx] <= 'b1; // default disable
        end else begin : g_implemented
          if (!rst_n) begin
            mcountinhibit_q[inh_gidx] <= 'b1; // default disable
          end else begin
            mcountinhibit_q[inh_gidx] <= mcountinhibit_n[inh_gidx];
          end
        end
      end
`else
      if( (inh_gidx == 1) || (inh_gidx >= (NUM_MHPMCOUNTERS+3) ) ) begin : g_non_implemented
        always_ff @(posedge clk) begin
          mcountinhibit_q[inh_gidx] <= 'b1; // default disable
        end
      end else begin : g_implemented
        always_ff @(posedge clk, negedge rst_n) begin
          if (!rst_n) begin
            mcountinhibit_q[inh_gidx] <= 'b1; // default disable
          end else begin
            mcountinhibit_q[inh_gidx] <= mcountinhibit_n[inh_gidx];
          end
        end
      end
`endif
    end
  endgenerate

  // capture valid for event match
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      id_valid_q <= 'b0;
    else
      id_valid_q <= id_valid_i;


endmodule

