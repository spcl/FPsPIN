# SPDX-License-Identifier: BSD-2-Clause-Views
# Copyright (c) 2019-2023 The Regents of the University of California

# FPGA settings
FPGA_PART = xcvu9p-fsgd2104-2L-e
FPGA_TOP = fpga
FPGA_ARCH = virtexuplus

# Files for synthesis
SYN_FILES = rtl/fpga.v
SYN_FILES += rtl/fpga_core.v
SYN_FILES += rtl/debounce_switch.v
SYN_FILES += rtl/sync_signal.v
SYN_FILES += rtl/common/mqnic_core_pcie_us.v
SYN_FILES += rtl/common/mqnic_core_pcie.v
SYN_FILES += rtl/common/mqnic_core.v
SYN_FILES += rtl/common/mqnic_dram_if.v
SYN_FILES += rtl/common/mqnic_interface.v
SYN_FILES += rtl/common/mqnic_interface_tx.v
SYN_FILES += rtl/common/mqnic_interface_rx.v
SYN_FILES += rtl/common/mqnic_port.v
SYN_FILES += rtl/common/mqnic_port_tx.v
SYN_FILES += rtl/common/mqnic_port_rx.v
SYN_FILES += rtl/common/mqnic_egress.v
SYN_FILES += rtl/common/mqnic_ingress.v
SYN_FILES += rtl/common/mqnic_l2_egress.v
SYN_FILES += rtl/common/mqnic_l2_ingress.v
SYN_FILES += rtl/common/mqnic_rx_queue_map.v
SYN_FILES += rtl/common/mqnic_ptp.v
SYN_FILES += rtl/common/mqnic_ptp_clock.v
SYN_FILES += rtl/common/mqnic_ptp_perout.v
SYN_FILES += rtl/common/mqnic_rb_clk_info.v
SYN_FILES += rtl/common/mqnic_port_map_mac_axis.v
SYN_FILES += rtl/common/cpl_write.v
SYN_FILES += rtl/common/cpl_op_mux.v
SYN_FILES += rtl/common/desc_fetch.v
SYN_FILES += rtl/common/desc_op_mux.v
SYN_FILES += rtl/common/queue_manager.v
SYN_FILES += rtl/common/cpl_queue_manager.v
SYN_FILES += rtl/common/tx_fifo.v
SYN_FILES += rtl/common/rx_fifo.v
SYN_FILES += rtl/common/tx_req_mux.v
SYN_FILES += rtl/common/tx_engine.v
SYN_FILES += rtl/common/rx_engine.v
SYN_FILES += rtl/common/tx_checksum.v
SYN_FILES += rtl/common/rx_hash.v
SYN_FILES += rtl/common/rx_checksum.v
SYN_FILES += rtl/common/rb_drp.v
SYN_FILES += rtl/common/cmac_gty_wrapper.v
SYN_FILES += rtl/common/cmac_gty_ch_wrapper.v
SYN_FILES += rtl/common/stats_counter.v
SYN_FILES += rtl/common/stats_collect.v
SYN_FILES += rtl/common/stats_pcie_if.v
SYN_FILES += rtl/common/stats_pcie_tlp.v
SYN_FILES += rtl/common/stats_dma_if_pcie.v
SYN_FILES += rtl/common/stats_dma_latency.v
SYN_FILES += rtl/common/mqnic_tx_scheduler_block_rr.v
SYN_FILES += rtl/common/tx_scheduler_rr.v
SYN_FILES += rtl/common/cmac_pad.v
SYN_FILES += rtl/common/mac_ts_insert.v
SYN_FILES += lib/eth/rtl/ptp_clock.v
SYN_FILES += lib/eth/rtl/ptp_clock_cdc.v
SYN_FILES += lib/eth/rtl/ptp_perout.v
SYN_FILES += lib/axi/rtl/axi_dma_wr.v
SYN_FILES += lib/axi/rtl/axi_dma_rd.v
SYN_FILES += lib/axi/rtl/axil_interconnect.v
SYN_FILES += lib/axi/rtl/axil_crossbar.v
SYN_FILES += lib/axi/rtl/axil_crossbar_addr.v
SYN_FILES += lib/axi/rtl/axil_crossbar_rd.v
SYN_FILES += lib/axi/rtl/axil_crossbar_wr.v
SYN_FILES += lib/axi/rtl/axil_ram.v # for APP
SYN_FILES += lib/axi/rtl/axil_reg_if.v
SYN_FILES += lib/axi/rtl/axil_reg_if_rd.v
SYN_FILES += lib/axi/rtl/axil_reg_if_wr.v
SYN_FILES += lib/axi/rtl/axil_register_rd.v
SYN_FILES += lib/axi/rtl/axil_register_wr.v
SYN_FILES += lib/axi/rtl/arbiter.v
SYN_FILES += lib/axi/rtl/priority_encoder.v
SYN_FILES += lib/axis/rtl/axis_adapter.v
SYN_FILES += lib/axis/rtl/axis_arb_mux.v
SYN_FILES += lib/axis/rtl/axis_async_fifo.v
SYN_FILES += lib/axis/rtl/axis_async_fifo_adapter.v
SYN_FILES += lib/axis/rtl/axis_demux.v
SYN_FILES += lib/axis/rtl/axis_fifo.v
SYN_FILES += lib/axis/rtl/axis_fifo_adapter.v
SYN_FILES += lib/axis/rtl/axis_pipeline_fifo.v
SYN_FILES += lib/axis/rtl/axis_register.v
SYN_FILES += lib/axis/rtl/sync_reset.v
SYN_FILES += lib/pcie/rtl/pcie_axil_master.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_demux.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_demux_bar.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_mux.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_fifo.v
SYN_FILES += lib/pcie/rtl/pcie_tlp_fifo_raw.v
SYN_FILES += lib/pcie/rtl/pcie_msix.v
SYN_FILES += lib/pcie/rtl/irq_rate_limit.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie_rd.v
SYN_FILES += lib/pcie/rtl/dma_if_pcie_wr.v
SYN_FILES += lib/pcie/rtl/dma_if_mux.v
SYN_FILES += lib/pcie/rtl/dma_if_mux_rd.v
SYN_FILES += lib/pcie/rtl/dma_if_mux_wr.v
SYN_FILES += lib/pcie/rtl/dma_if_desc_mux.v
SYN_FILES += lib/pcie/rtl/dma_ram_demux_rd.v
SYN_FILES += lib/pcie/rtl/dma_ram_demux_wr.v
SYN_FILES += lib/pcie/rtl/dma_psdpram.v
SYN_FILES += lib/pcie/rtl/dma_client_axis_sink.v
SYN_FILES += lib/pcie/rtl/dma_client_axis_source.v
SYN_FILES += lib/pcie/rtl/pcie_us_if.v
SYN_FILES += lib/pcie/rtl/pcie_us_if_rc.v
SYN_FILES += lib/pcie/rtl/pcie_us_if_rq.v
SYN_FILES += lib/pcie/rtl/pcie_us_if_cc.v
SYN_FILES += lib/pcie/rtl/pcie_us_if_cq.v
SYN_FILES += lib/pcie/rtl/pcie_us_cfg.v
SYN_FILES += lib/pcie/rtl/pulse_merge.v

