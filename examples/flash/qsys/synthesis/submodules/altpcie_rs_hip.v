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


//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on

// Complementary HIP reset logic (hiprst) used along with the
// HIP hard reset controller
//
module altpcie_rs_hip (
   input          pld_clk,
   input          dlup_exit,
   input          hotrst_exit,
   input          l2_exit,
   input          npor_core,
   input   [4: 0] ltssm,

   output reg     hiprst
);

localparam [4:0] LTSSM_POL          = 5'b00010;
localparam [4:0] LTSSM_CPL          = 5'b00011;
localparam [4:0] LTSSM_DET          = 5'b00000;
localparam [4:0] LTSSM_RCV          = 5'b01100;
localparam [4:0] LTSSM_DIS          = 5'b10000;
localparam [4:0] LTSSM_DETA         = 5'b00001;
localparam [4:0] LTSSM_DETQ         = 5'b00000;
localparam [23:0] RCV_TIMEOUT       = 24'd6000000;

`ifdef ALTERA_RESERVED_QIS_ES
   localparam SV_ES_DEVICE          =  1;
`else
   localparam SV_ES_DEVICE          =  0;
`endif

reg         hiprst_r;
reg [1:0]   npor_core_r ;
reg         npor_sync   ;
reg         dlup_exit_r;
reg         exits_r;
reg         hotrst_exit_r;
reg         l2_exit_r;
reg [4: 0]  rsnt_cntn;
reg [4: 0]  ltssm_r;
reg [4: 0]  ltssm_rr;
reg [23:0]  recovery_cnt;
reg         recovery_rst;
reg [7:0]   cnt_dect_quiet_low;
reg         ext_dect_quiet;

   //reset Synchronizer
   always @(posedge pld_clk or negedge npor_core) begin
      if (npor_core == 1'b0) begin
         npor_core_r  <= 2'b00;
         npor_sync    <= 1'b0;
      end
      else begin
         npor_core_r  <= {npor_core_r[0],1'b1};
         npor_sync    <= npor_core_r;
      end
   end

  //Reset delay
   always @(posedge pld_clk or negedge npor_sync) begin
      if (npor_sync == 1'b0)
         rsnt_cntn <= 5'h0;
      else if (exits_r == 1'b1)
         rsnt_cntn <= 5'd10;
      else if (rsnt_cntn != 5'd20)
         rsnt_cntn <= rsnt_cntn + 5'h1;
   end


  //sync and config reset
   always @(posedge pld_clk or negedge npor_sync) begin
      if (npor_sync == 1'b0) begin
          hiprst_r <= 1'b0;
      end
      else if (exits_r == 1'b1) begin
          hiprst_r <= 1'b1;
      end
      else if (rsnt_cntn == 5'd20) begin
          hiprst_r <= 1'b0;
      end
   end

   // Monitor if LTSSM is frozen in RECOVERY state
   // Issue reset if timeout RCV_TIMEOUT
   always @(posedge pld_clk or negedge npor_sync) begin
      if (npor_sync == 1'b0) begin
         recovery_cnt <= {24{1'b0}};
         recovery_rst <= 1'b0;
      end
      else begin
         if ((ltssm_r != LTSSM_RCV)||(SV_ES_DEVICE==0)) begin
            recovery_cnt <= {24{1'b0}};
         end
         else if (recovery_cnt == RCV_TIMEOUT) begin
            recovery_cnt <= recovery_cnt;
         end
         else if (ltssm_r == LTSSM_RCV) begin
            recovery_cnt <= recovery_cnt + 24'h1;
         end
         if (SV_ES_DEVICE==0) begin
            recovery_rst <= 1'b0;
         end
         else if (recovery_cnt == RCV_TIMEOUT) begin
            recovery_rst <= 1'b1;
         end
         else if (ltssm_r != LTSSM_RCV) begin
            recovery_rst <= 1'b0;
         end
      end
   end

   // Keep LTSSM in reset for 1us before transition from Detect.quiet to
   // Detect.active
   // Since the fastest pld_clk is 250Mhz (4ns) and the minimum wait is 1us,
   // the max_reset_cnt = 1024/4 = 256
   always @(posedge pld_clk or negedge npor_sync) begin
      if (npor_sync == 1'b0) begin
         cnt_dect_quiet_low   <= 8'hFF;
         ext_dect_quiet       <= 1'b0;
      end
      else  begin
         if ((ltssm_r == LTSSM_DETQ) && (ltssm_rr == LTSSM_DETA)) begin
            cnt_dect_quiet_low   <= 8'h0;
            ext_dect_quiet       <= 1'b1;
         end
         else begin
            if (cnt_dect_quiet_low < 8'hFF ) begin
               cnt_dect_quiet_low <= cnt_dect_quiet_low + 8'h1;
            end
            if (cnt_dect_quiet_low == 8'hFE ) begin
               ext_dect_quiet <= 1'b0;
            end
         end
      end
   end

   always @(posedge pld_clk or negedge npor_sync) begin
      if (npor_sync == 1'b0) begin
         dlup_exit_r    <= 1'b1;
         hotrst_exit_r  <= 1'b1;
         l2_exit_r      <= 1'b1;
         exits_r        <= 1'b0;
         hiprst         <= 1'b0;
         ltssm_r        <= LTSSM_DETQ;
         ltssm_rr       <= LTSSM_DETQ;
      end
      else begin
         ltssm_r        <= ltssm;
         ltssm_rr       <= ltssm_r;
         hiprst         <= hiprst_r;
         dlup_exit_r    <= dlup_exit;
         hotrst_exit_r  <= hotrst_exit;
         l2_exit_r      <= l2_exit;
         if (SV_ES_DEVICE==1) begin
            exits_r <= ((l2_exit_r == 1'b0)||(hotrst_exit_r == 1'b0)||(dlup_exit_r == 1'b0)||(ltssm_r == LTSSM_DIS)||(recovery_rst == 1'b1)||(ext_dect_quiet == 1'b1))?1'b1:1'b0;
         end
         else begin
            exits_r <= ((l2_exit_r == 1'b0)||(hotrst_exit_r == 1'b0)||(dlup_exit_r == 1'b0)||(ltssm_r == LTSSM_DIS)||(ext_dect_quiet == 1'b1))?1'b1:1'b0;
         end
      end
   end

endmodule
