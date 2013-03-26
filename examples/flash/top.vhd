-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

LIBRARY ieee;
   USE ieee.std_logic_1164.all;
   USE ieee.std_logic_arith.all;
   USE ieee.std_logic_unsigned.all;
   USE ieee.std_logic_misc.all;
	
entity top is
	port (
		refclk_clk                : in  std_logic;                                  -- clk
		pcie_rstn_pin_perst       : in  std_logic;                                  -- pin_perst
		hip_serial_rx_in0         : in  std_logic;                                  -- rx_in0
		hip_serial_rx_in1         : in  std_logic;                                  -- rx_in1
		hip_serial_rx_in2         : in  std_logic;                                  -- rx_in2
		hip_serial_rx_in3         : in  std_logic;                                  -- rx_in3
		hip_serial_rx_in4         : in  std_logic;                                  -- rx_in4
		hip_serial_rx_in5         : in  std_logic;                                  -- rx_in5
		hip_serial_rx_in6         : in  std_logic;                                  -- rx_in6
		hip_serial_rx_in7         : in  std_logic;                                  -- rx_in7
		hip_serial_tx_out0        : out std_logic;                                        -- tx_out0
		hip_serial_tx_out1        : out std_logic;                                        -- tx_out1
		hip_serial_tx_out2        : out std_logic;                                        -- tx_out2
		hip_serial_tx_out3        : out std_logic;                                        -- tx_out3
		hip_serial_tx_out4        : out std_logic;                                        -- tx_out4
		hip_serial_tx_out5        : out std_logic;                                        -- tx_out5
		hip_serial_tx_out6        : out std_logic;                                        -- tx_out6
		hip_serial_tx_out7        : out std_logic;

		flash_address 		 			: inout STD_LOGIC_VECTOR (25 downto 0);
		nflash_ce0				 		: inout STD_LOGIC;
		nflash_ce1				 		: inout STD_LOGIC;
		nflash_we				 		: inout STD_LOGIC;
		nflash_oe				 		: inout STD_LOGIC;
		flash_data			 			: inout STD_LOGIC_VECTOR (31 downto 0);
		nflash_reset					: inout STD_LOGIC;
		flash_clk						: inout STD_LOGIC;
		flash_wait0						: in STD_LOGIC;
		flash_wait1						: in STD_LOGIC;
		nflash_adv						: inout STD_LOGIC
	);
end entity;
	
