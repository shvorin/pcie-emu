-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

-- FIXME: if we got packet that reads from flash and then got packet that 
-- reads registers there may be collision

LIBRARY ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.fm_pkg.all;
use work.tlp_package.all;
use work.util.all;

entity flash_manager_regs is
	port (

		clk					: in STD_LOGIC;
		reset				: in STD_LOGIC;
		
		-- Empty signal from flash_manager input fifo
		fifo_empty			: in STD_LOGIC;
		
		-- Signal that indicates overflow of flash_manager input fifo
		input_fifo_err		: in STD_LOGIC;
		
		-- Read status from flash and signal
		-- that indicates that new status was read
		sts_reg				: in STD_LOGIC_VECTOR (15 downto 0);
		sts_changed			: in STD_LOGIC;
		
		flash_read			: in STD_LOGIC;
		-- Current mode chosen by processor program
		work_mode			: out STD_LOGIC_VECTOR (1 downto 0);
		
		flash_bsy			: in STD_LOGIC;
		
		test_sig 		: in STD_LOGIC;
		
		-- TLP_IO interface
		rx_data     		: in std_logic_vector(127 downto 0);
		rx_dvalid   		: in std_logic;
		rx_sop      		: in std_logic;
		rx_eop      		: in std_logic;
		tx_data     		: out std_logic_vector(127 downto 0);
		tx_dvalid   		: out std_logic;
		ej_ready    		: in std_logic
	);
end entity;

architecture flash_manager_regs_arch of flash_manager_regs is 
	type rx_state_mash is (idle, wr_reg);
	signal rx_cur_state : rx_state_mash;
	
	type tx_state_mash is (idle, wait_for_rdy, send_hdr, send_reg);
	signal tx_cur_state, tx_next_state : tx_state_mash;
	
	signal got_read : STD_LOGIC;
	
	signal reg 		: STD_LOGIC_VECTOR (63 downto 0);
	signal read_reg	: STD_LOGIC_VECTOR (127 downto 0);
	
	signal info_qqw			: tlp_info;
	signal pkt_addr			: STD_LOGIC_VECTOR(31 downto 0);
begin
	------------------------------------
	-- RX logic
	-------------------------------------
	
	info_qqw <= header_info (rx_data);
	
	pkt_addr <=  rx_data(127 downto 96) when (info_qqw.is_4dw)
				else rx_data(95 downto 64);
				
	-- FSM that recieves packets from TLP_IO adressed to flash_manager
	-- registers. If packet is write - writes data to register.
	
	got_read <= 	'1' when (rx_sop = '1') and ((info_qqw.kind = kind_MRd32) 
												or (info_qqw.kind = kind_Mrd64))
				else 	'0';
	
	process(clk, reset)
	begin
		if (reset = '1') then
			rx_cur_state <= idle;
		elsif (rising_edge(clk)) then
			case rx_cur_state is
				when idle =>
					if (rx_sop = '1') and ((info_qqw.kind = kind_MWr32) or (info_qqw.kind = kind_MWr64)) 
							and (pkt_addr(ADDR_TOP downto ADDR_BOT) = REG_ADDR) then
						rx_cur_state <= wr_reg;
					end if;
					
				when wr_reg =>
					if (rx_eop = '1') then
						rx_cur_state <= idle;
					end if;
					
			end case;
		end if;
	end process;
	
	process(clk, reset)
	begin
		if (reset = '1') then
			read_reg <= (others => '0');
		elsif (rising_edge(clk)) then
			if ((rx_cur_state = idle) and 
				(got_read = '1') and (pkt_addr(ADDR_TOP downto ADDR_BOT) = REG_ADDR)) then
				read_reg <= rx_data;
			end if;	
		end if;
	end process;

	------------------------------------
	-- TX logic
	-------------------------------------

	process(clk, reset)
	begin
		if (reset = '1') then
			tx_cur_state <= idle;
		elsif (rising_edge(clk)) then
			tx_cur_state <= tx_next_state;
		end if;
	end process;
	
	-- FSM that sends complition to read request. Can w8 if TLP_IO is not ready now
	process(clk)
	begin
		case tx_cur_state is
			when idle =>
				if (got_read = '1') and (pkt_addr(ADDR_TOP downto ADDR_BOT) = REG_ADDR) and 
					(ej_ready = '1') and (flash_read = '0') then
					tx_next_state <= send_hdr;
				elsif (got_read = '1') and (pkt_addr(ADDR_TOP downto ADDR_BOT) = REG_ADDR) and 
					(flash_read = '0') then 
					tx_next_state <= wait_for_rdy;
				else
					tx_next_state <= idle;
				end if;
			
			when wait_for_rdy =>
				if (ej_ready = '1') and (flash_read = '0') then
					tx_next_state <= send_hdr;
				else
					tx_next_state <= wait_for_rdy;
				end if;
				
			when send_hdr =>
				if (ej_ready = '1') then
					tx_next_state <= send_reg;
				else 
					tx_next_state <= send_hdr;
				end if;
				
			when send_reg =>
				if (ej_ready = '1') then
					tx_next_state <= idle;
				else 
					tx_next_state <= send_reg;
				end if;
				
		end case;
	end process;
	
	tx_data <= mk_cpl_packet (read_reg, MY_PCI_ID) when (tx_cur_state = send_hdr)
				else	x"0000000000000000" & reg;
	
	tx_dvalid <= to_stdl(tx_cur_state /= idle);
							
	--------------------------------
	-- Flash manager register
	--------------------------------
	-- reg (7 downto 0) is a status read from flash
	-- reg (9 downto 8) is a device work mode. 
	--		(Unlock, erase,program, buffered program, etc...)
	-- reg (10) - indicates that input fifo had overflow
	-- reg (62) - indicates that device currently working with flash.
				-- This bit is used while swithching between buffered program mode and 
				-- other modes. If core is in buffered mode and flash_bsy bit is set to '1', 
				-- program should not change mode until flash_bsy become '0'
	-- reg (63) - indicates is device input fifo empty or not
	
	process(clk, reset)
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				reg <= (others => '0');
			elsif (rx_cur_state = wr_reg) and (rx_dvalid = '1') then
				reg (10 downto 0) <= rx_data(10 downto 0);
			
			elsif (sts_changed = '1') then
				reg(0) <= sts_reg(0) or sts_reg(8) or reg(0);
				reg(1) <= sts_reg(1) or sts_reg(9) or reg(1);
				reg(2) <= sts_reg(2) or sts_reg(10) or reg(2);
				reg(3) <= sts_reg(3) or sts_reg(11) or reg(3);
				reg(4) <= sts_reg(4) or sts_reg(12) or reg(4);
				reg(5) <= sts_reg(5) or sts_reg(13) or reg(5);
				reg(6) <= sts_reg(6) or sts_reg(14) or reg(6);
				reg(7) <= (sts_reg(7) and sts_reg(15)) or reg(7);
			elsif (input_fifo_err = '1') then
				reg(10) <= '1';
			end if;
			
			reg (11) <= test_sig;
			reg(63) <= fifo_empty;
			reg(62) <= flash_bsy;

		end if;
	end process;
	
	work_mode <= reg (9 downto 8);
end architecture;