# Corundum-PsPIN
SYN_FILES += app/pspin/rtl/axil_interconnect_wrap_1x2.v
SYN_FILES += app/pspin/rtl/bus_cdc_wrap.v
SYN_FILES += app/pspin/rtl/mqnic_app_block.v
SYN_FILES += app/pspin/rtl/pspin_wrap.sv
SYN_FILES += app/pspin/rtl/pspin_ctrl_regs.v
SYN_FILES += app/pspin/rtl/pspin_egress_datapath.v
SYN_FILES += app/pspin/rtl/pspin_her_gen.v
SYN_FILES += app/pspin/rtl/pspin_ingress_datapath.v
SYN_FILES += app/pspin/rtl/pspin_ingress_dma.v
SYN_FILES += app/pspin/rtl/pspin_pkt_alloc.v
SYN_FILES += app/pspin/rtl/pspin_pkt_match.v
SYN_FILES += app/pspin/rtl/pspin_hostmem_dma.v
SYN_FILES += app/pspin/rtl/pspin_hostmem_dma_rd.v
SYN_FILES += app/pspin/rtl/pspin_hostmem_dma_wr.v

# PsPIN upstream
SYN_FILES += app/pspin/deps/pspin/hw/deps/scm/fpga_scm/register_file_1r_1w.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/scm/fpga_scm/register_file_1r_1w_1row.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/scm/fpga_scm/register_file_1w_multi_port_read.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi2apb/src/axi2apb_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi2apb/src/axi2apb_64_32.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_peripherals/cluster_control_unit/cluster_control_unit.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_peripherals/icache_ctrl_unit/mp_pf_icache_ctrl_unit.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_peripherals/icache_ctrl_unit/interfaces/mp_pf_icache_ctrl_unit_bus.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/event_unit_flex/event_unit_core.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/event_unit_flex/hw_dispatch.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/event_unit_flex/interc_sw_evt_trig.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/event_unit_flex/hw_mutex_unit.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/event_unit_flex/hw_barrier_unit.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/event_unit_flex/message_bus.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/event_unit_flex/event_unit_interface_mux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/event_unit_flex/event_unit_top.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/apb/src/apb_intf.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi2mem/src/axi_to_mem_interleaved.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi2mem/src/axi_to_mem_banked_mp.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi2mem/src/axi_to_mem.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/timer_unit/rtl/timer_unit_counter.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/timer_unit/rtl/timer_unit.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/timer_unit/rtl/timer_unit_counter_presc.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_slice/src/axi_ar_buffer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_slice/src/axi_aw_buffer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_slice/src/axi_r_buffer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_slice/src/axi_b_buffer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_slice/src/axi_single_slice.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_slice/src/axi_w_buffer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/nhi_port_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/cluster_peripherals.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/cpu_marx_if.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/core_demux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/inter_core_fifo.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/cluster_timer_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/pulp_cluster.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/cluster_bus_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/core_region.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/tryx_ctrl.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/per2axi_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/virtual_stdout_demux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/periph_FIFO.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/cluster_interconnect_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/axi2per_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/periph_demux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/cluster_event_map.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/per_demux_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/rtl/dmac_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/packages/apu_package.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/pulp_cluster/packages/pulp_cluster_package.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/include/axi/port.svh
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/include/axi/typedef.svh
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/include/axi/assign.svh
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_dw_converter.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_demux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_cut.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_id_prepend.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_dw_upsizer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/dma/axi_dma_data_path.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/dma/axi_dma_backend.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/dma/axi_dma_burst_reshaper.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/dma/axi_dma_data_mover.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/dma/frontends/pspin_soc_frontend/src/pspin_soc_dma.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/dma/frontends/pulp_cluster_frontend/src/pulp_cluster_frontend.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/dma/frontends/pulp_cluster_frontend/src/pulp_cluster_frontend_regs.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/dma/frontends/pulp_cluster_frontend/src/transfer_id_gen.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_serializer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_buf.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_err_slv.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_xbar.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_id_remap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_intf.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_atop_filter.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_dw_downsizer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_pkg.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_mux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi/src/axi_multicut.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/ResponseTree_PE.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/FanInPrimitive_Req_PE.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/AddressDecoder_Resp_PE.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/ResponseBlock_PE.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/RequestBlock2CH_PE.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/MUX2_REQ_PE.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/AddressDecoder_PE_Req.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/ArbitrationTree_PE.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/FanInPrimitive_PE_Resp.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/XBAR_PE.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/peripheral_interco/RR_Flag_Req_PE.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/interfaces/wide_dma_tcdm.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/interfaces/xbar_periph_bus.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/interfaces/xbar_tcdm_bus.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/interfaces/tcdm_bank_mem_bus.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/interfaces/xbar_demux_bus.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/tcdm_interconnect/amo_shim.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/tcdm_interconnect/addr_dec_resp_mux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/tcdm_interconnect/superbank_addr_decoder.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/tcdm_interconnect/tcdm_superbank_mux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/tcdm_interconnect/xbar.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/tcdm_interconnect/tcdm_interconnect.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/tcdm_interconnect/tcdm_interconnect_pkg.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/RequestBlock1CH.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/ResponseTree.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/FanInPrimitive_Resp.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/TCDM_PIPE_REQ.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/priority_Flag_Req.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/XBAR_TCDM_WRAPPER.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/tcdm_xbar_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/ResponseBlock.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/MUX2_REQ.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/grant_mask.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/AddressDecoder_Req.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/FanInPrimitive_Req.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/TestAndSet.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/RequestBlock2CH.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/XBAR_TCDM.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/parameters.v
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/ArbitrationTree.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/AddressDecoder_Resp.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/cluster_interconnect/rtl/low_latency_interco/TCDM_PIPE_RESP.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_riscv_atomics/src/axi_riscv_atomics_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_riscv_atomics/src/axi_riscv_amos.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_riscv_atomics/src/axi_riscv_amos_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_riscv_atomics/src/axi_riscv_atomics.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_riscv_atomics/src/axi_riscv_lrsc_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_riscv_atomics/src/axi_riscv_atomics_structs.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_riscv_atomics/src/axi_riscv_lrsc.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_riscv_atomics/src/axi_res_tbl.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_riscv_atomics/src/axi_riscv_amos_alu.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_ff_one.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_if_stage.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_int_controller.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_popcnt.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_prefetch_L0_buffer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_store_buffer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_L0_buffer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_hwloop_controller.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_compressed_decoder.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_core.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_controller.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_apu_disp.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/verilator-model/cluster_clock_gating.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_ex_stage.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_pmp.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/include/apu_macros.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/include/riscv_defines.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/include/riscv_tracer_defines.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/include/riscv_config.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/include/apu_core_package.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/include/fpnew_pkg.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_tracer.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_alu.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_mult.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_register_file.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_cs_registers.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_hwloop_regs.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_alu_div.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_id_stage.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_decoder.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/riscv/riscv_load_store_unit.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/include/common_cells/registers.svh
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_fork.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_register.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/spill_register.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/cf_math_pkg.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/counter.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_to_mem.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/rstgen_bypass.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/lzc.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/addr_decode.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/rr_arb_tree.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_filter.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/fall_through_register.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_arbiter_flushable.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/edge_propagator_tx.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_join.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/delta_counter.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_mux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/id_queue.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_fork_dynamic.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/onehot_to_bin.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_fifo.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/deprecated/generic_LFSR_8bit.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/deprecated/fifo_v2.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/deprecated/generic_fifo.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/deprecated/fifo_v1.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/fifo_v3.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_arbiter.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/stream_demux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/common_cells/src/rstgen.sv
# SYN_FILES += app/pspin/deps/pspin/hw/deps/tech_cells_generic/src/rtl/tc_sram.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/tech_cells_generic/src/fpga/tc_sram_xilinx.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/tech_cells_generic/src/fpga/tc_clk_xilinx.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/per2axi/src/per2axi_req_channel.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/per2axi/src/per2axi.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/per2axi/src/per2axi_busy_unit.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/per2axi/src/per2axi_res_channel.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache_mp_128_pf/RTL/pf_miss_mux.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache_mp_128_pf/RTL/merge_refill_cam_128_16.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache_mp_128_pf/RTL/central_controller_128.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache_mp_128_pf/RTL/prefetcher_if.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache_mp_128_pf/RTL/icache_top_mp_128_PF.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache_mp_128_pf/RTL/cache_controller_to_axi_128_PF.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache_mp_128_pf/RTL/icache_bank_mp_PF.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache_mp_128_pf/RTL/icache_bank_mp_128.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_slice_dc/src/dc_token_ring.v
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_slice_dc/src/dc_synchronizer.v
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi_slice_dc/src/dc_token_ring_fifo_dout.v
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi2per/axi2per.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi2per/axi2per_res_channel.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/axi2per/axi2per_req_channel.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache-intc/RoutingBlock_Req_icache_intc.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache-intc/RoutingBlock_Resp_icache_intc.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache-intc/icache_intc.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache-intc/DistributedArbitrationNetwork_Req_icache_intc.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache-intc/DistributedArbitrationNetwork_Resp_icache_intc.sv
SYN_FILES += app/pspin/deps/pspin/hw/deps/icache-intc/Req_Arb_Node_icache_intc.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/host_mst_mux.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/memories/sram.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/memories/l2_mem.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/memories/prog_mem.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pspin.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/soc_dma_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pulp_cluster_cfg_pkg.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/apb/apb_rw_regs.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/apb/apb_stdout.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/apb/apb_ro_regs.sv
# SYN_FILES += app/pspin/deps/pspin/hw/src/apb/apb_bus.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/apb/apb_bus_wrap.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/soc_ctrl_regs.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pulp_cluster_ooc.sv
# SYN_FILES += app/pspin/deps/pspin/hw/src/pspin_verilator.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/soc_peripherals.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/host_direct.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/cmds/cluster_cmd.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/cmds/cmd_unit.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pspin_cfg_pkg.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/interconnects/pe_noc.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/interconnects/nhi_xbar.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/interconnects/l2_xbar.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/interconnects/dma_noc.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/interconnects/cluster_noc.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pkt_scheduler/mpq_engine.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pkt_scheduler/cluster_scheduler.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pkt_scheduler/cluster_rb_shim.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pkt_scheduler/fifo_engine.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pkt_scheduler/cluster_rb.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pkt_scheduler/scheduler.sv
SYN_FILES += app/pspin/deps/pspin/hw/src/pkt_scheduler/hpu_driver.sv