architecture top_arch of top is
	component pcie_de_gen1_x8_ast128 is
		port (
			hip_ctrl_test_in          : in  std_logic_vector(31 downto 0) := (others => 'X'); -- test_in
			hip_ctrl_simu_mode_pipe   : in  std_logic                     := 'X';             -- simu_mode_pipe
			hip_serial_rx_in0         : in  std_logic                     := 'X';             -- rx_in0
			hip_serial_rx_in1         : in  std_logic                     := 'X';             -- rx_in1
			hip_serial_rx_in2         : in  std_logic                     := 'X';             -- rx_in2
			hip_serial_rx_in3         : in  std_logic                     := 'X';             -- rx_in3
			hip_serial_rx_in4         : in  std_logic                     := 'X';             -- rx_in4
			hip_serial_rx_in5         : in  std_logic                     := 'X';             -- rx_in5
			hip_serial_rx_in6         : in  std_logic                     := 'X';             -- rx_in6
			hip_serial_rx_in7         : in  std_logic                     := 'X';             -- rx_in7
			hip_serial_tx_out0        : out std_logic;                                        -- tx_out0
			hip_serial_tx_out1        : out std_logic;                                        -- tx_out1
			hip_serial_tx_out2        : out std_logic;                                        -- tx_out2
			hip_serial_tx_out3        : out std_logic;                                        -- tx_out3
			hip_serial_tx_out4        : out std_logic;                                        -- tx_out4
			hip_serial_tx_out5        : out std_logic;                                        -- tx_out5
			hip_serial_tx_out6        : out std_logic;                                        -- tx_out6
			hip_serial_tx_out7        : out std_logic;                                        -- tx_out7
			hip_pipe_sim_pipe_pclk_in : in  std_logic                     := 'X';             -- sim_pipe_pclk_in
			hip_pipe_sim_pipe_rate    : out std_logic_vector(1 downto 0);                     -- sim_pipe_rate
			hip_pipe_sim_ltssmstate   : out std_logic_vector(4 downto 0);                     -- sim_ltssmstate
			hip_pipe_eidleinfersel0   : out std_logic_vector(2 downto 0);                     -- eidleinfersel0
			hip_pipe_eidleinfersel1   : out std_logic_vector(2 downto 0);                     -- eidleinfersel1
			hip_pipe_eidleinfersel2   : out std_logic_vector(2 downto 0);                     -- eidleinfersel2
			hip_pipe_eidleinfersel3   : out std_logic_vector(2 downto 0);                     -- eidleinfersel3
			hip_pipe_eidleinfersel4   : out std_logic_vector(2 downto 0);                     -- eidleinfersel4
			hip_pipe_eidleinfersel5   : out std_logic_vector(2 downto 0);                     -- eidleinfersel5
			hip_pipe_eidleinfersel6   : out std_logic_vector(2 downto 0);                     -- eidleinfersel6
			hip_pipe_eidleinfersel7   : out std_logic_vector(2 downto 0);                     -- eidleinfersel7
			hip_pipe_powerdown0       : out std_logic_vector(1 downto 0);                     -- powerdown0
			hip_pipe_powerdown1       : out std_logic_vector(1 downto 0);                     -- powerdown1
			hip_pipe_powerdown2       : out std_logic_vector(1 downto 0);                     -- powerdown2
			hip_pipe_powerdown3       : out std_logic_vector(1 downto 0);                     -- powerdown3
			hip_pipe_powerdown4       : out std_logic_vector(1 downto 0);                     -- powerdown4
			hip_pipe_powerdown5       : out std_logic_vector(1 downto 0);                     -- powerdown5
			hip_pipe_powerdown6       : out std_logic_vector(1 downto 0);                     -- powerdown6
			hip_pipe_powerdown7       : out std_logic_vector(1 downto 0);                     -- powerdown7
			hip_pipe_rxpolarity0      : out std_logic;                                        -- rxpolarity0
			hip_pipe_rxpolarity1      : out std_logic;                                        -- rxpolarity1
			hip_pipe_rxpolarity2      : out std_logic;                                        -- rxpolarity2
			hip_pipe_rxpolarity3      : out std_logic;                                        -- rxpolarity3
			hip_pipe_rxpolarity4      : out std_logic;                                        -- rxpolarity4
			hip_pipe_rxpolarity5      : out std_logic;                                        -- rxpolarity5
			hip_pipe_rxpolarity6      : out std_logic;                                        -- rxpolarity6
			hip_pipe_rxpolarity7      : out std_logic;                                        -- rxpolarity7
			hip_pipe_txcompl0         : out std_logic;                                        -- txcompl0
			hip_pipe_txcompl1         : out std_logic;                                        -- txcompl1
			hip_pipe_txcompl2         : out std_logic;                                        -- txcompl2
			hip_pipe_txcompl3         : out std_logic;                                        -- txcompl3
			hip_pipe_txcompl4         : out std_logic;                                        -- txcompl4
			hip_pipe_txcompl5         : out std_logic;                                        -- txcompl5
			hip_pipe_txcompl6         : out std_logic;                                        -- txcompl6
			hip_pipe_txcompl7         : out std_logic;                                        -- txcompl7
			hip_pipe_txdata0          : out std_logic_vector(7 downto 0);                     -- txdata0
			hip_pipe_txdata1          : out std_logic_vector(7 downto 0);                     -- txdata1
			hip_pipe_txdata2          : out std_logic_vector(7 downto 0);                     -- txdata2
			hip_pipe_txdata3          : out std_logic_vector(7 downto 0);                     -- txdata3
			hip_pipe_txdata4          : out std_logic_vector(7 downto 0);                     -- txdata4
			hip_pipe_txdata5          : out std_logic_vector(7 downto 0);                     -- txdata5
			hip_pipe_txdata6          : out std_logic_vector(7 downto 0);                     -- txdata6
			hip_pipe_txdata7          : out std_logic_vector(7 downto 0);                     -- txdata7
			hip_pipe_txdatak0         : out std_logic;                                        -- txdatak0
			hip_pipe_txdatak1         : out std_logic;                                        -- txdatak1
			hip_pipe_txdatak2         : out std_logic;                                        -- txdatak2
			hip_pipe_txdatak3         : out std_logic;                                        -- txdatak3
			hip_pipe_txdatak4         : out std_logic;                                        -- txdatak4
			hip_pipe_txdatak5         : out std_logic;                                        -- txdatak5
			hip_pipe_txdatak6         : out std_logic;                                        -- txdatak6
			hip_pipe_txdatak7         : out std_logic;                                        -- txdatak7
			hip_pipe_txdetectrx0      : out std_logic;                                        -- txdetectrx0
			hip_pipe_txdetectrx1      : out std_logic;                                        -- txdetectrx1
			hip_pipe_txdetectrx2      : out std_logic;                                        -- txdetectrx2
			hip_pipe_txdetectrx3      : out std_logic;                                        -- txdetectrx3
			hip_pipe_txdetectrx4      : out std_logic;                                        -- txdetectrx4
			hip_pipe_txdetectrx5      : out std_logic;                                        -- txdetectrx5
			hip_pipe_txdetectrx6      : out std_logic;                                        -- txdetectrx6
			hip_pipe_txdetectrx7      : out std_logic;                                        -- txdetectrx7
			hip_pipe_txelecidle0      : out std_logic;                                        -- txelecidle0
			hip_pipe_txelecidle1      : out std_logic;                                        -- txelecidle1
			hip_pipe_txelecidle2      : out std_logic;                                        -- txelecidle2
			hip_pipe_txelecidle3      : out std_logic;                                        -- txelecidle3
			hip_pipe_txelecidle4      : out std_logic;                                        -- txelecidle4
			hip_pipe_txelecidle5      : out std_logic;                                        -- txelecidle5
			hip_pipe_txelecidle6      : out std_logic;                                        -- txelecidle6
			hip_pipe_txelecidle7      : out std_logic;                                        -- txelecidle7
			hip_pipe_txdeemph0        : out std_logic;                                        -- txdeemph0
			hip_pipe_txdeemph1        : out std_logic;                                        -- txdeemph1
			hip_pipe_txdeemph2        : out std_logic;                                        -- txdeemph2
			hip_pipe_txdeemph3        : out std_logic;                                        -- txdeemph3
			hip_pipe_txdeemph4        : out std_logic;                                        -- txdeemph4
			hip_pipe_txdeemph5        : out std_logic;                                        -- txdeemph5
			hip_pipe_txdeemph6        : out std_logic;                                        -- txdeemph6
			hip_pipe_txdeemph7        : out std_logic;                                        -- txdeemph7
			hip_pipe_txmargin0        : out std_logic_vector(2 downto 0);                     -- txmargin0
			hip_pipe_txmargin1        : out std_logic_vector(2 downto 0);                     -- txmargin1
			hip_pipe_txmargin2        : out std_logic_vector(2 downto 0);                     -- txmargin2
			hip_pipe_txmargin3        : out std_logic_vector(2 downto 0);                     -- txmargin3
			hip_pipe_txmargin4        : out std_logic_vector(2 downto 0);                     -- txmargin4
			hip_pipe_txmargin5        : out std_logic_vector(2 downto 0);                     -- txmargin5
			hip_pipe_txmargin6        : out std_logic_vector(2 downto 0);                     -- txmargin6
			hip_pipe_txmargin7        : out std_logic_vector(2 downto 0);                     -- txmargin7
			hip_pipe_txswing0         : out std_logic;                                        -- txswing0
			hip_pipe_txswing1         : out std_logic;                                        -- txswing1
			hip_pipe_txswing2         : out std_logic;                                        -- txswing2
			hip_pipe_txswing3         : out std_logic;                                        -- txswing3
			hip_pipe_txswing4         : out std_logic;                                        -- txswing4
			hip_pipe_txswing5         : out std_logic;                                        -- txswing5
			hip_pipe_txswing6         : out std_logic;                                        -- txswing6
			hip_pipe_txswing7         : out std_logic;                                        -- txswing7
			hip_pipe_phystatus0       : in  std_logic                     := 'X';             -- phystatus0
			hip_pipe_phystatus1       : in  std_logic                     := 'X';             -- phystatus1
			hip_pipe_phystatus2       : in  std_logic                     := 'X';             -- phystatus2
			hip_pipe_phystatus3       : in  std_logic                     := 'X';             -- phystatus3
			hip_pipe_phystatus4       : in  std_logic                     := 'X';             -- phystatus4
			hip_pipe_phystatus5       : in  std_logic                     := 'X';             -- phystatus5
			hip_pipe_phystatus6       : in  std_logic                     := 'X';             -- phystatus6
			hip_pipe_phystatus7       : in  std_logic                     := 'X';             -- phystatus7
			hip_pipe_rxdata0          : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata0
			hip_pipe_rxdata1          : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata1
			hip_pipe_rxdata2          : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata2
			hip_pipe_rxdata3          : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata3
			hip_pipe_rxdata4          : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata4
			hip_pipe_rxdata5          : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata5
			hip_pipe_rxdata6          : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata6
			hip_pipe_rxdata7          : in  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata7
			hip_pipe_rxdatak0         : in  std_logic                     := 'X';             -- rxdatak0
			hip_pipe_rxdatak1         : in  std_logic                     := 'X';             -- rxdatak1
			hip_pipe_rxdatak2         : in  std_logic                     := 'X';             -- rxdatak2
			hip_pipe_rxdatak3         : in  std_logic                     := 'X';             -- rxdatak3
			hip_pipe_rxdatak4         : in  std_logic                     := 'X';             -- rxdatak4
			hip_pipe_rxdatak5         : in  std_logic                     := 'X';             -- rxdatak5
			hip_pipe_rxdatak6         : in  std_logic                     := 'X';             -- rxdatak6
			hip_pipe_rxdatak7         : in  std_logic                     := 'X';             -- rxdatak7
			hip_pipe_rxelecidle0      : in  std_logic                     := 'X';             -- rxelecidle0
			hip_pipe_rxelecidle1      : in  std_logic                     := 'X';             -- rxelecidle1
			hip_pipe_rxelecidle2      : in  std_logic                     := 'X';             -- rxelecidle2
			hip_pipe_rxelecidle3      : in  std_logic                     := 'X';             -- rxelecidle3
			hip_pipe_rxelecidle4      : in  std_logic                     := 'X';             -- rxelecidle4
			hip_pipe_rxelecidle5      : in  std_logic                     := 'X';             -- rxelecidle5
			hip_pipe_rxelecidle6      : in  std_logic                     := 'X';             -- rxelecidle6
			hip_pipe_rxelecidle7      : in  std_logic                     := 'X';             -- rxelecidle7
			hip_pipe_rxstatus0        : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus0
			hip_pipe_rxstatus1        : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus1
			hip_pipe_rxstatus2        : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus2
			hip_pipe_rxstatus3        : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus3
			hip_pipe_rxstatus4        : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus4
			hip_pipe_rxstatus5        : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus5
			hip_pipe_rxstatus6        : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus6
			hip_pipe_rxstatus7        : in  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus7
			hip_pipe_rxvalid0         : in  std_logic                     := 'X';             -- rxvalid0
			hip_pipe_rxvalid1         : in  std_logic                     := 'X';             -- rxvalid1
			hip_pipe_rxvalid2         : in  std_logic                     := 'X';             -- rxvalid2
			hip_pipe_rxvalid3         : in  std_logic                     := 'X';             -- rxvalid3
			hip_pipe_rxvalid4         : in  std_logic                     := 'X';             -- rxvalid4
			hip_pipe_rxvalid5         : in  std_logic                     := 'X';             -- rxvalid5
			hip_pipe_rxvalid6         : in  std_logic                     := 'X';             -- rxvalid6
			hip_pipe_rxvalid7         : in  std_logic                     := 'X';             -- rxvalid7
			refclk_clk                : in  std_logic                     := 'X';             -- clk
			pcie_rstn_npor            : in  std_logic                     := 'X';             -- npor
			pcie_rstn_pin_perst       : in  std_logic                     := 'X';             -- pin_perst
			clk_clk                   : in  std_logic                     := 'X';             -- clk
			reset_reset_n             : in  std_logic                     := 'X';              -- reset_n
			
			flash_address 		 			: inout STD_LOGIC_VECTOR (25 downto 0);
			nflash_ce0				 		: inout STD_LOGIC;
			nflash_ce1				 		: inout STD_LOGIC;
			nflash_we				 		: inout STD_LOGIC;
			nflash_oe				 		: inout STD_LOGIC;
			flash_data			 			: inout STD_LOGIC_VECTOR (31 downto 0);
			nflash_reset					: inout STD_LOGIC;
			flash_clk						: inout STD_LOGIC;
			flash_wait0						: in STD_LOGIC;
			flash_wait1						: in STD_LOGIC;
			nflash_adv						: inout STD_LOGIC
		);
	end component;

			signal hip_ctrl_test_in          : std_logic_vector(31 downto 0) := (others => 'X'); -- test_in
			signal hip_ctrl_simu_mode_pipe   : std_logic                     := 'X';             -- simu_mode_pipe
		
			signal hip_pipe_sim_pipe_pclk_in :   std_logic                     := 'X';             -- sim_pipe_pclk_in
			signal hip_pipe_sim_pipe_rate    :  std_logic_vector(1 downto 0);                     -- sim_pipe_rate
			signal hip_pipe_sim_ltssmstate   :  std_logic_vector(4 downto 0);                     -- sim_ltssmstate
			signal hip_pipe_eidleinfersel0   :  std_logic_vector(2 downto 0);                     -- eidleinfersel0
			signal hip_pipe_eidleinfersel1   :  std_logic_vector(2 downto 0);                     -- eidleinfersel1
			signal hip_pipe_eidleinfersel2   :  std_logic_vector(2 downto 0);                     -- eidleinfersel2
			signal hip_pipe_eidleinfersel3   :  std_logic_vector(2 downto 0);                     -- eidleinfersel3
			signal hip_pipe_eidleinfersel4   :  std_logic_vector(2 downto 0);                     -- eidleinfersel4
			signal hip_pipe_eidleinfersel5   :  std_logic_vector(2 downto 0);                     -- eidleinfersel5
			signal hip_pipe_eidleinfersel6   :  std_logic_vector(2 downto 0);                     -- eidleinfersel6
			signal hip_pipe_eidleinfersel7   : std_logic_vector(2 downto 0);                     -- eidleinfersel7
			signal hip_pipe_powerdown0       :  std_logic_vector(1 downto 0);                     -- powerdown0
			signal hip_pipe_powerdown1       :  std_logic_vector(1 downto 0);                     -- powerdown1
			signal hip_pipe_powerdown2       :  std_logic_vector(1 downto 0);                     -- powerdown2
			signal hip_pipe_powerdown3       :  std_logic_vector(1 downto 0);                     -- powerdown3
			signal hip_pipe_powerdown4       :  std_logic_vector(1 downto 0);                     -- powerdown4
			signal hip_pipe_powerdown5       :  std_logic_vector(1 downto 0);                     -- powerdown5
			signal hip_pipe_powerdown6       :  std_logic_vector(1 downto 0);                     -- powerdown6
			signal hip_pipe_powerdown7       :  std_logic_vector(1 downto 0);                     -- powerdown7
			signal hip_pipe_rxpolarity0      :  std_logic;                                        -- rxpolarity0
			signal hip_pipe_rxpolarity1      :  std_logic;                                        -- rxpolarity1
			signal hip_pipe_rxpolarity2      :  std_logic;                                        -- rxpolarity2
			signal hip_pipe_rxpolarity3      :  std_logic;                                        -- rxpolarity3
			signal hip_pipe_rxpolarity4      :  std_logic;                                        -- rxpolarity4
			signal hip_pipe_rxpolarity5      :  std_logic;                                        -- rxpolarity5
			signal hip_pipe_rxpolarity6      :  std_logic;                                        -- rxpolarity6
			signal hip_pipe_rxpolarity7      :  std_logic;                                        -- rxpolarity7
			signal hip_pipe_txcompl0         :  std_logic;                                        -- txcompl0
			signal hip_pipe_txcompl1         :  std_logic;                                        -- txcompl1
			signal hip_pipe_txcompl2         :  std_logic;                                        -- txcompl2
			signal hip_pipe_txcompl3         :  std_logic;                                        -- txcompl3
			signal hip_pipe_txcompl4         :  std_logic;                                        -- txcompl4
			signal hip_pipe_txcompl5         :  std_logic;                                        -- txcompl5
			signal hip_pipe_txcompl6         :  std_logic;                                        -- txcompl6
			signal hip_pipe_txcompl7         :  std_logic;                                        -- txcompl7
			signal hip_pipe_txdata0          :  std_logic_vector(7 downto 0);                     -- txdata0
			signal hip_pipe_txdata1          :  std_logic_vector(7 downto 0);                     -- txdata1
			signal hip_pipe_txdata2          :  std_logic_vector(7 downto 0);                     -- txdata2
			signal hip_pipe_txdata3          :  std_logic_vector(7 downto 0);                     -- txdata3
			signal hip_pipe_txdata4          :  std_logic_vector(7 downto 0);                     -- txdata4
			signal hip_pipe_txdata5          :  std_logic_vector(7 downto 0);                     -- txdata5
			signal hip_pipe_txdata6          :  std_logic_vector(7 downto 0);                     -- txdata6
			signal hip_pipe_txdata7          :  std_logic_vector(7 downto 0);                     -- txdata7
			signal hip_pipe_txdatak0         :  std_logic;                                        -- txdatak0
			signal hip_pipe_txdatak1         :  std_logic;                                        -- txdatak1
			signal hip_pipe_txdatak2         :  std_logic;                                        -- txdatak2
			signal hip_pipe_txdatak3         :  std_logic;                                        -- txdatak3
			signal hip_pipe_txdatak4         :  std_logic;                                        -- txdatak4
			signal hip_pipe_txdatak5         :  std_logic;                                        -- txdatak5
			signal hip_pipe_txdatak6         :  std_logic;                                        -- txdatak6
			signal hip_pipe_txdatak7         :  std_logic;                                        -- txdatak7
			signal hip_pipe_txdetectrx0      :  std_logic;                                        -- txdetectrx0
			signal hip_pipe_txdetectrx1      :  std_logic;                                        -- txdetectrx1
			signal hip_pipe_txdetectrx2      :  std_logic;                                        -- txdetectrx2
			signal hip_pipe_txdetectrx3      :  std_logic;                                        -- txdetectrx3
			signal hip_pipe_txdetectrx4      :  std_logic;                                        -- txdetectrx4
			signal hip_pipe_txdetectrx5      :  std_logic;                                        -- txdetectrx5
			signal hip_pipe_txdetectrx6      :  std_logic;                                        -- txdetectrx6
			signal hip_pipe_txdetectrx7      :  std_logic;                                        -- txdetectrx7
			signal hip_pipe_txelecidle0      :  std_logic;                                        -- txelecidle0
			signal hip_pipe_txelecidle1      :  std_logic;                                        -- txelecidle1
			signal hip_pipe_txelecidle2      :  std_logic;                                        -- txelecidle2
			signal hip_pipe_txelecidle3      :  std_logic;                                        -- txelecidle3
			signal hip_pipe_txelecidle4      :  std_logic;                                        -- txelecidle4
			signal hip_pipe_txelecidle5      :  std_logic;                                        -- txelecidle5
			signal hip_pipe_txelecidle6      :  std_logic;                                        -- txelecidle6
			signal hip_pipe_txelecidle7      :  std_logic;                                        -- txelecidle7
			signal hip_pipe_txdeemph0        :  std_logic;                                        -- txdeemph0
			signal hip_pipe_txdeemph1        :  std_logic;                                        -- txdeemph1
			signal hip_pipe_txdeemph2        :  std_logic;                                        -- txdeemph2
			signal hip_pipe_txdeemph3        :  std_logic;                                        -- txdeemph3
			signal hip_pipe_txdeemph4        :  std_logic;                                        -- txdeemph4
			signal hip_pipe_txdeemph5        :  std_logic;                                        -- txdeemph5
			signal hip_pipe_txdeemph6        :  std_logic;                                        -- txdeemph6
			signal hip_pipe_txdeemph7        :  std_logic;                                        -- txdeemph7
			signal hip_pipe_txmargin0        :  std_logic_vector(2 downto 0);                     -- txmargin0
			signal hip_pipe_txmargin1        :  std_logic_vector(2 downto 0);                     -- txmargin1
			signal hip_pipe_txmargin2        :  std_logic_vector(2 downto 0);                     -- txmargin2
			signal hip_pipe_txmargin3        :  std_logic_vector(2 downto 0);                     -- txmargin3
			signal hip_pipe_txmargin4        :  std_logic_vector(2 downto 0);                     -- txmargin4
			signal hip_pipe_txmargin5        :  std_logic_vector(2 downto 0);                     -- txmargin5
			signal hip_pipe_txmargin6        :  std_logic_vector(2 downto 0);                     -- txmargin6
			signal hip_pipe_txmargin7        :  std_logic_vector(2 downto 0);                     -- txmargin7
			signal hip_pipe_txswing0         :  std_logic;                                        -- txswing0
			signal hip_pipe_txswing1         :  std_logic;                                        -- txswing1
			signal hip_pipe_txswing2         :  std_logic;                                        -- txswing2
			signal hip_pipe_txswing3         :  std_logic;                                        -- txswing3
			signal hip_pipe_txswing4         :  std_logic;                                        -- txswing4
			signal hip_pipe_txswing5         :  std_logic;                                        -- txswing5
			signal hip_pipe_txswing6         :  std_logic;                                        -- txswing6
			signal hip_pipe_txswing7         :  std_logic;                                        -- txswing7
			signal hip_pipe_phystatus0       :  std_logic                     := 'X';             -- phystatus0
			signal hip_pipe_phystatus1       :  std_logic                     := 'X';             -- phystatus1
			signal hip_pipe_phystatus2       :  std_logic                     := 'X';             -- phystatus2
			signal hip_pipe_phystatus3       :  std_logic                     := 'X';             -- phystatus3
			signal hip_pipe_phystatus4       :  std_logic                     := 'X';             -- phystatus4
			signal hip_pipe_phystatus5       :  std_logic                     := 'X';             -- phystatus5
			signal hip_pipe_phystatus6       :  std_logic                     := 'X';             -- phystatus6
			signal hip_pipe_phystatus7       :  std_logic                     := 'X';             -- phystatus7
			signal hip_pipe_rxdata0          :  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata0
			signal hip_pipe_rxdata1          :  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata1
			signal hip_pipe_rxdata2          :  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata2
			signal hip_pipe_rxdata3          :  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata3
			signal hip_pipe_rxdata4          :  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata4
			signal hip_pipe_rxdata5          :  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata5
			signal hip_pipe_rxdata6          :  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata6
			signal hip_pipe_rxdata7          :  std_logic_vector(7 downto 0)  := (others => 'X'); -- rxdata7
			signal hip_pipe_rxdatak0         :  std_logic                     := 'X';             -- rxdatak0
			signal hip_pipe_rxdatak1         :  std_logic                     := 'X';             -- rxdatak1
			signal hip_pipe_rxdatak2         :  std_logic                     := 'X';             -- rxdatak2
			signal hip_pipe_rxdatak3         :  std_logic                     := 'X';             -- rxdatak3
			signal hip_pipe_rxdatak4         :  std_logic                     := 'X';             -- rxdatak4
			signal hip_pipe_rxdatak5         :  std_logic                     := 'X';             -- rxdatak5
			signal hip_pipe_rxdatak6         :  std_logic                     := 'X';             -- rxdatak6
			signal hip_pipe_rxdatak7         :  std_logic                     := 'X';             -- rxdatak7
			signal hip_pipe_rxelecidle0      :  std_logic                     := 'X';             -- rxelecidle0
			signal hip_pipe_rxelecidle1      :  std_logic                     := 'X';             -- rxelecidle1
			signal hip_pipe_rxelecidle2      :  std_logic                     := 'X';             -- rxelecidle2
			signal hip_pipe_rxelecidle3      :  std_logic                     := 'X';             -- rxelecidle3
			signal hip_pipe_rxelecidle4      :  std_logic                     := 'X';             -- rxelecidle4
			signal hip_pipe_rxelecidle5      :  std_logic                     := 'X';             -- rxelecidle5
			signal hip_pipe_rxelecidle6      :  std_logic                     := 'X';             -- rxelecidle6
			signal hip_pipe_rxelecidle7      :  std_logic                     := 'X';             -- rxelecidle7
			signal hip_pipe_rxstatus0        :  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus0
			signal hip_pipe_rxstatus1        :  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus1
			signal hip_pipe_rxstatus2        :  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus2
			signal hip_pipe_rxstatus3        :  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus3
			signal hip_pipe_rxstatus4        :  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus4
			signal hip_pipe_rxstatus5        :  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus5
			signal hip_pipe_rxstatus6        :  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus6
			signal hip_pipe_rxstatus7        :  std_logic_vector(2 downto 0)  := (others => 'X'); -- rxstatus7
			signal hip_pipe_rxvalid0         :  std_logic                     := 'X';             -- rxvalid0
			signal hip_pipe_rxvalid1         :  std_logic                     := 'X';             -- rxvalid1
			signal hip_pipe_rxvalid2         :  std_logic                     := 'X';             -- rxvalid2
			signal hip_pipe_rxvalid3         :  std_logic                     := 'X';             -- rxvalid3
			signal hip_pipe_rxvalid4         :  std_logic                     := 'X';             -- rxvalid4
			signal hip_pipe_rxvalid5         :  std_logic                     := 'X';             -- rxvalid5
			signal hip_pipe_rxvalid6         :  std_logic                     := 'X';             -- rxvalid6
			signal hip_pipe_rxvalid7         :  std_logic                     := 'X';             -- rxvalid7
	
			signal pcie_rstn_npor            :  std_logic                     := 'X';             -- npor
			signal clk_clk                   :  std_logic                     := 'X';             -- clk
			signal reset_reset_n             :  std_logic                     := 'X';              -- reset_n
	
