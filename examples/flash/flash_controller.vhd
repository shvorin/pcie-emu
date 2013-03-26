-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

--------------------------------------------------------------------------------
-- Flash controller - core that send given commands to flash.
-- Version: 1.0
-- Author: Adamovich Igor <arranje@gmail.com>
-- Description: This core consist of FSM that uses delay counters 
--				to achive right flash bus timings.
-- 				It executes command from fifo_data. When comand is executed
-- 				FSM requests new command by asserting flash_rdreq or waiting for
-- 				availability (flash_empty) of such command.
-- 				Also, when requested, fsm can dissconnect its pins from flash bus 
--				to allow other devices to work with flash. Deny_req should be 
--				asserted to achive this behaivour.
---------------------------------------------------------------------------------	
----------------------------------
-- FORMAT OF COMMAND
----------------------------------
-- Flash command (fifo_data) have followed form:
-- fifo(15 downto 0) - data of command if write
-- fifo (39 downto 16) - address of comand
-- fifo(40) - type of command (read or write) 1 - write, 0 - read

--!!!FIX ME : REMOVED PART WITH READ_REG becouse of testing issues

-- NOTE: This module SHOULD be used only with non-look-ahead FIFO (normal fifo).
LIBRARY ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.fm_pkg.all;

entity flash_controller is
	port (
		clk				: in STD_LOGIC;
		reset			: in STD_LOGIC;
		
		-- Deny_req asserted asks controller to disconnect from flash bus
		-- and deny_ack confirms disconnection
		deny_req		: in STD_LOGIC;
		deny_ack		: out STD_LOGIC;
				
		-- Data read from flash.
		-- rddata_rdy is asserted for one cycle, when new data arrived
		read_data 		: out STD_LOGIC_VECTOR (31 downto 0);
		rddata_rdy		: out STD_LOGIC;
			
		-- fifo_data - input command
		-- fifo_empty - availability of new command
		-- fifo_rdreq - conformation of execution of current command. New command or 
		-- rising of fifo_empty should be provided when this signal is asserted 
		fifo_data		: in STD_LOGIC_VECTOR (FIFO_DATA_SZ - 1 downto 0);
		fifo_empty		: in STD_LOGIC;
		fifo_rdreq		: out STD_LOGIC;
		
		
		test_sig 		: out STD_LOGIC;
		-- Flash interface
		flash_address 		: inout STD_LOGIC_VECTOR (ADDR_SZ - 1 downto 0);
		nflash_ce0			: inout STD_LOGIC;
		nflash_ce1			: inout STD_LOGIC;
		nflash_we			: inout STD_LOGIC;
		nflash_oe			: inout STD_LOGIC;
		flash_data			: inout STD_LOGIC_VECTOR (31 downto 0);	
		nflash_reset		: inout STD_LOGIC;
		flash_clk			: inout STD_LOGIC;
		flash_wait0			: in STD_LOGIC;
		flash_wait1			: in STD_LOGIC;
		nflash_adv			: inout STD_LOGIC
		
	);
end entity;

architecture flash_controller_arch of flash_controller is
	
	type controller_st_mach is (init, init_done, acc_deny, get_cmnd, wr_wait, wr_end,  
									rd_prep, rd_setOE, rd_wait, rd_end);
	signal cur_state, next_state : controller_st_mach;
	
	signal flash_address_s	 	: STD_LOGIC_VECTOR (ADDR_SZ - 1 downto 0);
	signal flash_ce0_s			: STD_LOGIC;
	signal flash_ce1_s			: STD_LOGIC;
	signal flash_we_s			: STD_LOGIC;
	signal flash_oe_s			: STD_LOGIC;
	
	signal flash_data_o			: STD_LOGIC_VECTOR (31 downto 0);
	signal flash_data_i			: STD_LOGIC_VECTOR (31 downto 0);
	signal data_oe				: STD_LOGIC_VECTOR (31 downto 0);
		
	signal init_delay_cnt		: UNSIGNED (7 downto 0);
	signal wr_w8_delay_cnt		: UNSIGNED (7 downto 0);
	signal wr_end_delay_cnt		: UNSIGNED (7 downto 0);
	signal rd_w8_delay_cnt		: UNSIGNED (7 downto 0);
	signal rd_end_delay_cnt		: UNSIGNED (7 downto 0);

	signal wr_cmnd_recv			: STD_LOGIC;
	signal rd_cmnd_recv			: STD_LOGIC;