# XDC files
XDC_FILES = fpga.xdc
XDC_FILES += placement.xdc
XDC_FILES += cfgmclk.xdc
XDC_FILES += boot.xdc
XDC_FILES += debug.xdc
XDC_FILES += lib/axis/syn/vivado/axis_async_fifo.tcl
XDC_FILES += lib/axis/syn/vivado/sync_reset.tcl
XDC_FILES += lib/eth/syn/vivado/ptp_clock_cdc.tcl
XDC_FILES += ../../../common/syn/vivado/mqnic_port.tcl
XDC_FILES += ../../../common/syn/vivado/mqnic_ptp_clock.tcl
XDC_FILES += ../../../common/syn/vivado/mqnic_rb_clk_info.tcl
XDC_FILES += ../../../common/syn/vivado/rb_drp.tcl
XDC_FILES += ../../../common/syn/vivado/cmac_gty_wrapper.tcl
XDC_FILES += ../../../common/syn/vivado/cmac_gty_ch_wrapper.tcl

# IP
IP_TCL_FILES = ip/pcie4_uscale_plus_0.tcl
IP_TCL_FILES += ip/cmac_usplus.tcl
IP_TCL_FILES += ip/cmac_gty.tcl
#IP_TCL_FILES += ip/ddr4_0.tcl
IP_TCL_FILES += ip/pspin_clk_wiz.tcl
IP_TCL_FILES += ip/pspin_host_clk_converter.tcl
IP_TCL_FILES += ip/pspin_host_protocol_converter.tcl
IP_TCL_FILES += ip/pspin_host_dwidth_converter.tcl
IP_TCL_FILES += ip/pspin_hostdma_clk_converter.tcl
IP_TCL_FILES += ip/proc_sys_reset_0.tcl