begin
DUT : pcie_de_gen1_x8_ast128 port map (
			hip_ctrl_test_in          => hip_ctrl_test_in,
			hip_ctrl_simu_mode_pipe   => hip_ctrl_simu_mode_pipe,
			hip_serial_rx_in0         => hip_serial_rx_in0,
			hip_serial_rx_in1         => hip_serial_rx_in1,
			hip_serial_rx_in2         => hip_serial_rx_in2,
			hip_serial_rx_in3         => hip_serial_rx_in3,
			hip_serial_rx_in4         => hip_serial_rx_in4,
			hip_serial_rx_in5         => hip_serial_rx_in5,
			hip_serial_rx_in6         => hip_serial_rx_in6,
			hip_serial_rx_in7         => hip_serial_rx_in7,
			hip_serial_tx_out0        => hip_serial_tx_out0,
			hip_serial_tx_out1        => hip_serial_tx_out1,
			hip_serial_tx_out2        => hip_serial_tx_out2,
			hip_serial_tx_out3        => hip_serial_tx_out3,
			hip_serial_tx_out4        => hip_serial_tx_out4,
			hip_serial_tx_out5        => hip_serial_tx_out5,
			hip_serial_tx_out6        => hip_serial_tx_out6,
			hip_serial_tx_out7        => hip_serial_tx_out7,                                  -- tx_out7
			
			hip_pipe_sim_pipe_pclk_in => hip_pipe_sim_pipe_pclk_in,
			
			hip_pipe_phystatus0       => hip_pipe_phystatus0,
			hip_pipe_phystatus1       => hip_pipe_phystatus1, 
			hip_pipe_phystatus2       => hip_pipe_phystatus2,
			hip_pipe_phystatus3       => hip_pipe_phystatus3,
			hip_pipe_phystatus4       => hip_pipe_phystatus4,
			hip_pipe_phystatus5       => hip_pipe_phystatus5,
			hip_pipe_phystatus6       => hip_pipe_phystatus6,
			hip_pipe_phystatus7       => hip_pipe_phystatus7,
			hip_pipe_rxdata0          => hip_pipe_rxdata0,
			hip_pipe_rxdata1          => hip_pipe_rxdata1,
			hip_pipe_rxdata2          => hip_pipe_rxdata2,
			hip_pipe_rxdata3          => hip_pipe_rxdata3,
			hip_pipe_rxdata4          => hip_pipe_rxdata4,
			hip_pipe_rxdata5          => hip_pipe_rxdata5,
			hip_pipe_rxdata6          => hip_pipe_rxdata6,
			hip_pipe_rxdata7          => hip_pipe_rxdata7,
			hip_pipe_rxdatak0         => hip_pipe_rxdatak0,
			hip_pipe_rxdatak1         => hip_pipe_rxdatak1,
			hip_pipe_rxdatak2         => hip_pipe_rxdatak2,
			hip_pipe_rxdatak3         => hip_pipe_rxdatak3,
			hip_pipe_rxdatak4         => hip_pipe_rxdatak4,
			hip_pipe_rxdatak5         => hip_pipe_rxdatak5,
			hip_pipe_rxdatak6         => hip_pipe_rxdatak6,
			hip_pipe_rxdatak7         => hip_pipe_rxdatak7,
			hip_pipe_rxelecidle0      => hip_pipe_rxelecidle0,
			hip_pipe_rxelecidle1      => hip_pipe_rxelecidle1,
			hip_pipe_rxelecidle2      => hip_pipe_rxelecidle2,
			hip_pipe_rxelecidle3      => hip_pipe_rxelecidle3,
			hip_pipe_rxelecidle4      => hip_pipe_rxelecidle4,
			hip_pipe_rxelecidle5      => hip_pipe_rxelecidle5,
			hip_pipe_rxelecidle6      => hip_pipe_rxelecidle6,
			hip_pipe_rxelecidle7      => hip_pipe_rxelecidle7,
			hip_pipe_rxstatus0        => hip_pipe_rxstatus0,
			hip_pipe_rxstatus1        => hip_pipe_rxstatus1,
			hip_pipe_rxstatus2        => hip_pipe_rxstatus2,
			hip_pipe_rxstatus3        => hip_pipe_rxstatus3,
			hip_pipe_rxstatus4        => hip_pipe_rxstatus4,
			hip_pipe_rxstatus5        => hip_pipe_rxstatus5,
			hip_pipe_rxstatus6        => hip_pipe_rxstatus6,
			hip_pipe_rxstatus7        => hip_pipe_rxstatus7,
			hip_pipe_rxvalid0         => hip_pipe_rxvalid0,
			hip_pipe_rxvalid1         => hip_pipe_rxvalid1,
			hip_pipe_rxvalid2         => hip_pipe_rxvalid2,
			hip_pipe_rxvalid3         => hip_pipe_rxvalid3,
			hip_pipe_rxvalid4         => hip_pipe_rxvalid4,
			hip_pipe_rxvalid5         => hip_pipe_rxvalid5,
			hip_pipe_rxvalid6         => hip_pipe_rxvalid6,
			hip_pipe_rxvalid7         => hip_pipe_rxvalid7,
			refclk_clk                => refclk_clk,
			pcie_rstn_npor            => pcie_rstn_pin_perst,
			pcie_rstn_pin_perst       => pcie_rstn_pin_perst,
			clk_clk                   => refclk_clk,
			reset_reset_n             => pcie_rstn_pin_perst,
			
			flash_address 		 		  => flash_address,
			nflash_ce0				 	  => nflash_ce0,
			nflash_ce1				 	  => nflash_ce1,
			nflash_we				 	  => nflash_we,
			nflash_oe				 	  => nflash_oe,
			flash_data			 		  => flash_data,
			nflash_reset		 		  => nflash_reset,
			flash_clk			 		  => flash_clk,
			flash_wait0					  => flash_wait0,
			flash_wait1					  => flash_wait1,
			nflash_adv					  => nflash_adv
			);

end architecture;