begin
	process(clk, reset)
	begin
		if (reset = '1') then
			cur_state <= init;
		elsif (rising_edge(clk)) then
			cur_state <= next_state;
		end if;
	end process;

	-- FSM that just statisfies timings
	process (clk, reset)
	begin
		case (cur_state) is
			when init =>
				if (init_delay_cnt = AFTER_RST_DELAY) then
					next_state <= init_done;
				else
					next_state <= init;
				end if;
			
			when init_done =>
				next_state <= get_cmnd;
				
			when get_cmnd =>
				if (deny_req = '1') then
					next_state <= acc_deny;
				elsif (wr_cmnd_recv = '1') then
					next_state <= wr_wait;
				elsif (rd_cmnd_recv = '1') then
					next_state <= rd_prep;
				else
					next_state <= get_cmnd;
				end if;
				
			when acc_deny =>
					if (deny_req = '0') then
						next_state <= get_cmnd;
					else
						next_state <= acc_deny;
					end if;
			
			when wr_wait =>
				if (wr_w8_delay_cnt = WR_CYCLE) then
					next_state <= wr_end;
				else 
					next_state <= wr_wait;
				end if;
				
			when wr_end =>
				if (wr_end_delay_cnt = POST_WR_DELAY) then
					next_state <= get_cmnd;
				else
					next_state <= wr_end;
				end if;
			
			when rd_prep =>
				next_state <= rd_setOE;
				
			when rd_setOE =>
				next_state <= rd_wait;
				
			when rd_wait =>
				if ((rd_w8_delay_cnt = RD_CYCLE) and (flash_wait0 = '1')	and (flash_wait1 = '1')) then
					next_state <= rd_end;
				else
					next_state <= rd_wait;
				end if;
			
			when rd_end =>
				if (rd_end_delay_cnt = POST_RD_DELAY) then
					next_state <= get_cmnd;
				else
					next_state <= rd_end;
				end if;
				
		end case;	
				
	end process;

	-- determine type of command
	wr_cmnd_recv <= 	'1' when ((fifo_empty = '0') and (fifo_data(58) = '1'))
				else	'0';
	
	rd_cmnd_recv <=		'1' when ((fifo_empty = '0') and (fifo_data(58) = '0'))
				else	'0';
	
	--------------------------------------
	-- DELAY counters
	--------------------------------------
	
	process(clk, reset)
	begin
		if (reset = '1') then
			init_delay_cnt <= (others => '0');
		elsif (rising_edge(clk)) then
			if (cur_state = init) then
				init_delay_cnt <= init_delay_cnt + 1;
			end if;
		end if;
	end process;
	
	process(clk, reset)
	begin
		if (reset = '1') then
			wr_w8_delay_cnt <= (others => '0');
		elsif (rising_edge(clk)) then
			if ((cur_state = get_cmnd) and (next_state = wr_wait)) then
				wr_w8_delay_cnt <= (others => '0');
			elsif (next_state = wr_wait) then
				wr_w8_delay_cnt <= wr_w8_delay_cnt + 1;
			end if;
		end if;
	end process;
	
	process(clk, reset)
	begin
		if (reset = '1') then
			wr_end_delay_cnt <= (others => '0');
		elsif (rising_edge(clk)) then
			if ((cur_state = wr_wait) and (next_state = wr_end)) then
				wr_end_delay_cnt <= (others => '0');
			elsif (next_state = wr_end) then
				wr_end_delay_cnt <= wr_end_delay_cnt + 1;
			end if;
		end if;
	end process;
	
	process(clk, reset)
	begin
		if (reset = '1') then
			rd_w8_delay_cnt <= (others => '0');
		elsif (rising_edge(clk)) then	
			if ((cur_state = rd_setOE) and (next_state = rd_wait)) then
				rd_w8_delay_cnt <= (others => '0');
			elsif (next_state = rd_wait) and (rd_w8_delay_cnt /= RD_CYCLE) then
				rd_w8_delay_cnt <= rd_w8_delay_cnt + 1;
			end if;
		end if;
	end process;
	
	process(clk, reset)
	begin
		if (reset = '1') then
			rd_end_delay_cnt <= (others => '0');
		elsif (rising_edge(clk)) then
			if ((cur_state = rd_wait) and (next_state = rd_end)) then
				rd_end_delay_cnt <= (others => '0');
			elsif (next_state = rd_end) then
				rd_end_delay_cnt <= rd_end_delay_cnt + 1;
			
			end if;
		end if;
	end process;
	
	----------------------------------
	-- END OF DELAY counters
	----------------------------------
	
	-- Read data to register from flash bus, when read operating is performed
	-- and timings statisfied.
	-- rddata_rdy indicates presence of new data.
	process(clk, reset)
	begin
		if (reset = '1') then
			read_data <= (others => '1');
			rddata_rdy <= '0';
		elsif (rising_edge(clk)) then
		if ((cur_state = rd_wait) and (next_state = rd_end)) then
				read_data <= flash_data;
				rddata_rdy <= '1';
			else
				rddata_rdy <= '0';
			end if;
		end if;
	end process;
	
	fifo_rdreq <= 	'1' when (((cur_state = rd_end) or (cur_state = wr_end)) and 
								(next_state = get_cmnd) and (fifo_empty = '0'))
			else	'0';
			
	deny_ack <= 	'1' when (next_state = acc_deny)
			else	'0';
	
	-- Flash controlling signals are non inverted to arhive more
	-- clearness. 
		
	flash_ce0_s <= '1';
	flash_ce1_s <= '1';
	
	flash_address_s <= fifo_data (57 downto 32);
	
	flash_we_s <= 	'1' when (cur_state = wr_wait)
			else 	'0';
			
	flash_oe_s <=	'1' when ((cur_state = rd_setOE) or (cur_state = rd_wait))
			else 	'0';
			
	flash_data_i <= fifo_data (31 downto 0);
	
	-- Tristated flash output
	-- Also inverts flash signels, because really they are inverted
	
	nflash_ce0 <= 	'Z' when (next_state = acc_deny) or (reset = '1')
			else	not(flash_ce0_s);
	nflash_ce1 <= 	'Z' when (next_state = acc_deny) or (reset = '1')
			else	not(flash_ce1_s);
			
	nflash_adv <= 'Z' when (next_state = acc_deny) or (reset = '1') 
				else '0';
					
	
	flash_address <= 	(others => 'Z') when (next_state = acc_deny) or (reset = '1')
				else	flash_address_s;
				
	test_sig <= '1' when (next_state = acc_deny) or (reset = '1') else '0';
	
	nflash_we <= 	'Z' when (next_state = acc_deny) or (reset = '1')
			else	not(flash_we_s);
			
	nflash_oe <= 	'Z' when (next_state = acc_deny) or (reset = '1')
			else	not(flash_oe_s);
	
	flash_data <= 	(others => 'Z') when ((next_state = acc_deny) or (cur_state = rd_prep) or (flash_oe_s = '1')) or (reset = '1')
									else	flash_data_i;

		
	nflash_reset <= 'Z' when (next_state = acc_deny) or (reset = '1')
			else ('1');
	
	flash_clk	<= 'Z' when (next_state = acc_deny) or (reset = '1')
			else '0';	
		
end architecture;