# Configuration
CONFIG_TCL_FILES = ./config.tcl

include ../common/vivado.mk

%_fallback.bit: %.bit
	echo "open_project $*.xpr" > generate_fallback_bit.tcl
	echo "open_run impl_1" >> generate_fallback_bit.tcl
	echo "startgroup" >> generate_fallback_bit.tcl
	echo "set_property BITSTREAM.CONFIG.CONFIGFALLBACK ENABLE [current_design]" >> generate_fallback_bit.tcl
	echo "set_property BITSTREAM.CONFIG.TIMER_CFG 0x03000000 [current_design]" >> generate_fallback_bit.tcl
	echo "set_property BITSTREAM.CONFIG.NEXT_CONFIG_REBOOT ENABLE [current_design]" >> generate_fallback_bit.tcl
	echo "set_property BITSTREAM.CONFIG.NEXT_CONFIG_ADDR 0x04000000 [current_design]" >> generate_fallback_bit.tcl
	echo "endgroup" >> generate_fallback_bit.tcl
	echo "write_bitstream -verbose -force $*_fallback.bit" >> generate_fallback_bit.tcl
	echo "undo" >> generate_fallback_bit.tcl
	echo "exit" >> generate_fallback_bit.tcl
	vivado -nojournal -nolog -mode batch -source generate_fallback_bit.tcl
	mkdir -p rev
	EXT=bit; COUNT=100; \
	while [ -e rev/$*_rev$$COUNT.$$EXT ]; \
	do COUNT=$$((COUNT+1)); done; \
	COUNT=$$((COUNT-1)); \
	cp $@ rev/$*_fallback_rev$$COUNT.$$EXT; \
	echo "Output: rev/$*_fallback_rev$$COUNT.$$EXT";

