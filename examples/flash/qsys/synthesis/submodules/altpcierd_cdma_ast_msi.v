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



// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on
// synthesis verilog_input_version verilog_2001
// turn off superfluous verilog processor warnings
// altera message_level Level1
// altera message_off 10034 10035 10036 10037 10230 10240 10030
//-----------------------------------------------------------------------------
// Title         : PCI Express Reference Design Example Application
// Project       : PCI Express MegaCore function
//-----------------------------------------------------------------------------
// File          : altpcierd_cdma_ast_msi.v
// Author        : Altera Corporation
//-----------------------------------------------------------------------------
// Description :
// This module construct of the Avalon Streaming receive port for the
// chaining DMA application MSI signals.
//-----------------------------------------------------------------------------
module altpcierd_cdma_ast_msi (
                           input clk_in,
                           input rstn,
                           input app_msi_req,
                           output reg app_msi_ack,
                           input[2:0]   app_msi_tc,
                           input[4:0]   app_msi_num,
                                 input        stream_ready,
                           output reg [7:0] stream_data,
                           output reg stream_valid);

   reg   stream_ready_del;
   reg   app_msi_req_r;
   wire [7:0] m_data;

   assign m_data[7:5] = app_msi_tc[2:0];
   assign m_data[4:0] = app_msi_num[4:0];
   //------------------------------------------------------------
   //    Input register boundary
   //------------------------------------------------------------

   always @(negedge rstn or posedge clk_in) begin
      if (rstn == 1'b0)
          stream_ready_del <= 1'b0;
      else
          stream_ready_del <= stream_ready;
   end
   //------------------------------------------------------------
   //    Arbitration between master and target for transmission
   //------------------------------------------------------------

   // tx_state SM states


   always @(negedge rstn or posedge clk_in) begin
      if (rstn == 1'b0) begin
          app_msi_ack        <= 1'b0;
         stream_valid <= 1'b0;
           stream_data  <= 8'h0;
           app_msi_req_r      <= 1'b0;
      end
      else begin
         app_msi_ack       <= stream_ready_del & app_msi_req;
           stream_valid      <= stream_ready_del & app_msi_req & ~app_msi_req_r;
           stream_data       <= m_data;
           app_msi_req_r     <= stream_ready_del ? app_msi_req : app_msi_req_r;
      end
   end
endmodule
