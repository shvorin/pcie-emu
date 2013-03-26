// (C) 2001-2012 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera MegaCore Function License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


`timescale 1ps/1ps

import altera_xcvr_functions::*;

module sv_xcvr_avmm
  #(
    //PARAM_LIST_START
    parameter bonded_lanes        = 1,      // Number of lanes
    parameter bonding_master_ch   = 0,      // Indicates which channel is master
    parameter bonding_master_only = "-1",   // Indicates which channels are MASTER_ONLY. List of strings.
    parameter pma_reserved_ch     = "-1",   // Indicates which channels are reserved

	// PMA enables
    parameter rx_enable           = 0,      // Indicates whether this interface contains an rx channel.
    parameter tx_enable           = 0,      // Indicates whether this interface contains a tx channel
    parameter att_enable          = 0,      // Indicates whether this interface is an ATT channel
    // PCS enables
    parameter enable_10g_tx       = "false",// Is 10g TX PCS enabled?
    parameter enable_10g_rx       = "false",// Is 10g RX PCS enabled?
    parameter enable_8g_tx        = "false",// Is 8g TX PCS enabled?
    parameter enable_8g_rx        = "false",// Is 8g RX PCS enabled?
    // Services requests
    parameter request_adce_cont   = 0,      // Request ADCE continuous mode at startup
    parameter request_adce_single = 0,      // Request ADCE one-time mode at startup
    parameter request_adce_cancel = 0,      // Request ADCE to auto-start offset cancellation
    parameter request_dcd         = 1,      // Request Duty Cycle Distortion correction at startup
    parameter request_dfe         = 0,      // Request DFE at startup
    parameter request_vrc         = 0,      // Request Voltage Regulator Calibration at startup
    parameter request_offset      = 1       // Request RX Offset Cancellation at startup - defaults to enabled, only PCIE w/HIP should unset this
    //PARAM_LIST_END
  )  (
    //PORT_LIST_START
    // Reconfiguration signal bundles
    input   wire  [bonded_lanes*W_S5_RECONFIG_BUNDLE_TO_XCVR  -1:0] reconfig_to_xcvr,
    output  wire  [bonded_lanes*W_S5_RECONFIG_BUNDLE_FROM_XCVR-1:0] reconfig_from_xcvr,
    // Control inputs from PLD
    input   wire  [bonded_lanes-1     :0] in_pld_10g_rx_prbs_err_clr,
    input   wire  [bonded_lanes-1     :0] seriallpbken,   // 1 = enable serial loopback
    // PCS clocks
    input   wire  [bonded_lanes-1     :0] in_pld_8g_pld_rx_clk,   // 8g PCS RX clock
    input   wire  [bonded_lanes-1     :0] in_pld_10g_rx_pld_clk,  // 10g PCS RX clock
    // PCS resets
    input   wire  [bonded_lanes-1     :0] in_pld_8g_txurstpcs_n,  // 8g PCS TX reset
    input   wire  [bonded_lanes-1     :0] in_pld_8g_rxurstpcs_n,  // 8g PCS RX reset
    input   wire  [bonded_lanes-1     :0] in_pld_10g_tx_rst_n,    // 10g PCS TX reset
    input   wire  [bonded_lanes-1     :0] in_pld_10g_rx_rst_n,    // 10g PCS RX reset
    output  wire  [bonded_lanes-1     :0] out_pld_8g_txurstpcs_n, // 8g PCS TX reset
    output  wire  [bonded_lanes-1     :0] out_pld_8g_rxurstpcs_n, // 8g PCS RX reset
    output  wire  [bonded_lanes-1     :0] out_pld_10g_tx_rst_n,   // 10g PCS TX reset
    output  wire  [bonded_lanes-1     :0] out_pld_10g_rx_rst_n,   // 10g PCS RX reset

    // PMA resets
    input   wire  [bonded_lanes-1     :0] rx_crurstn,             // CDR analog reset (active low)
    input   wire  [bonded_lanes-1     :0] in_pld_rxpma_rstb_in,
    output  wire  [bonded_lanes-1     :0] out_rx_crurstn,         // CDR analog reset (active low)
    output  wire  [bonded_lanes-1     :0] out_pld_rxpma_rstb_in,

    // PCS data
    input   wire  [bonded_lanes*64-1  :0] out_pld_rx_data,        // PCS data output

    // Calibration clocks
    output  wire                          calclk, // Calibration clock driven from reconfig clock to aux block

    //calibration status
    output  wire  [bonded_lanes-1     :0] tx_cal_busy,
    output  wire  [bonded_lanes-1     :0] rx_cal_busy,
    // Reconfig controls
    output  wire  [bonded_lanes*5-1   :0] pma_eyemonitor,
    output  wire  [bonded_lanes-1     :0] pma_hardoccalen,
    output  wire  [bonded_lanes-1     :0] pma_adcecapture,
    output  wire  [bonded_lanes-1     :0] pma_adcestandby,
    output  wire  [bonded_lanes-1     :0] pma_seriallpbken,
    output  wire  [bonded_lanes-1     :0] pcs_10g_prbs_err_clr,
    // Reconfig status
    input   wire  [bonded_lanes-1     :0] pma_adaptdone,
    input   wire  [bonded_lanes-1     :0] pma_hardoccaldone,
    input   wire  [bonded_lanes-1     :0] pcs_8g_prbs_done,
    input   wire  [bonded_lanes-1     :0] pcs_8g_prbs_err,
    input   wire  [bonded_lanes-1     :0] pcs_10g_prbs_done,
    input   wire  [bonded_lanes-1     :0] pcs_10g_prbs_err,
    // ltr/ltd overrides
    input   wire  [bonded_lanes-1     :0] in_pld_ltr,
    input   wire  [bonded_lanes-1     :0] rx_ltd,
    output  wire  [bonded_lanes-1     :0] csr2pcs_ltr,
    output  wire  [bonded_lanes-1     :0] csr2pma_ltd,
    // Channel AVMM interface signals
    output  wire  [bonded_lanes-1     :0] chnl_avmm_clk,
    output  wire  [bonded_lanes-1     :0] chnl_avmm_rstn,
    output  wire  [bonded_lanes*16-1  :0] chnl_avmm_writedata,
    output  wire  [bonded_lanes*11-1  :0] chnl_avmm_address,
    output  wire  [bonded_lanes-1     :0] chnl_avmm_write,
    output  wire  [bonded_lanes-1     :0] chnl_avmm_read,
    output  wire  [bonded_lanes*2-1   :0] chnl_avmm_byteen,
    // PMA AVMM signals
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_tx_cgb,    // TX AVMM CGB readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_tx_ser,    // TX AVMM SER readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_tx_buf,    // TX AVMM BUF readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_att_tx_ser,// ATT TX AVMM SER readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_att_tx_buf,// ATT TX AVMM BUF readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_rx_ser,    // RX AVMM SER readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_rx_buf,    // RX AVMM BUF readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_rx_cdr,    // RX AVMM CDR readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_rx_mux,    // RX AVMM CDR MUX readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_att_rx_ser,// ATT RX AVMM SER readdata (16 for each lane)
    input   wire  [bonded_lanes*16-1  :0] pma_avmmreaddata_att_rx_buf,// ATT RX AVMM BUF readdata (16 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_tx_cgb,     // TX AVMM CGB blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_tx_ser,     // TX AVMM SER blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_tx_buf,     // TX AVMM BUF blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_att_tx_ser, // ATT TX AVMM SER blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_att_tx_buf, // ATT TX AVMM BUF blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_rx_ser,     // RX AVMM SER blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_rx_buf,     // RX AVMM BUF blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_rx_cdr,     // RX AVMM CDR blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_rx_mux,     // RX AVMM CDR MUX blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_att_rx_ser, // ATT RX AVMM SER blockselect (1 for each lane)
    input   wire  [bonded_lanes-1     :0] pma_blockselect_att_rx_buf, // ATT RX AVMM BUF blockselect (1 for each lane)
    // PCS AVMM signals
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_com_pcs_pma_if,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_com_pld_pcs_if,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_pcs10g_rx,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_pcs10g_tx,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_pcs8g_rx,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_pcs8g_tx,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_pcs_g3_rx,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_pcs_g3_tx,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_pipe12,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_pipe3,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_rx_pcs_pma_if,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_rx_pld_pcs_if,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_tx_pcs_pma_if,
    input   wire  [bonded_lanes*16-1  :0] avmmreaddata_tx_pld_pcs_if,
    input   wire  [bonded_lanes-1     :0] blockselect_com_pcs_pma_if,
    input   wire  [bonded_lanes-1     :0] blockselect_com_pld_pcs_if,
    input   wire  [bonded_lanes-1     :0] blockselect_pcs10g_rx,
    input   wire  [bonded_lanes-1     :0] blockselect_pcs10g_tx,
    input   wire  [bonded_lanes-1     :0] blockselect_pcs8g_rx,
    input   wire  [bonded_lanes-1     :0] blockselect_pcs8g_tx,
    input   wire  [bonded_lanes-1     :0] blockselect_pcs_g3_rx,
    input   wire  [bonded_lanes-1     :0] blockselect_pcs_g3_tx,
    input   wire  [bonded_lanes-1     :0] blockselect_pipe12,
    input   wire  [bonded_lanes-1     :0] blockselect_pipe3,
    input   wire  [bonded_lanes-1     :0] blockselect_rx_pcs_pma_if,
    input   wire  [bonded_lanes-1     :0] blockselect_rx_pld_pcs_if,
    input   wire  [bonded_lanes-1     :0] blockselect_tx_pcs_pma_if,
    input   wire  [bonded_lanes-1     :0] blockselect_tx_pld_pcs_if
    //PORT_LIST_END
  );

localparam  w_bundle_to_xcvr  = W_S5_RECONFIG_BUNDLE_TO_XCVR;
localparam  w_bundle_from_xcvr= W_S5_RECONFIG_BUNDLE_FROM_XCVR;


wire    [bonded_lanes-1:0]  pld_avmm_clk;
wire    [bonded_lanes-1:0]  pld_avmm_reset;
wire    [bonded_lanes-1:0]  w_interface_sel;
wire    [bonded_lanes-1:0]  w_ser_shift_load;
wire    [bonded_lanes-1:0]  w_10g_prbs_err_clr;
wire    [bonded_lanes-1:0]  w_seriallpbken;
wire    [bonded_lanes-1:0]  tx_digital_reset;
wire    [bonded_lanes-1:0]  rx_digital_reset;
wire    [bonded_lanes-1:0]  tx_rst_ovr;
wire    [bonded_lanes-1:0]  tx_digital_rst_n_val;
wire    [bonded_lanes-1:0]  rx_rst_ovr;
wire    [bonded_lanes-1:0]  rx_digital_rst_n_val;
wire    [bonded_lanes-1:0]  rx_analog_rst_n_val;
wire    [bonded_lanes-1:0]  rx_ltrltd_ovr;
wire    [bonded_lanes-1:0]  rx_ltr_val;
wire    [bonded_lanes-1:0]  rx_ltd_val;

wire    avmm_clk;   // Selected AVMM clock
wire    avmm_reset; // Selected AVMM reset
// Use first channel clock for all channels' calclk
assign  calclk    = pld_avmm_clk[0];
assign  avmm_clk  = pld_avmm_clk[0];
assign  avmm_reset= pld_avmm_reset[0];

// Allow PRBS clear to be driven either from reconfig or from core.
assign  pcs_10g_prbs_err_clr = in_pld_10g_rx_prbs_err_clr; //remove w_10g_prbs_err_clr to clean up timing violations
// Allow serial loopback to be driven either from reconfig or from core.
assign  pma_seriallpbken      = seriallpbken | w_seriallpbken;
assign  rx_digital_reset = (enable_10g_rx == "true") ? ~in_pld_10g_rx_rst_n  :
                           (enable_8g_rx  == "true") ? ~in_pld_8g_rxurstpcs_n:
                           1'b0; // Issue
assign  tx_digital_reset = (enable_10g_rx == "true") ? ~in_pld_10g_rx_rst_n  :
                           (enable_8g_rx  == "true") ? ~in_pld_8g_rxurstpcs_n:
                           1'b0; // Issue

// Reset overrides for calibration IP use
assign out_pld_8g_txurstpcs_n   = tx_rst_ovr ? tx_digital_rst_n_val : in_pld_8g_txurstpcs_n;  // 8g PCS TX reset
assign out_pld_8g_rxurstpcs_n   = rx_rst_ovr ? rx_digital_rst_n_val : in_pld_8g_rxurstpcs_n;  // 8g PCS RX reset
assign out_pld_10g_tx_rst_n     = tx_rst_ovr ? tx_digital_rst_n_val : in_pld_10g_tx_rst_n;    // 10g PCS TX reset
assign out_pld_10g_rx_rst_n     = rx_rst_ovr ? rx_digital_rst_n_val : in_pld_10g_rx_rst_n;    // 10g PCS RX reset
assign out_rx_crurstn           = rx_rst_ovr ? rx_analog_rst_n_val  : rx_crurstn;             // CDR analog reset (active low)
// LTR/LTD override for calibration IP use
assign csr2pcs_ltr = rx_ltrltd_ovr ? rx_ltr_val : in_pld_ltr;
assign csr2pma_ltd = rx_ltrltd_ovr ? rx_ltd_val : rx_ltd;
//Move the following mux into  the loop below to bypass for master only
//channels
//assign out_pld_rxpma_rstb_in    = rx_rst_ovr ? rx_analog_rst_n_val  : in_pld_rxpma_rstb_in;

initial begin
  // Validate parameters
  // PMA disabled and PCS enabled
  if(rx_enable == 0 && (enable_10g_rx == "true" || enable_8g_rx == "true"))
    $display("Error: [sv_xcvr_avmm] Enabling of 10g or 8g RX PCS without PMA not supported!");
  if(tx_enable == 0 && (enable_10g_tx == "true" || enable_8g_tx == "true"))
    $display("Error: [sv_xcvr_avmm] Enabling of 10g or 8g RX PCS without PMA not supported!");
end

  localparam [MAX_XCVR_CHANNELS-1:0] int_bonding_master_only_set = altera_xcvr_functions::map_numerical_is_in_legal_set(bonded_lanes,bonding_master_only);
  localparam [MAX_XCVR_CHANNELS-1:0] int_reserved_ch_set = altera_xcvr_functions::map_numerical_is_in_legal_set(bonded_lanes,pma_reserved_ch);

generate begin
  genvar ig;
  genvar jg;
  for(ig=0;ig<bonded_lanes;ig=ig+1) begin : avmm_interface_insts
    // Bundle <-> AVMM signals
    // Avalon MM native reconfiguration interfaces
    wire  [15:0]  pld_avmm_writedata; // Avalon DPRIO writedata
    wire  [11:0]  pld_avmm_address;   // Avalon DPRIO address
    wire          pld_avmm_write;     // Avalon DPRIO write
    wire          pld_avmm_read;      // Avalon DPRIO read
    wire  [15:0]  pld_avmm_readdata;  // Avalon readdata to core
    wire          csr_avmm_n_sel;     // Select Soft CSR or DPRIO
    reg           csr_avmm_n_sel_r;   // Select Soft CSR or DPRIO (read)
    // Soft CSR Avalon signals
    wire          csr_write;          // Avalon write to Soft CSR
    wire          csr_read;           // Avalon read to Soft CSR
    wire  [15:0]  csr_readdata;       // Avalon readdata from Soft CSR
    // DPRIO Avalon signals
    wire          avmm_write;         // Avalon write to DPRIO
    wire          avmm_read;          // Avalon read to DPRIO
    wire  [15:0]  avmm_readdata;      // Avalon readdata from DPRIO
    // Testbus
    wire  [23:0]  w_pmatestbus;
    wire  [11:0]  w_pmatestbussel;
    // DCD <-> CSR signals
    wire          dcd_req;
    wire          dcd_ack;
    wire  [7:0]   dcd_sum_a;
    wire  [7:0]   dcd_sum_b;

    localparam is_master_only = (((int_bonding_master_only_set >> ig) & 1'b1) == 1) ? 1 : 0;
    localparam is_reserved    = (((int_reserved_ch_set >> ig) & 1'b1) == 1) ? 1 : 0;

    //if this channel is a bonding master channel or a reserved channel, do
    //not add in an override mux, to allow the fitter to see proper
    //connectivity to the PCIe HIP. These channels are not cailibrated, so
    //this is OK.
    assign out_pld_rxpma_rstb_in[ig]    = ( is_master_only == 1 || is_reserved == 1) ? in_pld_rxpma_rstb_in[ig] :
                                                                                       rx_rst_ovr[ig] ? rx_analog_rst_n_val[ig]  :
                                                                                       in_pld_rxpma_rstb_in[ig];

    // Extract and compose bundled signals
    sv_reconfig_bundle_to_xcvr #(
      .native_ifs         (1)     // number of native reconfig interfaces
    ) sv_reconfig_bundle_to_xcvr_inst(
      // bundled reconfig buses
      .reconfig_to_xcvr         (reconfig_to_xcvr  [ig*w_bundle_to_xcvr  +:w_bundle_to_xcvr  ] ),  // all inputs from reconfig block to native xcvr reconfig ports
      .reconfig_from_xcvr       (reconfig_from_xcvr[ig*w_bundle_from_xcvr+:w_bundle_from_xcvr] ),  // all outputs from native xcvr reconfig ports to reconfig block
      // native reconfig sources
      .native_reconfig_readdata (pld_avmm_readdata      ),  // Avalon DPRIO readdata
      .pif_testbus              (w_pmatestbus           ),

      // Calibration status
      .tx_cal_busy              (tx_cal_busy        [ig]),
      .rx_cal_busy              (rx_cal_busy        [ig]),

      // native reconfig sinks
      .native_reconfig_clk      (pld_avmm_clk       [ig]),
      .native_reconfig_reset    (pld_avmm_reset     [ig]),
      .native_reconfig_writedata(pld_avmm_writedata     ),
      .native_reconfig_address  (pld_avmm_address       ),
      .native_reconfig_write    (pld_avmm_write         ),
      .native_reconfig_read     (pld_avmm_read          ),
      .pif_testbus_sel          (w_pmatestbussel        ), // 4 bits per physical channel
      .pif_interface_sel        (w_interface_sel    [ig]),
      .pif_ser_shift_load       (w_ser_shift_load   [ig])
    );

    // Only instantiate avmm block if this is not a bonding master only channel
    // If the lane is master only lane or empty channel, do not stamp out the AVMM
      if((is_master_only != 1) && (is_reserved != 1)) begin
      // DPRIO signals
      wire  [90-1:0]    chnl_avmm_blockselect;
      wire  [15:0]      chnl_avmm_readdata [0:(90-1)];
      wire  [90*16-1:0] chnl_avmm_readdatabus;

      for(jg = 0; jg < 90; jg = jg + 1) begin:avmm_assigns
        assign  chnl_avmm_readdatabus[jg*16+:16] = chnl_avmm_readdata[jg];
        assign  {chnl_avmm_readdata[jg],chnl_avmm_blockselect[jg]} =
          // TX PMA connections
          (jg ==  0) ? {pma_avmmreaddata_tx_ser     [ig*16+:16],pma_blockselect_tx_ser    [ig]} :
          (jg ==  1) ? {pma_avmmreaddata_tx_cgb     [ig*16+:16],pma_blockselect_tx_cgb    [ig]} :
          (jg ==  2) ? {pma_avmmreaddata_tx_buf     [ig*16+:16],pma_blockselect_tx_buf    [ig]} :
          // RX PMA connections
          (jg ==  3) ? {pma_avmmreaddata_rx_ser     [ig*16+:16],pma_blockselect_rx_ser    [ig]} :
          (jg ==  4) ? {pma_avmmreaddata_rx_buf     [ig*16+:16],pma_blockselect_rx_buf    [ig]} :
          (jg ==  5) ? {pma_avmmreaddata_rx_cdr     [ig*16+:16],pma_blockselect_rx_cdr    [ig]} :
          (jg ==  6) ? {pma_avmmreaddata_rx_mux     [ig*16+:16],pma_blockselect_rx_mux    [ig]} :
          // PCS connections
          (jg == 10) ? {avmmreaddata_pcs8g_rx       [ig*16+:16],blockselect_pcs8g_rx      [ig]} :
          (jg == 11) ? {avmmreaddata_pipe12         [ig*16+:16],blockselect_pipe12        [ig]} :
          (jg == 12) ? {avmmreaddata_pcs8g_tx       [ig*16+:16],blockselect_pcs8g_tx      [ig]} :
          (jg == 13) ? {avmmreaddata_pcs10g_rx      [ig*16+:16],blockselect_pcs10g_rx     [ig]} :
          (jg == 14) ? {avmmreaddata_pcs10g_tx      [ig*16+:16],blockselect_pcs10g_tx     [ig]} :
          (jg == 15) ? {avmmreaddata_pipe3          [ig*16+:16],blockselect_pipe3         [ig]} :
          (jg == 16) ? {avmmreaddata_pcs_g3_tx      [ig*16+:16],blockselect_pcs_g3_tx     [ig]} :
          (jg == 17) ? {avmmreaddata_pcs_g3_rx      [ig*16+:16],blockselect_pcs_g3_rx     [ig]} :
          (jg == 18) ? {avmmreaddata_com_pld_pcs_if [ig*16+:16],blockselect_com_pld_pcs_if[ig]} :
          (jg == 19) ? {avmmreaddata_tx_pld_pcs_if  [ig*16+:16],blockselect_tx_pld_pcs_if [ig]} :
          (jg == 20) ? {avmmreaddata_rx_pld_pcs_if  [ig*16+:16],blockselect_rx_pld_pcs_if [ig]} :
          (jg == 21) ? {avmmreaddata_com_pcs_pma_if [ig*16+:16],blockselect_com_pcs_pma_if[ig]} :
          (jg == 22) ? {avmmreaddata_tx_pcs_pma_if  [ig*16+:16],blockselect_tx_pcs_pma_if [ig]} :
          (jg == 23) ? {avmmreaddata_rx_pcs_pma_if  [ig*16+:16],blockselect_rx_pcs_pma_if [ig]} :
          //ATT TX PMA connections
          (jg == 81) ? {pma_avmmreaddata_att_tx_ser [ig*16+:16],pma_blockselect_att_tx_ser[ig]} :
          (jg == 82) ? {pma_avmmreaddata_att_tx_buf [ig*16+:16],pma_blockselect_att_tx_buf[ig]} :
          //ATT RX PMA connections
          (jg == 84) ? {pma_avmmreaddata_att_rx_buf [ig*16+:16],pma_blockselect_att_rx_buf[ig]} :
          (jg == 85) ? {pma_avmmreaddata_att_rx_ser [ig*16+:16],pma_blockselect_att_rx_ser[ig]} :
          {16'd0,1'b0};
      end

      // Mux between hard and soft reconfig registers
      assign  csr_avmm_n_sel    = pld_avmm_address[11];
      assign  pld_avmm_readdata = csr_avmm_n_sel_r ? csr_readdata : avmm_readdata;
      assign  avmm_write        = pld_avmm_write & ~csr_avmm_n_sel;
      assign  avmm_read         = pld_avmm_read  & ~csr_avmm_n_sel;
      assign  csr_write         = pld_avmm_write & csr_avmm_n_sel;
      assign  csr_read          = pld_avmm_read  & csr_avmm_n_sel;

      always @(posedge avmm_clk or posedge avmm_reset)
        if(avmm_reset)  csr_avmm_n_sel_r  <= 1'b0;
        else            csr_avmm_n_sel_r  <= csr_avmm_n_sel;

      // AVMM atom
      stratixv_hssi_avmm_interface stratixv_hssi_avmm_interface_inst
      (
        .avmmrstn           (1'b1                             ),
        .avmmclk            (avmm_clk                         ),  // Use first channel clock for all channels
        .avmmwrite          (avmm_write                       ),
        .avmmread           (avmm_read                        ),
        .avmmbyteen         (2'b11                            ),
        .avmmaddress        (pld_avmm_address     [10:0]      ),
        .avmmwritedata      (pld_avmm_writedata               ),
        .avmmreaddata       (avmm_readdata                    ),


        .blockselect        (chnl_avmm_blockselect            ),
        .readdatachnl       (chnl_avmm_readdatabus            ),
        .clkchnl            (chnl_avmm_clk        [ig]        ),
        .rstnchnl           (chnl_avmm_rstn       [ig]        ),
        .writedatachnl      (chnl_avmm_writedata  [ig*16+:16] ),
        .regaddrchnl        (chnl_avmm_address    [ig*11+:11] ),
        .writechnl          (chnl_avmm_write      [ig]        ),
        .readchnl           (chnl_avmm_read       [ig]        ),
        .byteenchnl         (chnl_avmm_byteen     [ig*2+:2]   ),

        // The following ports belong to pm_tst_mux blocks in the PMA
        .pmatestbus         (w_pmatestbus                     ),
        .pmatestbussel      (w_pmatestbussel                  ),

        //
        .scanmoden          (1'b1                             ),  // Not used
        .scanshiftn         (1'b1                             ),  // Not used
        .sershiftload       (w_ser_shift_load[0]              ),  // Use first channel signal
        .interfacesel       (w_interface_sel [0]              ),  // Use first channel signal

        .refclkdig          (/*unused*/ ),
        .avmmreservedin     (/*unused*/ ),

        .avmmreservedout    (/*unused*/ ),
        .dpriorstntop       (/*unused*/ ),
        .dprioclktop        (/*unused*/ ),
        .mdiodistopchnl     (/*unused*/ ),
        .dpriorstnmid       (/*unused*/ ),
        .dprioclkmid        (/*unused*/ ),
        .mdiodismidchnl     (/*unused*/ ),
        .dpriorstnbot       (/*unused*/ ),
        .dprioclkbot        (/*unused*/ ),
        .mdiodisbotchnl     (/*unused*/ ),
        .dpriotestsitopchnl (/*unused*/ ),
        .dpriotestsimidchnl (/*unused*/ ),
        .dpriotestsibotchnl (/*unused*/ )
      );

      // Soft reconfig CSR
      sv_xcvr_avmm_csr #(
          .pll_type   (0          ),  // 0-None,1-CMU,2-LC/ATX,3-fPLL
          .rx_enable  (rx_enable  ),  // Indicates whether this interface contains an rx channel.
          .tx_enable  (tx_enable  ),  // Indicates whether this interface contains a tx channel
          .att_enable (att_enable ),  // Indicates whether this interface is an ATT channel
          // Service request parameters
          .request_adce_cont  (request_adce_cont  ),      // Request ADCE continuous mode at startup
          .request_adce_single(request_adce_single),      // Request ADCE one-time mode at startup
          .request_adce_cancel(request_adce_cancel),      // Request ADCE to auto-start offset cancellation
          .request_dcd        (request_dcd        ),      // Request Duty Cycle Distortion correction at startup
          .request_dfe        (request_dfe        ),      // Request DFE at startup
          .request_vrc        (request_vrc        ),      // Request Voltage Regulator Calibration at startup
          .request_offset     (request_offset     )       // Request RX Offset Cancellation at startup
        ) sv_xcvr_avmm_csr_inst (
        // Avalon interface
        .av_clk               (avmm_clk               ),
        .av_reset             (avmm_reset             ),
        .av_writedata         (pld_avmm_writedata     ),
        .av_address           (pld_avmm_address[3:0]  ),
        .av_write             (csr_write              ),
        .av_read              (csr_read               ),
        .av_readdata          (csr_readdata           ),
        // ADCE
        .adce_done            (pma_adaptdone      [ig]),
        .adce_capture         (pma_adcecapture    [ig]),
        .adce_standby         (pma_adcestandby    [ig]),
        // Offset Cancellation
        .hardoccaldone        (pma_hardoccaldone  [ig]),
        .hardoccalen          (pma_hardoccalen    [ig]),
        // PRBS
        .pcs_8g_prbs_done     (pcs_8g_prbs_done   [ig]),
        .pcs_8g_prbs_err      (pcs_8g_prbs_err    [ig]),
        .pcs_10g_prbs_done    (pcs_10g_prbs_done  [ig]),
        .pcs_10g_prbs_err     (pcs_10g_prbs_err   [ig]),
        .pcs_10g_prbs_err_clr (w_10g_prbs_err_clr [ig]),
        // DCD
        .dcd_ack              (dcd_ack                ),
        .dcd_sum_a            (dcd_sum_a              ),
        .dcd_sum_b            (dcd_sum_b              ),
        .dcd_req              (dcd_req                ),
        // SLPBK
        .seriallpbken         (w_seriallpbken     [ig]),
        // Channel STATUS
        .stat_pll_locked      (1'b0                   ),
        .stat_tx_digital_reset(tx_digital_reset   [ig]),
        .stat_rx_digital_reset(rx_digital_reset   [ig]),
        // Reset overrides
        .tx_rst_ovr           (tx_rst_ovr          [ig]),
        .tx_digital_rst_n_val (tx_digital_rst_n_val[ig]),
        .rx_rst_ovr           (rx_rst_ovr          [ig]),
        .rx_digital_rst_n_val (rx_digital_rst_n_val[ig]),
        .rx_analog_rst_n_val  (rx_analog_rst_n_val [ig]),
	// ltr/ltd overrides
        .rx_ltrltd_ovr        (rx_ltrltd_ovr       [ig]),
        .rx_ltr_val           (rx_ltr_val          [ig]),
        .rx_ltd_val           (rx_ltd_val          [ig]),
        // EYEMON
        .eyemonitor           (pma_eyemonitor[ig*5+:5])
      );

// DCD soft-IP is no longer used
// Keep this code just in case we need to turn it back on
      // Enable DCD accumulators only if RX is enabled
//      if(rx_enable) begin
//        wire  dcd_clk;
//
//        assign  dcd_clk = (enable_10g_rx == "true") ? in_pld_10g_rx_pld_clk[ig] :
//                          (enable_8g_rx  == "true") ? in_pld_8g_pld_rx_clk [ig] :
//                          1'b0;
//
//        // Use dprio reset for DCD reset
//        sv_xcvr_avmm_dcd sv_xcvr_avmm_dcd_inst(
//          .clk            (dcd_clk                  ),
//          .req            (dcd_req                  ),
//          .ack            (dcd_ack                  ),
//          .deserial_data  (out_pld_rx_data[ig*64+:8]),
//          .acc_a          (dcd_sum_a                ),
//          .acc_b          (dcd_sum_b                )
//        );
//      end else begin
        assign  dcd_ack   = &{1'b0,dcd_req,out_pld_rx_data[ig*64+:64]}; // Warning avoidance
        assign  dcd_sum_a = 8'd0;
        assign  dcd_sum_b = 8'd0;
//      end

  end else begin
    assign  chnl_avmm_clk       [ig]        = 1'b0;
    assign  chnl_avmm_rstn      [ig]        = 1'b1;
    assign  chnl_avmm_writedata [ig*16+:16] = 16'd0;
    assign  chnl_avmm_address   [ig*11+:11] = 11'd0;
    assign  chnl_avmm_write     [ig]        = 1'b0;
    assign  chnl_avmm_read      [ig]        = 1'b0;
    assign  chnl_avmm_byteen    [ig* 2+: 2] = 1'b0;
    assign  w_seriallpbken      [ig]        = 1'b0;

    assign  tx_rst_ovr          [ig]        = 1'b0;
    assign  tx_digital_rst_n_val[ig]        = 1'b0;
    assign  rx_rst_ovr          [ig]        = 1'b0;
    assign  rx_digital_rst_n_val[ig]        = 1'b0;
    assign  rx_analog_rst_n_val [ig]        = 1'b0;
  end
  end
end
endgenerate

endmodule