program: $(FPGA_TOP).bit
	echo "open_hw" > program.tcl
	echo "connect_hw_server" >> program.tcl
	echo "open_hw_target" >> program.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> program.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> program.tcl
	echo "set_property PROGRAM.FILE {$(FPGA_TOP).bit} [current_hw_device]" >> program.tcl
	echo "program_hw_devices [current_hw_device]" >> program.tcl
	echo "exit" >> program.tcl
	vivado -nojournal -nolog -mode batch -source program.tcl

%.mcs %.prm: %.bit
	echo "write_cfgmem -force -format mcs -size 128 -interface SPIx4 -loadbit {up 0x04000000 $*.bit} -checksum -file $*.mcs" > generate_mcs.tcl
	echo "exit" >> generate_mcs.tcl
	vivado -nojournal -nolog -mode batch -source generate_mcs.tcl
	mkdir -p rev
	COUNT=100; \
	while [ -e rev/$*_rev$$COUNT.bit ]; \
	do COUNT=$$((COUNT+1)); done; \
	COUNT=$$((COUNT-1)); \
	for x in .mcs .prm; \
	do cp $*$$x rev/$*_rev$$COUNT$$x; \
	echo "Output: rev/$*_rev$$COUNT$$x"; done;

%_fallback.mcs %_fallback.prm: %_fallback.bit
	echo "write_cfgmem -force -format mcs -size 128 -interface SPIx4 -loadbit {up 0x00000000 $*_fallback.bit} -checksum -file $*_fallback.mcs" > generate_fallback_mcs.tcl
	echo "exit" >> generate_fallback_mcs.tcl
	vivado -nojournal -nolog -mode batch -source generate_fallback_mcs.tcl
	mkdir -p rev
	COUNT=100; \
	while [ -e rev/$*_rev$$COUNT.bit ]; \
	do COUNT=$$((COUNT+1)); done; \
	COUNT=$$((COUNT-1)); \
	for x in .mcs .prm; \
	do cp $*_fallback$$x rev/$*_fallback_rev$$COUNT$$x; \
	echo "Output: rev/$*_fallback_rev$$COUNT$$x"; done;

