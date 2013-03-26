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
//  * the chaining DMA design example. It contains the descriptor header
//  * table registers which get programmed by the software application.
//  */
// synthesis translate_off
`define PCIE_SIM         TRUE
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
`timescale 1ns / 1ps
// synthesis translate_on
// synthesis verilog_input_version verilog_2001
// turn off superfluous verilog processor warnings
// altera message_level Level1
// altera message_off 10034 10035 10036 10037 10230 10240 10030

//-----------------------------------------------------------------------------
// Title         : altpcierd_ctl_sts_regs
// Project       : PCI Express MegaCore function
//-----------------------------------------------------------------------------
// File          : altpcierd_ctl_sts_regs.v
// Author        : Altera Corporation
//-----------------------------------------------------------------------------
//
//  Description:  This module contains the Address decoding for BAR2/3
//                address space.
//-----------------------------------------------------------------------------

module altpcierd_reg_access   (
   input             clk_in,
   input             rstn,
   input             sel_ep_reg,
   input             reg_wr_ena,         // pulse.  register write enable
   input             reg_rd_ena,
   input [7:0]       reg_rd_addr,        // register byte address (BAR 2/3 is 128 bytes max)
   input [7:0]       reg_wr_addr,
   input [31:0]      reg_wr_data,        // register data to be written
   input [31:0]      dma_rd_prg_rddata,
   input [31:0]      dma_wr_prg_rddata,
   input [15:0]      rx_ecrc_bad_cnt,
   input [63:0]      read_dma_status,
   input [63:0]      write_dma_status,

   output reg [31:0] reg_rd_data,        // register read data
   output reg        reg_rd_data_valid,  // pulse.  means reg_rd_data is valid
   output reg [31:0] dma_prg_wrdata,
   output reg [3:0]  dma_prg_addr,       // byte address
   output reg        dma_rd_prg_wrena,
   output reg        dma_wr_prg_wrena
   );


   // Module Address Decode - 2 MSB's

   localparam DMA_WRITE_PRG = 4'h0;
   localparam DMA_READ_PRG  = 4'h1;
   localparam MISC          = 4'h2;
   localparam ERR_STATUS    = 4'h3;

   // MISC address space
   localparam WRITE_DMA_STATUS_REG_HI = 4'h0;
   localparam WRITE_DMA_STATUS_REG_LO = 4'h4;
   localparam READ_DMA_STATUS_REG_HI  = 4'h8;
   localparam READ_DMA_STATUS_REG_LO  = 4'hc;


   reg [31:0] err_status_reg;
   reg [63:0] read_dma_status_reg;
   reg [63:0] write_dma_status_reg;
   reg [31:0] dma_rd_prg_rddata_reg;
   reg [31:0] dma_wr_prg_rddata_reg;

   reg             reg_wr_ena_reg;
   reg             reg_rd_ena_reg;
   reg [7:0]       reg_rd_addr_reg;
   reg [7:0]       reg_wr_addr_reg;
   reg [31:0]      reg_wr_data_reg;
   reg             sel_ep_reg_reg;
   reg             reg_rd_ena_reg2;
   reg             reg_rd_ena_reg3;

   // Pipeline input data for performance
   always @ (negedge rstn or posedge clk_in) begin
      if (rstn==1'b0) begin
          err_status_reg       <= 32'h0;
          read_dma_status_reg  <= 64'h0;
          write_dma_status_reg <= 64'h0;
          reg_wr_ena_reg       <= 1'b0;
          reg_rd_ena_reg       <= 1'b0;
          reg_rd_ena_reg2      <= 1'b0;
          reg_rd_ena_reg3      <= 1'b0;
          reg_rd_addr_reg      <= 8'h0;
          reg_wr_addr_reg      <= 8'h0;
          reg_wr_data_reg      <= 32'h0;
          sel_ep_reg_reg       <= 1'b0;
          dma_rd_prg_rddata_reg <= 32'h0;
          dma_wr_prg_rddata_reg <= 32'h0;
      end
      else begin
          err_status_reg       <= {16'h0, rx_ecrc_bad_cnt};
          read_dma_status_reg  <= read_dma_status;
          write_dma_status_reg <= write_dma_status;
          reg_wr_ena_reg       <= reg_wr_ena & sel_ep_reg;
          reg_rd_ena_reg       <= reg_rd_ena & sel_ep_reg;
          reg_rd_ena_reg2      <= reg_rd_ena_reg;
          reg_rd_ena_reg3      <= reg_rd_ena_reg2;
          reg_rd_addr_reg      <= reg_rd_addr;
          reg_wr_addr_reg      <= reg_wr_addr;
          reg_wr_data_reg      <= reg_wr_data;
          dma_rd_prg_rddata_reg <= dma_rd_prg_rddata;
          dma_wr_prg_rddata_reg <= dma_wr_prg_rddata;
      end
   end

   // Register Access
   always @ (negedge rstn or posedge clk_in) begin
      if (rstn==1'b0) begin
          reg_rd_data       <= 32'h0;
          reg_rd_data_valid <= 1'b0;
          dma_prg_wrdata    <= 32'h0;
          dma_prg_addr      <= 4'h0;
          dma_rd_prg_wrena  <= 1'b0;
          dma_wr_prg_wrena  <= 1'b0;
      end
      else begin
          //////////
          // WRITE

          dma_prg_wrdata    <= reg_wr_data_reg;
          dma_prg_addr      <= reg_wr_addr_reg[3:0];
          dma_rd_prg_wrena  <= ((reg_wr_ena_reg==1'b1) & (reg_wr_addr_reg[7:4] == DMA_READ_PRG))  ? 1'b1 : 1'b0;
          dma_wr_prg_wrena  <= ((reg_wr_ena_reg==1'b1) & (reg_wr_addr_reg[7:4] == DMA_WRITE_PRG)) ? 1'b1 : 1'b0;

          //////////
          // READ


          case (reg_rd_addr_reg[7:0])
              {MISC, WRITE_DMA_STATUS_REG_HI}: reg_rd_data <= write_dma_status_reg[63:32];
              {MISC, WRITE_DMA_STATUS_REG_LO}: reg_rd_data <= write_dma_status_reg[31:0];
              {MISC, READ_DMA_STATUS_REG_HI} : reg_rd_data <= read_dma_status_reg[63:32];
              {MISC, READ_DMA_STATUS_REG_LO} : reg_rd_data <= read_dma_status_reg[31:0];
              {ERR_STATUS, 4'h0}             : reg_rd_data <= err_status_reg;
              {DMA_WRITE_PRG, 4'h0},
              {DMA_WRITE_PRG, 4'h4},
              {DMA_WRITE_PRG, 4'h8},
              {DMA_WRITE_PRG, 4'hC}          : reg_rd_data <= dma_wr_prg_rddata_reg;
              {DMA_READ_PRG, 4'h0},
              {DMA_READ_PRG, 4'h4},
              {DMA_READ_PRG, 4'h8},
              {DMA_READ_PRG, 4'hC}           : reg_rd_data <= dma_rd_prg_rddata_reg;
              default                        : reg_rd_data <= 32'h0;
          endcase

          case (reg_rd_addr_reg[7:4])
              DMA_WRITE_PRG: reg_rd_data_valid <= reg_rd_ena_reg3;
              DMA_READ_PRG : reg_rd_data_valid <= reg_rd_ena_reg3;
              default      : reg_rd_data_valid <= reg_rd_ena_reg;
          endcase
      end
   end


endmodule
