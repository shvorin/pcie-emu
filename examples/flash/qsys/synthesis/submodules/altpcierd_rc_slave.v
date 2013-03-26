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
//  * the chaining DMA design example. It could be used by the software
//  * application (Root Port) to retrieve the DMA Performance counter values
//  * and performs read and write to the Endpoint memory by
//  * bypassing the DMA engines.
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


module altpcierd_rc_slave #(
   parameter AVALON_WDATA          = 128,
   parameter AVALON_WADDR          = 12,
   parameter AVALON_ST_128         = 0,
   parameter AVALON_BYTE_WIDTH     = AVALON_WDATA/8,
   parameter INTENDED_DEVICE_FAMILY="Cyclone IV GX"
   ) (

   input           clk_in,
   input           rstn,
   input [31:0]    dma_rd_prg_rddata,
   input [31:0]    dma_wr_prg_rddata,
   output [3:0]    dma_prg_addr,
   output [31:0]   dma_prg_wrdata,
   output          dma_wr_prg_wrena,
   output          dma_rd_prg_wrena,

   output          mem_wr_ena,  // rename this to write_downstream
   output          mem_rd_ena,

   input [15:0]    rx_ecrc_bad_cnt,
   input [63:0]    read_dma_status,
   input [63:0]    write_dma_status,
   input [12:0]    cfg_busdev,
   input           rx_req  ,
   input[135:0]    rx_desc ,
   input[127:0]    rx_data ,
   input[15:0]     rx_be,
   input           rx_dv   ,
   input           rx_dfr  ,
   output          rx_ack  ,
   output          rx_ws   ,
   input           tx_ws ,
   input           tx_ack ,
   output[127:0]   tx_data,
   output [127:0]  tx_desc,
   output          tx_dfr ,
   output          tx_dv  ,
   output          tx_req ,
   output          tx_busy,
   output          tx_ready,
   input           tx_sel,
   input                          mem_rd_data_valid,
   output [AVALON_WADDR-1:0]      mem_rd_addr ,
   input [AVALON_WDATA-1:0]       mem_rd_data  ,
   output [AVALON_WADDR-1:0]      mem_wr_addr ,
   output [AVALON_WDATA-1:0]      mem_wr_data ,
   output                         sel_epmem       ,
   output [AVALON_BYTE_WIDTH-1:0] mem_wr_be
);

   wire          sel_ep_reg;
   wire [31:0]   reg_rd_data;
   wire          reg_rd_data_valid;
   wire [7:0]    reg_rd_addr;
   wire [7:0]    reg_wr_addr;
   wire [31:0]   reg_wr_data;

   altpcierd_rxtx_downstream_intf #(
      .AVALON_ST_128    (AVALON_ST_128),
      .AVALON_WDATA     (AVALON_WDATA),
      .AVALON_BE_WIDTH  (AVALON_BYTE_WIDTH),
      .MEM_ADDR_WIDTH   (AVALON_WADDR),
      .INTENDED_DEVICE_FAMILY (INTENDED_DEVICE_FAMILY)
      ) altpcierd_rxtx_mem_intf (
      .clk_in       (clk_in),
      .rstn         (rstn),
      .cfg_busdev   (cfg_busdev),

      .rx_req       (rx_req),
      .rx_desc      (rx_desc),
      .rx_data      (rx_data[AVALON_WDATA-1:0]),
      .rx_be        (rx_be[AVALON_BYTE_WIDTH-1:0]),
      .rx_dv        (rx_dv),
      .rx_dfr       (rx_dfr),
      .rx_ack       (rx_ack),
      .rx_ws        (rx_ws),

      .tx_ws        (tx_ws),
      .tx_ack       (tx_ack),
      .tx_desc      (tx_desc),
      .tx_data      (tx_data[AVALON_WDATA-1:0]),
      .tx_dfr       (tx_dfr),
      .tx_dv        (tx_dv),
      .tx_req       (tx_req),
      .tx_busy      (tx_busy ),
      .tx_ready     (tx_ready),
      .tx_sel       (tx_sel ),

      .mem_rd_data_valid (mem_rd_data_valid),
      .mem_rd_addr       (mem_rd_addr),
      .mem_rd_data       (mem_rd_data),
      .mem_rd_ena        (mem_rd_ena),
      .mem_wr_ena        (mem_wr_ena),
      .mem_wr_addr       (mem_wr_addr),
      .mem_wr_data       (mem_wr_data),
      .mem_wr_be         (mem_wr_be),
      .sel_epmem         (sel_epmem),

      .sel_ctl_sts       (sel_ep_reg),
      .reg_rd_data       (reg_rd_data),
      .reg_rd_data_valid (reg_rd_data_valid),
      .reg_wr_addr       (reg_wr_addr),
      .reg_rd_addr       (reg_rd_addr),
      .reg_wr_data       (reg_wr_data)
   );

   altpcierd_reg_access altpcierd_reg_access   (
        .clk_in            (clk_in),
        .rstn              (rstn),
        .dma_rd_prg_rddata (dma_rd_prg_rddata),
        .dma_wr_prg_rddata (dma_wr_prg_rddata),
        .dma_prg_wrdata    (dma_prg_wrdata),
        .dma_prg_addr      (dma_prg_addr),
        .dma_rd_prg_wrena  (dma_rd_prg_wrena),
        .dma_wr_prg_wrena  (dma_wr_prg_wrena),

        .sel_ep_reg        (sel_ep_reg),
        .reg_rd_data       (reg_rd_data),
        .reg_rd_data_valid (reg_rd_data_valid),
        .reg_wr_ena        (mem_wr_ena),
        .reg_rd_ena        (mem_rd_ena),
        .reg_rd_addr       (reg_rd_addr),
        .reg_wr_addr       (reg_wr_addr),
        .reg_wr_data       (reg_wr_data),

        .rx_ecrc_bad_cnt   (rx_ecrc_bad_cnt),
        .read_dma_status   (read_dma_status),
        .write_dma_status  (write_dma_status)
   );



endmodule