%_full.mcs %_full.prm: %_fallback.bit %.bit
	echo "write_cfgmem -force -format mcs -size 128 -interface SPIx4 -loadbit {up 0x00000000 $*_fallback.bit up 0x04000000 $*.bit} -checksum -file $*_full.mcs" > generate_full_mcs.tcl
	echo "exit" >> generate_full_mcs.tcl
	vivado -nojournal -nolog -mode batch -source generate_full_mcs.tcl
	mkdir -p rev
	COUNT=100; \
	while [ -e rev/$*_rev$$COUNT.bit ]; \
	do COUNT=$$((COUNT+1)); done; \
	COUNT=$$((COUNT-1)); \
	for x in .mcs .prm; \
	do cp $*_full$$x rev/$*_full_rev$$COUNT$$x; \
	echo "Output: rev/$*_full_rev$$COUNT$$x"; done;

flash: $(FPGA_TOP).mcs $(FPGA_TOP).prm
	echo "open_hw" > flash.tcl
	echo "connect_hw_server" >> flash.tcl
	echo "open_hw_target" >> flash.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> flash.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> flash.tcl
	echo "create_hw_cfgmem -hw_device [current_hw_device] [lindex [get_cfgmem_parts {mt25qu01g-spi-x1_x2_x4}] 0]" >> flash.tcl
	echo "current_hw_cfgmem -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM [current_hw_device]]" >> flash.tcl
	echo "set_property PROGRAM.FILES [list \"$(FPGA_TOP).mcs\"] [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.PRM_FILES [list \"$(FPGA_TOP).prm\"] [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.ERASE 1 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.CFG_PROGRAM 1 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.VERIFY 1 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.CHECKSUM 0 [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.ADDRESS_RANGE {use_file} [current_hw_cfgmem]" >> flash.tcl
	echo "set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [current_hw_cfgmem]" >> flash.tcl
	echo "create_hw_bitstream -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM_BITFILE [current_hw_device]]" >> flash.tcl
	echo "program_hw_devices [current_hw_device]" >> flash.tcl
	echo "refresh_hw_device [current_hw_device]" >> flash.tcl
	echo "program_hw_cfgmem -hw_cfgmem [current_hw_cfgmem]" >> flash.tcl
	echo "boot_hw_device [current_hw_device]" >> flash.tcl
	echo "exit" >> flash.tcl
	vivado -nojournal -nolog -mode batch -source flash.tcl

