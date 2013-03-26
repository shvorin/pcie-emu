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


// /**
//  * This Verilog HDL file is used for simulation and synthesis in
//  * the chaining DMA design example. It retrieves DMA read or write
//  * descriptor from the root port memory, and store it in a descriptor FIFO.
//  */
// synthesis translate_off
`timescale 1 ps / 1 ps
`define PCIE_SIM         TRUE
// synthesis translate_on
//-----------------------------------------------------------------------------
// TLP Packet constant
`define TLP_FMT_4DW_W        2'b11    // TLP FMT field  -> 64 bits Write
`define TLP_FMT_3DW_W        2'b10    // TLP FMT field  -> 32 bits Write
`define TLP_FMT_4DW_R        2'b01    // TLP FMT field  -> 64 bits Read
`define TLP_FMT_3DW_R        2'b00    // TLP FMT field  -> 32 bits Read

`define TLP_FMT_CPL          2'b00    // TLP FMT field  -> Completion w/o data
`define TLP_FMT_CPLD         2'b10    // TLP FMT field  -> Completion with data

`define TLP_TYPE_WRITE       5'b00000 // TLP Type field -> write
`define TLP_TYPE_READ        5'b00000 // TLP Type field -> read
`define TLP_TYPE_READ_LOCKED 5'b00001 // TLP Type field -> read_lock
`define TLP_TYPE_CPLD        5'b01010 // TLP Type field -> Completion with data
`define TLP_TYPE_IO          5'b00010 // TLP Type field -> IO

`define TLP_TC_DEFAULT       3'b000   // Default TC of the TLP
`define TLP_TD_DEFAULT       1'b0     // Default TD of the TLP
`define TLP_EP_DEFAULT       1'b0     // Default EP of the TLP
`define TLP_ATTR_DEFAULT     2'b0     // Default EP of the TLP

`define RESERVED_1BIT        1'b0     // reserved bit on 1 bit
`define RESERVED_2BIT        2'b00    // reserved bit on 1 bit
`define RESERVED_3BIT        3'b000   // reserved bit on 1 bit
`define RESERVED_4BIT        4'b0000  // reserved bit on 1 bit

`define EP_ADDR_READ_OFFSET  16
`define TRANSACTION_ID       3'b000

`define ZERO_QWORD           64'h0000_0000_0000_0000
`define ZERO_DWORD           32'h0000_0000
`define ZERO_WORD            16'h0000
`define ZERO_BYTE            8'h00

`define ONE_QWORD            64'h0000_0000_0000_0001
`define ONE_DWORD            32'h0000_0001
`define ONE_WORD             16'h0001
`define ONE_BYTE             8'h01

`define MINUS_ONE_QWORD      64'hFFFF_FFFF_FFFF_FFFF
`define MINUS_ONE_DWORD      32'hFFFF_FFFF
`define MINUS_ONE_WORD       16'hFFFF
`define MINUS_ONE_BYTE       8'hFF

`define DIRECTION_WRITE      1
`define DIRECTION_READ       0

// synthesis verilog_input_version verilog_2001
// turn off superfluous verilog processor warnings
// altera message_level Level1
// altera message_off 10034 10035 10036 10037 10230 10240 10030
//-----------------------------------------------------------------------------
// Title         : DMA Descriptor module (altpcierd_dma_descriptor)
// Project       : PCI Express MegaCore function
//-----------------------------------------------------------------------------
// File          : altpcierd_dma_descriptor.v
// Author        : Altera Corporation
//-----------------------------------------------------------------------------
// Each Descriptor uses 2 QWORD such as
//       if (cstate==DT_FIFO_RD_QW0)
//   QW0      ep_addr <= dt_fifo_q[63:32]; length <= dt_fifo_q[63:32];
//   QW1      RC_MSB  <= dt_fifo_q[31:0];  RC_LSB <= dt_fifo_q[63:32];
//-----------------------------------------------------------------------------
module altpcierd_dma_descriptor  # (
      parameter RC_64BITS_ADDR    = 0,
      parameter MAX_NUMTAG        = 32,
      parameter DIRECTION         = `DIRECTION_WRITE,
      parameter FIFO_DEPTH        = 256,
      parameter FIFO_WIDTHU       = 8,
      parameter FIFO_WIDTH        = 64,
      parameter TXCRED_WIDTH      = 22,
      parameter AVALON_ST_128     = 0,
      parameter USE_CREDIT_CTRL   = 1,
      parameter INTENDED_DEVICE_FAMILY = "Cyclone IV GX",
      parameter  CDMA_AST_RXWS_LATENCY = 2                 // response time of rx_data to rx_ws
   )
   (
      input      [15:0] dt_rc_last     ,
      input             dt_rc_last_sync,
      input      [15:0] dt_size        ,
      input      [63:0] dt_base_rc     ,
      input             dt_3dw_rcadd   ,

      input          dt_fifo_rdreq,
      output  reg    dt_fifo_empty,
      output  [FIFO_WIDTH-1:0] dt_fifo_q,
      output [12:0]  dt_fifo_q_4K_bound,

      input  [15:0] cfg_maxrdreq_dw ,

      input          tx_sel  ,
      output         tx_ready,
      output         tx_busy ,

      input [TXCRED_WIDTH-1:0] tx_cred,
      input          tx_have_creds,

      output         tx_req  ,
      input          tx_ack  ,
      output [127:0] tx_desc ,
      input          tx_ws   ,
      input [15:0]   rx_buffer_cpl_max_dw,  // specify the maximum amount of data available in RX Buffer for a given MRd

      input          rx_req  ,
      output reg     rx_ack  ,
      input [135:0]  rx_desc ,
      input [127:0]  rx_data ,
      input          rx_dv   ,
      input          rx_dfr  ,

      input          init    ,
      output  reg    descriptor_mrd_cycle,

      output [3:0]   dma_sm ,
      output reg     cpl_pending,

      input          clk_in  ,
      input          rstn
   );

   // descriptor module state machine
   localparam IDLE_ST         =0,
              IDLE_NEW_RCLAST =1,
              TX_LENGTH       =2,
              IS_TX_READY     =3,
              START_TX        =4,
              MRD_TX_REQ      =5,
              MRD_TX_ACK      =6,
              WAIT_FOR_CPLD   =7,
              CPLD_ACK        =8,
              CPLD_DATA       =9,
              DONE_ST         =10;

   localparam FIFO_WIDTH_DWORD = (AVALON_ST_128==1)?4:2;
   localparam DESCRIPTOR_PER_FIFO_WIDTH = (AVALON_ST_128==1)?0:1;
   localparam FIFO_NUMDW       = FIFO_WIDTH_DWORD*FIFO_DEPTH;

   reg [3:0] cstate;
   reg [3:0] nstate;
   wire      descr_tag;

   // Register which contains the value of the last completed DMA transfer
   reg  [15:0] dt_addr_offset;
   wire [31:0] dt_addr_offset_dw_ext;
   wire [63:0] dt_addr_offset_qw_ext;
   wire [63:0] tx_desc_addr_pipe;
   reg         addrval_32b      ; //indicates taht a 4DW header has a 32-bit address
                                  //where tx_desc_adddr[63:32]==32'h

   wire[FIFO_WIDTH+12 : 0] dt_fifo_q_int;

   wire dt_fifo_sclr;
   wire dt_fifo_full;
   reg dt_fifo_tx_ready;
   wire rx_buffer_cpl_ready;
   wire scfifo_empty;
   wire [FIFO_WIDTHU-1:0] dt_fifo_usedw;
   wire [FIFO_WIDTH-1:0] dt_fifo_data;
   wire [FIFO_WIDTH+12:0] dt_fifo_data_int;
   wire dt_fifo_wrreq;

   wire [3:0] tx_lbe_d;
   wire [3:0] tx_fbe_d;

   wire [4:0]  tlp_rx_type  ;
   wire [1:0]  tlp_rx_fmt   ;

   wire [7:0] tx_tag_descriptor_wire;



   reg  [31:0] tx_desc_3DW     ;
   reg  [63:0] tx_desc_4DW     ;
   reg  [63:0] tx_desc_addr    ;
   reg  [31:0] tx_desc_addr_3dw_pipe    ;
   reg  [9:0]  dt_fifo_cnt;
   reg         dt_fifo_cnt_eq_zero;
   reg  [9:0]  tx_length_dw    ;
   wire [15:0] tx_length_dw_ext16   ;
   reg  [9:0]  tx_length_dw_md ;
   wire [9:0]  tx_length_dw_max;

   reg  [15:0] tx_length_byte    ;
   reg  [15:0] cfg_maxrdreq_dw_fifo_size ;
   reg  [15:0] dt_rc_last_size_dw ; // total number of descriptor for a given RC LAst
   reg         loop_dma;

   // control signals used for pipelined configuration
   wire rx_ack_descrpt_ena ;  // Set when valid descriptor rx_desc , tag OK and TLP=CLPD
   wire rx_ack_descrpt_ena_p0; // same as rx_ack_descrpt_ena, but valid on rx_req_p0 and not rx_req_p1
   reg valid_rx_dv_descriptor_cpld;  // Set when valid descriptor rx_desc , tag OK and TLP=CLPD
   reg  rx_ack_pipe;
   reg  rx_cpld_data_on_rx_req_p0;
   reg rx_req_reg;
   reg rx_req_p1 ;
   wire rx_req_p0;
   reg  descr_tag_reg;

   reg  tx_cred_non_posted_header_valid;

   // pipelines for performance
   reg dt_rc_last_size_dw_gt_cfg_maxrdreq_dw_fifo_size;
   reg [15:0] dt_rc_last_size_dw_minus_cfg_maxrdreq_dw_fifo_size;

   always @ (posedge clk_in) begin
      if (init==1'b1) begin
         rx_req_reg <= 1'b0;
         rx_req_p1  <= 1'b0;
      end
      else begin
         rx_req_reg <= rx_req;
         rx_req_p1  <= rx_req_p0;
      end
   end
   assign rx_req_p0 = rx_req & ~rx_req_reg;

   always @ (posedge clk_in) begin
      if (cfg_maxrdreq_dw>FIFO_DEPTH)
         cfg_maxrdreq_dw_fifo_size <= FIFO_DEPTH;
      else
         cfg_maxrdreq_dw_fifo_size <= cfg_maxrdreq_dw;
   end

   // RX assignments
   assign tlp_rx_fmt       = rx_desc[126:125];
   assign tlp_rx_type      = rx_desc[124:120];
   assign dma_sm           = cstate;

   assign tx_tag_descriptor_wire = (DIRECTION==`DIRECTION_WRITE)?8'h1:8'h0;
   assign descr_tag = (rx_desc[47:40]==tx_tag_descriptor_wire)?1'b1:1'b0;

   always @ (posedge clk_in) begin
      descr_tag_reg <= descr_tag;    // rx_desc is valid on rx_req_p0, used on rx_req_p1
   end

   // Check if credits are available for Non-Posted Header (MRd)
   // if (USE_CREDIT_CTRL==0)

   // Check for non posted header credit
   generate begin
      if (TXCRED_WIDTH>36) begin
         always @ (posedge clk_in) begin
            if ((init==1'b1) || (USE_CREDIT_CTRL==0))
               tx_cred_non_posted_header_valid<=1'b1;
            else begin
               if  ((tx_cred[27:20]>0)||(tx_cred[62]==1))
                  tx_cred_non_posted_header_valid <= 1'b1;
               else
                  tx_cred_non_posted_header_valid <= 1'b0;
            end
         end
      end
   end
   endgenerate

   generate begin
      if (TXCRED_WIDTH<37) begin
         always @ (*) begin
             tx_cred_non_posted_header_valid = (USE_CREDIT_CTRL==0) ? 1'b1 : tx_have_creds;
         end
      end
   end
   endgenerate

   always @ (posedge clk_in) begin
      if (init==1'b1)
        dt_fifo_tx_ready <= 1'b0;
      else if (cstate==IS_TX_READY) begin
         if (dt_fifo_cnt+tx_length_dw<FIFO_NUMDW)
            dt_fifo_tx_ready <= 1'b1;
          else
            dt_fifo_tx_ready <= 1'b0;
      end
   end

   assign tx_length_dw_ext16[9:0] = tx_length_dw;
   assign tx_length_dw_ext16[15:10] = 0;

   assign rx_buffer_cpl_ready = (tx_length_dw_ext16>rx_buffer_cpl_max_dw)?1'b0:1'b1;

   // TX assignments
   assign tx_req        = (cstate == MRD_TX_REQ) ?1'b1:1'b0;

   // TX descriptor arbitration
   assign tx_busy       =(cstate==MRD_TX_REQ)?1'b1:1'b0;
   assign tx_ready      = ((cstate==START_TX) && (dt_fifo_tx_ready==1'b1) &&
                           (rx_buffer_cpl_ready==1'b1)
                            && (tx_cred_non_posted_header_valid==1'b1)) ?1'b1:1'b0;

   assign tx_lbe_d      = 4'hF;
   assign tx_fbe_d      = 4'hF;

   assign tx_desc[127]     = `RESERVED_1BIT     ;//Set at top level readability
   // 64 vs 32 bits tx_desc[126:125] cmd

   assign tx_desc[126:125] =  ((RC_64BITS_ADDR==0)||(dt_3dw_rcadd==1'b1)||(addrval_32b==1'b1))?
                              `TLP_FMT_3DW_R:`TLP_FMT_4DW_R;
   assign tx_desc[124:120] = `TLP_TYPE_READ     ;
   assign tx_desc[119]     = `RESERVED_1BIT     ;
   assign tx_desc[118:116] = `TLP_TC_DEFAULT    ;
   assign tx_desc[115:112] = `RESERVED_4BIT     ;
   assign tx_desc[111]     = `TLP_TD_DEFAULT    ;
   assign tx_desc[110]     = `TLP_EP_DEFAULT    ;
   assign tx_desc[109:108] = `TLP_ATTR_DEFAULT  ;
   assign tx_desc[107:106] = `RESERVED_2BIT     ;
   assign tx_desc[105:96]  = tx_length_dw       ;
   assign tx_desc[95:80]   = `ZERO_WORD         ;//Requester ID set at top level
   assign tx_desc[79:72]   = tx_tag_descriptor_wire;
   assign tx_desc[71:64]   = {tx_lbe_d,tx_fbe_d};
   assign tx_desc[63:0]    = ((RC_64BITS_ADDR==0)||(dt_3dw_rcadd==1'b1)||(addrval_32b==1'b0))?
                              tx_desc_addr:{tx_desc_addr[31:0],32'h0};

   // Each descriptor uses 4 DWORD
   always @ (posedge clk_in) begin
      if ((dt_fifo_empty==1'b1)&&(dt_rc_last_sync==1'b1))
         loop_dma <= 1'b1;
      else
         loop_dma <= 1'b0;
   end


   always @ (posedge clk_in) begin
      dt_rc_last_size_dw_gt_cfg_maxrdreq_dw_fifo_size    <= dt_rc_last_size_dw > cfg_maxrdreq_dw_fifo_size;
      dt_rc_last_size_dw_minus_cfg_maxrdreq_dw_fifo_size <= dt_rc_last_size_dw - cfg_maxrdreq_dw_fifo_size;
      if (cstate==IDLE_ST) begin
         dt_rc_last_size_dw[1:0] <= 0;
         dt_rc_last_size_dw[15:2] <= dt_rc_last[13:0]+1;
      end
      else begin
         if ((cstate==CPLD_DATA)&&(tx_length_dw==0)&&            // transition to DONE state
                    (rx_dv==1'b0)) begin
            if (dt_rc_last_size_dw_gt_cfg_maxrdreq_dw_fifo_size)
                dt_rc_last_size_dw <= dt_rc_last_size_dw_minus_cfg_maxrdreq_dw_fifo_size;
            else
                dt_rc_last_size_dw <= 0;
          end
      end
   end

   always @ (posedge clk_in) begin
      if (init==1'b1)
         dt_fifo_cnt <= 0;
      else if ((dt_fifo_rdreq==1'b1)&&(dt_fifo_cnt_eq_zero==0)
                && (scfifo_empty==1'b0)) begin
         if (cstate==MRD_TX_ACK)
            dt_fifo_cnt <= dt_fifo_cnt+tx_length_dw_md;
         else
            dt_fifo_cnt <= dt_fifo_cnt-FIFO_WIDTH_DWORD;
      end
      else if (cstate==MRD_TX_ACK)
         dt_fifo_cnt <= dt_fifo_cnt+tx_length_dw;
   end

   always @ (posedge clk_in) begin
      if (init==1'b1)
         dt_fifo_cnt_eq_zero <= 1'b1;
      else if ((dt_fifo_rdreq==1'b1)&&(dt_fifo_cnt_eq_zero==0)
                && (scfifo_empty==1'b0)) begin
         if (cstate==MRD_TX_ACK) begin
            if (dt_fifo_cnt+tx_length_dw_md>0)
               dt_fifo_cnt_eq_zero <= 1'b0;
            else
               dt_fifo_cnt_eq_zero <= 1'b1;
         end
         else  begin
            if (dt_fifo_cnt-FIFO_WIDTH_DWORD>0)
               dt_fifo_cnt_eq_zero <= 1'b0;
            else
               dt_fifo_cnt_eq_zero <= 1'b1;
         end
      end
      else if (cstate==MRD_TX_ACK)  begin
         if (dt_fifo_cnt+tx_length_dw>0)
            dt_fifo_cnt_eq_zero <= 1'b0;
         else
            dt_fifo_cnt_eq_zero <= 1'b1;
      end
   end

   always @ (posedge clk_in) begin
      if ((cstate==IDLE_ST)||(cstate==DONE_ST))
         tx_length_dw <= 0;
      else begin
         if (cstate==TX_LENGTH) begin
            if (dt_rc_last_size_dw>cfg_maxrdreq_dw_fifo_size)
               tx_length_dw[9:0] <= cfg_maxrdreq_dw_fifo_size[9:0];
            else
               tx_length_dw[9:0] <= dt_rc_last_size_dw[9:0];
         end
         else if (((cstate==CPLD_ACK)||(cstate==CPLD_DATA) ||
                  ((cstate==WAIT_FOR_CPLD)&& (rx_ack_descrpt_ena==1'b1))) &&
                   (rx_dv==1'b1) && (tx_length_dw>0)) begin
            if (tx_length_dw==1)
               tx_length_dw <= 0;
            else
               tx_length_dw <= tx_length_dw-FIFO_WIDTH_DWORD;
         end
      end
   end

   assign tx_length_dw_max[9:0] =
                              (dt_rc_last_size_dw>cfg_maxrdreq_dw_fifo_size) ?
                        cfg_maxrdreq_dw_fifo_size[9:0]:dt_rc_last_size_dw[9:0];

   always @ (posedge clk_in) begin
      if ((cstate==IDLE_ST)||(cstate==DONE_ST))
         tx_length_dw_md <= 0;
      else begin
         if (cstate==TX_LENGTH)
            tx_length_dw_md <=  tx_length_dw_max-FIFO_WIDTH_DWORD;
         else if (((cstate==CPLD_ACK)||(cstate==CPLD_DATA) ||
                  ((cstate==WAIT_FOR_CPLD)&&(rx_ack_descrpt_ena==1'b1))) &&
                   (rx_dv==1'b1) && (tx_length_dw_md>0)) begin
            if (tx_length_dw_md==1)
               tx_length_dw_md <= 0;
            else
               tx_length_dw_md <= tx_length_dw_md-FIFO_WIDTH_DWORD;
         end
      end
   end

   always @ (posedge clk_in) begin
      if (init==1'b1)
         tx_length_byte       <= 0;
      else if (cstate==MRD_TX_ACK) begin
         tx_length_byte[1:0]  <= 0;
         tx_length_byte[11:2] <= tx_length_dw[9:0];
         tx_length_byte[15:12]<= 0;
      end
   end

   always @ (posedge clk_in) begin
      if (cstate== IDLE_ST)
         dt_addr_offset[15:0] <= 16'h10;
      else if (cstate == DONE_ST)
         dt_addr_offset <=dt_addr_offset+tx_length_byte;
   end

   assign dt_addr_offset_dw_ext[15:0]  = dt_addr_offset[15:0];
   assign dt_addr_offset_dw_ext[31:16] = 0;

   assign dt_addr_offset_qw_ext[31:0] = dt_addr_offset_dw_ext;
   assign dt_addr_offset_qw_ext[63:32] = 0;
   // Generate tx_desc_addr  upon 32 vs 64 bits RC
   always @ (posedge clk_in) begin
      tx_desc_addr_3dw_pipe[31:0] <= dt_base_rc[31:0]+dt_addr_offset_dw_ext;
   end

   always @ (posedge clk_in) begin
      if (cstate== IDLE_ST) begin
         tx_desc_addr <=64'h0;
         addrval_32b  <=1'b0;
      end
      else if (RC_64BITS_ADDR==0) begin
         tx_desc_addr[31:0] <= `ZERO_DWORD;
         addrval_32b        <= 1'b0;
         if ((cstate== START_TX)&&(tx_sel==1'b1))
            //tx_desc_addr[63:32] <= dt_base_rc[31:0]+dt_addr_offset_dw_ext;
            tx_desc_addr[63:32] <= tx_desc_addr_3dw_pipe[31:0];
      end
      else begin
         if ((cstate==START_TX)&&(tx_sel==1'b1)) begin
            if (dt_3dw_rcadd==1'b1) begin
               tx_desc_addr[63:32] <= dt_base_rc[31:0]+dt_addr_offset_dw_ext;
               tx_desc_addr[31:0]  <= `ZERO_DWORD;
               addrval_32b         <= 1'b0;
            end
            else begin
               // tx_desc_addr <= dt_base_rc+dt_addr_offset_qw_ext;
               tx_desc_addr <= tx_desc_addr_pipe;
               if (tx_desc_addr_pipe[63:32]==32'h0)
                  addrval_32b <=1'b1;
               else
                  addrval_32b <=1'b0;
            end
         end
      end
   end

    lpm_add_sub  # (
        .lpm_direction ("ADD"),
        .lpm_hint ( "ONE_INPUT_IS_CONSTANT=NO,CIN_USED=NO"),
        .lpm_pipeline ( 2),
        .lpm_type ( "LPM_ADD_SUB"),
        .lpm_width ( 64))
    addr64_add  (
                .dataa (dt_addr_offset_qw_ext),
                .datab (dt_base_rc),
                .clock (clk_in),
                .result (tx_desc_addr_pipe)
                // synopsys translate_off
                ,
                .aclr (),
                .add_sub (),
                .cin (),
                .clken (),
                .cout (),
                .overflow ()
                // synopsys translate_on
                );

   always @ (posedge clk_in) begin
      if (rx_req_p0==1'b0)
         rx_cpld_data_on_rx_req_p0 <= 1'b0;
      else begin
        if ((tlp_rx_fmt  == `TLP_FMT_CPLD) &&
                (tlp_rx_type == `TLP_TYPE_CPLD)&&
                (rx_dfr==1'b1)                   )
           rx_cpld_data_on_rx_req_p0 <= 1'b1;
      end
   end

   //cpl_pending
   always @ (negedge rstn or posedge clk_in) begin
      if (rstn==1'b0) begin
         cpl_pending <=1'b0;
       end
       else begin
         if (cstate==MRD_TX_ACK) begin
            cpl_pending <=1'b1;
         end
         else if (cstate==DONE_ST) begin
            cpl_pending <=1'b0;
         end
       end
   end

   always @ (posedge clk_in) begin
      if ((cstate==IDLE_ST) || (cstate==IDLE_NEW_RCLAST))
         descriptor_mrd_cycle<=1'b0;
      else
         descriptor_mrd_cycle<=1'b1;
   end
   // Descriptor state machine
   //    Combinatorial state transition (case state)
   always @*
   case (cstate)

      IDLE_ST:
         begin
            if (init==1'b0)
               nstate = TX_LENGTH;
            else
               nstate = IDLE_ST;
         end

      IDLE_NEW_RCLAST:
         begin
            if ((loop_dma==1'b1)||(init==1'b1))
               nstate = IDLE_ST;
            else
               nstate = IDLE_NEW_RCLAST;
         end
      TX_LENGTH:
         nstate = IS_TX_READY;

      IS_TX_READY:
         begin
            if ((tx_cred_non_posted_header_valid==1'b1)&&
                  (rx_buffer_cpl_ready==1'b1) &&
                   (dt_fifo_tx_ready==1'b1))
               nstate = START_TX;
            else
               nstate = IS_TX_READY;
         end

      START_TX:
      // Wait for top level arbitration (tx_sel)
      // Form tx_desc
      //      Calculate tx_desc_addr
      //      Calculate tx_length
         begin
            if (init==1'b1)
              nstate = IDLE_ST;
            else begin
               if ((dt_fifo_tx_ready==1'b0) ||
                     (rx_buffer_cpl_ready==1'b0)||
                     (tx_cred_non_posted_header_valid==1'b0))
                  nstate  = IS_TX_READY;
               else if ((tx_sel==1'b1) && (tx_ready==1'b1))
                  nstate = MRD_TX_REQ;
               else
                  nstate = START_TX;
            end
         end

      MRD_TX_REQ:
         begin
            if (tx_ack==1'b1)
               nstate = MRD_TX_ACK;
            else
               nstate = MRD_TX_REQ;
         end

      MRD_TX_ACK:
         nstate = WAIT_FOR_CPLD;

      WAIT_FOR_CPLD:
         begin
            if (init==1'b1)
               nstate = IDLE_ST;
            else begin
               if (rx_ack_descrpt_ena == 1'b1)
                  nstate = CPLD_ACK;
               else
                  nstate = WAIT_FOR_CPLD;
            end
         end

      CPLD_ACK:
         nstate = CPLD_DATA;

      CPLD_DATA:
         begin
            if (rx_dv==1'b0) begin
               if (tx_length_dw==0)
                  nstate    = DONE_ST;
               else
                  nstate    = WAIT_FOR_CPLD;
            end
            else
               nstate    = CPLD_DATA;
         end

      DONE_ST:
         begin
           if (dt_rc_last_size_dw>0)
              nstate = TX_LENGTH;
           else
              nstate = IDLE_NEW_RCLAST;
          end

       default:
            nstate  = IDLE_ST;
   endcase

   // Requester state machine
   //    Registered state state transition
   always @ (negedge rstn or posedge clk_in) begin
      if (rstn==1'b0) begin
         cstate <= IDLE_ST;
         rx_ack <= 1'b0;
      end
      else begin
         cstate <= nstate;
         rx_ack <= (nstate==WAIT_FOR_CPLD) & (init==1'b0) & (rx_ack_descrpt_ena_p0 == 1'b1) ? 1'b1 : 1'b0;
      end
   end


   // Descriptor FIFO which contain the table of descriptors
   // dt_fifo assignments


   assign rx_ack_descrpt_ena = ((rx_req_p1==1'b1)&&(descr_tag_reg==1'b1)&&          //  use descr_tag_reg instead of descr_tag
                                  (rx_cpld_data_on_rx_req_p0==1'b1))?1'b1:1'b0;

   assign rx_ack_descrpt_ena_p0 = ((rx_req_p0==1'b1)&&(descr_tag==1'b1)&&
                                  ((tlp_rx_fmt  == `TLP_FMT_CPLD) && (tlp_rx_type == `TLP_TYPE_CPLD)&& (rx_dfr==1'b1) ))?1'b1:1'b0;

   always @ (posedge clk_in) begin
      if ((init==1'b1)||(cstate==START_TX))
          valid_rx_dv_descriptor_cpld <=1'b0;
      else begin
         if ((rx_req_p1==1'b1) && (descr_tag==1'b1) &&
               (rx_cpld_data_on_rx_req_p0==1'b1))
               valid_rx_dv_descriptor_cpld <=1'b1;
         else if (rx_dv==1'b0)
            valid_rx_dv_descriptor_cpld <=1'b0;
      end
   end

   always @ (posedge clk_in) begin
      if (init==1'b1)
         rx_ack_pipe <= 1'b0;
      else
         rx_ack_pipe <= rx_ack;
   end

   always @ (posedge clk_in) begin
      if (init==1'b1)
         dt_fifo_empty <= 1'b1;
      else if (dt_fifo_usedw>DESCRIPTOR_PER_FIFO_WIDTH)
         dt_fifo_empty <=1'b0;
      else
         dt_fifo_empty <=1'b1;
   end

   assign dt_fifo_sclr  = init ;
   assign dt_fifo_data  = rx_data[FIFO_WIDTH-1:0];
   assign dt_fifo_wrreq =((rx_dv==1'b1)&&((valid_rx_dv_descriptor_cpld==1'b1)||
                           (rx_ack_descrpt_ena==1'b1)))?1'b1:1'b0;

   assign dt_fifo_data_int = (AVALON_ST_128 == 1'b0) ? {(13'h1000 - rx_data[43:32]), rx_data[FIFO_WIDTH-1:0]} :
                                                       {(13'h1000 - rx_data[107:96]), rx_data[FIFO_WIDTH-1:0]} ;

   scfifo # (
            .add_ram_output_register ("ON")          ,
            .intended_device_family  (INTENDED_DEVICE_FAMILY),
            .lpm_numwords            (FIFO_DEPTH)     ,
            .lpm_showahead           ("OFF")          ,
            .lpm_type                ("scfifo")       ,
            .lpm_width               (FIFO_WIDTH + 13)     ,
            .lpm_widthu              (FIFO_WIDTHU)    ,
            .overflow_checking       ("ON")           ,
            .underflow_checking      ("ON")           ,
            .use_eab                 ("ON")
            )
            dt_scfifo (
            .clock (clk_in),
            .sclr  (dt_fifo_sclr),
            .wrreq (dt_fifo_wrreq),
            .rdreq (dt_fifo_rdreq),
            .data  (dt_fifo_data_int),
            .q     (dt_fifo_q_int),
            .empty (scfifo_empty),
            .full  (dt_fifo_full),

            .usedw (dt_fifo_usedw)
                     // synopsys translate_off
                     ,
                     .aclr (),
                     .almost_empty (),
                     .almost_full ()
                     // synopsys translate_on
            );

      assign dt_fifo_q = dt_fifo_q_int[FIFO_WIDTH-1 : 0];
      assign dt_fifo_q_4K_bound = dt_fifo_q_int[FIFO_WIDTH+12 : FIFO_WIDTH];

 endmodule