flash%: $(FPGA_TOP)%.mcs $(FPGA_TOP)%.prm
	echo "open_hw" > flash$*.tcl
	echo "connect_hw_server" >> flash$*.tcl
	echo "open_hw_target" >> flash$*.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> flash$*.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> flash$*.tcl
	echo "create_hw_cfgmem -hw_device [current_hw_device] [lindex [get_cfgmem_parts {mt25qu01g-spi-x1_x2_x4}] 0]" >> flash$*.tcl
	echo "current_hw_cfgmem -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM [current_hw_device]]" >> flash$*.tcl
	echo "set_property PROGRAM.FILES [list \"$(FPGA_TOP)$*.mcs\"] [current_hw_cfgmem]" >> flash$*.tcl
	echo "set_property PROGRAM.PRM_FILES [list \"$(FPGA_TOP)$*.prm\"] [current_hw_cfgmem]" >> flash$*.tcl
	echo "set_property PROGRAM.ERASE 1 [current_hw_cfgmem]" >> flash$*.tcl
	echo "set_property PROGRAM.CFG_PROGRAM 1 [current_hw_cfgmem]" >> flash$*.tcl
	echo "set_property PROGRAM.VERIFY 1 [current_hw_cfgmem]" >> flash$*.tcl
	echo "set_property PROGRAM.CHECKSUM 0 [current_hw_cfgmem]" >> flash$*.tcl
	echo "set_property PROGRAM.ADDRESS_RANGE {use_file} [current_hw_cfgmem]" >> flash$*.tcl
	echo "set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [current_hw_cfgmem]" >> flash$*.tcl
	echo "create_hw_bitstream -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM_BITFILE [current_hw_device]]" >> flash$*.tcl
	echo "program_hw_devices [current_hw_device]" >> flash$*.tcl
	echo "refresh_hw_device [current_hw_device]" >> flash$*.tcl
	echo "program_hw_cfgmem -hw_cfgmem [current_hw_cfgmem]" >> flash$*.tcl
	echo "boot_hw_device [current_hw_device]" >> flash$*.tcl
	echo "exit" >> flash$*.tcl
	vivado -nojournal -nolog -mode batch -source flash$*.tcl
