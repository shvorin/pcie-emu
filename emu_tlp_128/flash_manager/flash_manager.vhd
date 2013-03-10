-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

------------------------------------------------------------------
-- Flash manager - FPGA core working with flash memory
-- Version: 1.0
-- Author: Adamovich Igor <arranje@gmail.com>
-- Description: This core recievs TLP_IO packets (simplified PCIE packets,
-- 				internal standart). Each packet is interpretated as sequence of 
-- 				64bit commands. This interpretation depends upon current working mode
-- 				that is writen before to core registers. For instance, if working mode
-- 				is erase mode, each 64bit word is a erase command. It means that
-- 				for this command several flash commands would be send(so 1 flash manager 
-- 				command corresponds to several flash commands). The result
-- 				would be that specified flash block is erased or error occured. Any way
-- 				status of operation can be found in core registers. More information
-- 				can be found in doc/ directory.
------------------------------------------------------------------
----------------------------------
--- Some notes and FIXMEs
----------------------------------

-- NOTE :if there is read from flash and then comes read from regs, read from regs will be ignored.
-- NOTE: only 1 at time read request from flash can be statisfied. If there are two such requests
--			second will be ignored.

-- NOTE: i suppose that there are operations of only one type at time (only write, unlock and etc).

-- NOTE: 	i suppose that read packet comes without pauses (1st cycle - 1st qword, 
--			2nd cycle - 2nd qword)

LIBRARY ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.fm_pkg.all;

entity flash_manager is
	port (
		clk					: in STD_LOGIC;
		reset				: in STD_LOGIC;
		
		-- TLP_IO tx and rx interface
		-- TLP_IO is our internal standart that specifies interface
		-- between arbitrary core and our PCIE core. See tlp_io.html.
		rx_data     		: in std_logic_vector(63 downto 0);
		rx_dvalid   		: in std_logic;
		rx_sop      		: in std_logic;
		rx_eop      		: in std_logic;
		
		tx_data     		: out std_logic_vector(63 downto 0);
		tx_dvalid   		: out std_logic;
		ej_ready    		: in std_logic;

		-- 2 Parallel flash loader signals. Used to solve problem with
		-- flash bus arbitration
		pfl_flash_acc_req	: in STD_LOGIC;
		pfl_flash_acc_grnt	: out STD_LOGIC;
			
		-- flash interface
		flash_address 		: inout STD_LOGIC_VECTOR (ADDR_SZ - 1 downto 0);
		nflash_ce			: inout STD_LOGIC;
		nflash_we			: inout STD_LOGIC;
		nflash_oe			: inout STD_LOGIC;
		flash_data			: inout STD_LOGIC_VECTOR (15 downto 0)
	);
end entity;

architecture flash_manager_arch of flash_manager is 
	component flash_manager_regs is
		port (
			clk					: in STD_LOGIC;
			reset				: in STD_LOGIC;
			
			fifo_empty			: in STD_LOGIC;
			flash_bsy			: in STD_LOGIC;
			input_fifo_err		: in STD_LOGIC;
			
			sts_reg				: in STD_LOGIC_VECTOR (7 downto 0);
			sts_changed			: in STD_LOGIC;
			
			flash_read			: in STD_LOGIC;
			
			work_mode			: out STD_LOGIC_VECTOR (1 downto 0);
			
			rx_data     		: in std_logic_vector(63 downto 0);
			rx_dvalid   		: in std_logic;
			rx_sop      		: in std_logic;
			rx_eop      		: in std_logic;
			tx_data     		: out std_logic_vector(63 downto 0);
			tx_dvalid   		: out std_logic;
			ej_ready    		: in std_logic
		);
	end component;
	
	component flash_controller is
		port (
			clk				: in STD_LOGIC;
			reset			: in STD_LOGIC;
				
			deny_req		: in STD_LOGIC;
			deny_ack		: out STD_LOGIC;
	
			read_data 		: out STD_LOGIC_VECTOR (15 downto 0);
			rddata_rdy		: out STD_LOGIC;
			
			fifo_data		: in STD_LOGIC_VECTOR (FIFO_DATA_SZ - 1 downto 0);
			fifo_empty		: in STD_LOGIC;
			fifo_rdreq		: out STD_LOGIC;
			
			flash_address 	: inout STD_LOGIC_VECTOR (ADDR_SZ - 1 downto 0);
			nflash_ce		: inout STD_LOGIC;
			nflash_we		: inout STD_LOGIC;
			nflash_oe		: inout STD_LOGIC;
			flash_data		: inout STD_LOGIC_VECTOR (15 downto 0)
		
		);
	end component;
	
	component fm_fifo48 IS
		PORT
		(
			clock		: IN STD_LOGIC ;
			data		: IN STD_LOGIC_VECTOR (47 DOWNTO 0);
			rdreq		: IN STD_LOGIC ;
			wrreq		: IN STD_LOGIC ;
			almost_empty		: OUT STD_LOGIC ;
			empty		: OUT STD_LOGIC ;
			full		: OUT STD_LOGIC ;
			q			: OUT STD_LOGIC_VECTOR (47 DOWNTO 0)
		);
	end component;
	
	component buf_fifo16 IS
		PORT
		(
			clock		: IN STD_LOGIC ;
			data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			rdreq		: IN STD_LOGIC ;
			wrreq		: IN STD_LOGIC ;
			empty		: OUT STD_LOGIC ;
			full		: OUT STD_LOGIC ;
			q			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	end component;
	
	type rx_state_mach is (idle, recv_data);
	signal rx_cur_state, rx_next_state : rx_state_mach;
	
	type ul_state_mach is (idle, fst_cycle, scnd_cycle, rd_sts_cycle, clr_sts_cycle);
	type er_state_mach is (idle, fst_cycle, scnd_cycle, rd_sts_cycle, clr_sts_cycle);
	type wr_state_mach is (idle, fst_cycle, scnd_cycle, rd_sts_cycle, clr_sts_cycle);
	type rd_state_mach is (idle, fst_cycle, scnd_cycle);
	signal ul_cur_state, ul_next_state : ul_state_mach;
	signal er_cur_state, er_next_state : er_state_mach;
	signal wr_cur_state, wr_next_state : wr_state_mach;
	signal rd_cur_state, rd_next_state : rd_state_mach;
	
	type rdrq_state_mach is (idle, wait_for_rdy, recv_hdr1);
	signal rdrq_cur_state, rdrq_next_state : rdrq_state_mach;
	
	-- buffered programm buffer state machine
	type bpbuf_state_mach is (idle, clear_buf, fill_buf, give_buf);
	signal bpbuf_cur_state, bpbuf_next_state : bpbuf_state_mach;
	
	type bp_state_mach is (idle, clear_buf, sync, ask_for_buf, req_program,	check_sts, 
				write_word_cnt, write_word, confirm, rd_op_sts, clr_sts);
	signal bp_cur_state, bp_next_state : bp_state_mach;
	
	type tx_state_mach is (idle, wait_for_rdy, send_hdr0, send_hdr1, send_data);
	signal tx_cur_state, tx_next_state : tx_state_mach;
	
	type pfl_state_mash is (idle, req_deny, deny);
	signal pfl_cur_state : pfl_state_mash; 
	
	signal zero48				: STD_LOGIC_VECTOR (47 downto 0);
	signal zero10				: STD_LOGIC_VECTOR (9 downto 0);
	
	signal is_read				: STD_LOGIC;
	signal got_read				: STD_LOGIC;
	
	signal got_answer			: STD_LOGIC;
	signal read_reg				: STD_LOGIC_VECTOR (127 downto 0);
	
	signal addr					: UNSIGNED (23 downto 0);
	signal rd_addr				: STD_LOGIC_VECTOR (23 downto 0);
	
	signal read_data			: STD_LOGIC_VECTOR (15 downto 0);
	signal rddata_rdy			: STD_LOGIC;
	signal input_fifo_err		: STD_LOGIC;
	signal sts_changed			: STD_LOGIC;
	signal work_mode			: STD_LOGIC_VECTOR (1 downto 0);
	
	signal deny_req				: STD_LOGIC;
	signal deny_ack				: STD_LOGIC;
	signal cmd_req				: STD_LOGIC;
	signal tx_data_from_regs 	: STD_LOGIC_VECTOR (63 downto 0);
	signal tx_dvalid_from_regs	: STD_LOGIC;
	
	signal ul_cmd				: STD_LOGIC_VECTOR (FIFO_DATA_SZ - 1 downto 0);
	signal er_cmd				: STD_LOGIC_VECTOR (FIFO_DATA_SZ - 1 downto 0);
	signal wr_cmd				: STD_LOGIC_VECTOR (FIFO_DATA_SZ - 1 downto 0);
	signal rd_cmd				: STD_LOGIC_VECTOR (FIFO_DATA_SZ - 1 downto 0);
	signal bp_cmd				: STD_LOGIC_VECTOR (FIFO_DATA_SZ - 1 downto 0);
	signal cmd					: STD_LOGIC_VECTOR (FIFO_DATA_SZ - 1 downto 0);

	signal ul_cmd_nrdy 			: STD_LOGIC;
	signal er_cmd_nrdy 			: STD_LOGIC;
	signal wr_cmd_nrdy 			: STD_LOGIC;
	signal rd_cmd_nrdy 			: STD_LOGIC;
	signal bp_cmd_nrdy			: STD_LOGIC;
	signal cmd_nrdy 			: STD_LOGIC;
	signal flash_bsy			: STD_LOGIC;
	
	signal buf_req 				: STD_LOGIC;
	signal read_next			: STD_LOGIC;
	signal word_conseq			: STD_LOGIC;
	signal is_space				: STD_LOGIC;
	signal new_block			: STD_LOGIC;
	signal fifo_rdreq_bp		: STD_LOGIC;
	signal prev_addr			: UNSIGNED(23 downto 0);
	signal zero24				: STD_LOGIC_VECTOR(23 downto 0);
	signal free_space			: UNSIGNED(5 downto 0);
	signal buf_strt_addr		: STD_LOGIC_VECTOR(23 downto 0);
	signal buf_cur_cnt			: UNSIGNED(5 downto 0);
	
	signal buf_rdreq			: STD_LOGIC;
	signal buf_wrreq			: STD_LOGIC;
	signal buf_empty			: STD_LOGIC;
	signal buf_full				: STD_LOGIC;
	signal buf_q				: STD_LOGIC_VECTOR (15 downto 0);
	signal buf_data				: STD_LOGIC_VECTOR (15 downto 0);
	
	signal buf_rdy				: STD_LOGIC;
	signal bp_word_cnt			: UNSIGNED(5 downto 0);
	signal bp_addr				: UNSIGNED(23 downto 0);
	signal bp_base_addr			: STD_LOGIC_VECTOR(23 downto 0);
	
	signal flash_read			: STD_LOGIC;
	
	signal fifo_data 			: STD_LOGIC_VECTOR (47 downto 0);
	signal fifo_rdreq			: STD_LOGIC;
	signal fifo_wrreq			: STD_LOGIC;
	signal fifo_empty			: STD_LOGIC;
	attribute syn_keep: boolean;
	attribute syn_keep of fifo_empty: signal is true;
	
	signal fifo_full			: STD_LOGIC;
	signal fifo_a_empty			: STD_LOGIC;
	signal fifo_q				: STD_LOGIC_VECTOR (47 downto 0);
	signal fifo_usedw			: STD_LOGIC_VECTOR (3 downto 0);
begin

	zero48 <= (others => '0');

------------------------------------
--	Store data in fifo
------------------------------------	
	-- is incomint TLP_IO packet read or not
	is_read <= rx_data(9);
	
	process(clk, reset)
	begin
		if (reset = '1') then
			rx_cur_state <= idle;
		elsif (rising_edge(clk)) then
			rx_cur_state <= rx_next_state;
		end if;
	end process;
	
	-- BAR is devided into 2 parts: registers and window to flash. Data from TLP_IO
	-- packet should be stored in fifo only if its target is flash and it is write packet. And 
	-- when we got such packet - store it in fifo.
	-- if someone writes more then free space, data would be currapted
	process(clk, reset)
	begin
		case rx_cur_state is
			when idle =>
				if ((rx_sop = '1') and (rx_eop = '0') and (rx_data(DATA_BAR_BIT_NUM) = '1') 
						and (is_read = '0') ) then
					rx_next_state <= recv_data;
				else
					rx_next_state <= idle;
				end if;
				
			
			when recv_data =>
				if (rx_eop = '1') then
					rx_next_state <= idle;
				else
					rx_next_state <= recv_data;
				end if;
				
		end case;
	end process;
	
	-- Calculating address of current data word from incoming TLP_IO packet
	process(clk, reset)
	begin
		if (reset = '1') then
			addr <= (others => '0');
		elsif (rising_edge(clk)) then
			if ((rx_cur_state = idle) and (rx_next_state = recv_data)) then
				addr <= UNSIGNED(rx_data(ADDR_TOP downto ADDR_BOT));
			elsif (rx_dvalid = '1') then
				addr <= addr + 1;
			end if;
		end if;
	end process;
	
	-- indicate error when fifo is overfilled
	input_fifo_err <= 	'1' when ((rx_cur_state = recv_data) and (fifo_full = '1'))
				else 	'0';
				
	fifo_wrreq <= 	'1' when ((rx_cur_state = recv_data) and (rx_dvalid = '1'))
			else	'0';
			
	fifo_data <= STD_LOGIC_VECTOR(addr) & rx_data(23 downto 0);
	
-----------------------------
--  Block Unlocking Logic
-----------------------------

	process (clk, reset)
	begin
		if (reset = '1') then
			ul_cur_state <= idle;
		elsif (rising_edge(clk)) then
			ul_cur_state <= ul_next_state;
		end if;
	end process;
	
	-- I suppose that after unlock operation there is next unlock operation or
	-- fifo is empty (changing mode is done over empty command fifo).
	
	-- This state machine simply indicates 2 steps: send unlock command to flash
	-- and confirm it.
	process(clk, reset, cmd_req)
	begin
		case ul_cur_state is
			when idle =>
				if ((fifo_empty = '0') and (work_mode = UL_MODE)
											and (flash_bsy = '0')) then
					ul_next_state <= fst_cycle;
				else
					ul_next_state <= idle;
				end if;
				
			when fst_cycle =>
				if (cmd_req = '1') then
					ul_next_state <= scnd_cycle;
				else
					ul_next_state <= fst_cycle;
				end if;
				
			when scnd_cycle =>
				if (cmd_req = '1') then
					ul_next_state <= rd_sts_cycle;
				else
					ul_next_state <= scnd_cycle;
				end if;
				
			when rd_sts_cycle =>
				if ((cmd_req = '1') and (read_data(7) = '1')) then
					ul_next_state <= clr_sts_cycle;
				else
					ul_next_state <= rd_sts_cycle;
				end if;
				
			when clr_sts_cycle =>
				if ((cmd_req = '1') and (fifo_a_empty = '0')) then
					ul_next_state <= fst_cycle;
				elsif (cmd_req = '1') then
					ul_next_state <= idle;
				else
					ul_next_state <= clr_sts_cycle;
				end if;
		end case;
	end process;
	
	-- send commands when state machine says to do it
	process(clk, reset)
	begin
		if (reset = '1') then
			ul_cmd <= (others => '0');
		elsif (rising_edge(clk)) then
			if (ul_next_state = fst_cycle) then
				ul_cmd(40) <= '1';
				ul_cmd(39 downto 16) <= fifo_q(23 downto 0);
				ul_cmd(15 downto 0) <= "00000000" & "0110" & "0000";
			elsif (ul_next_state = scnd_cycle) then
				ul_cmd(40) <= '1';
				ul_cmd(39 downto 16) <= fifo_q(23 downto 0);
				ul_cmd(15 downto 0) <= "00000000" & "1101" & "0000";
			elsif (ul_next_state = rd_sts_cycle) then
				ul_cmd(40) <= '0';
				ul_cmd(39 downto 16) <= (others => '0');
				ul_cmd(15 downto 0) <= (others => '0');
			else 
				ul_cmd(40) <= '1';
				ul_cmd(39 downto 16) <= (others => '0');
				ul_cmd(15 downto 0) <= "00000000" & "0101" & "0000";
			end if;
		end if;			
	end process;
	
	-- fifo_empty - state machine cant give next command. flash_controller should w8
	ul_cmd_nrdy <= 	'1' when (ul_cur_state = idle)
			else	'0';
	
-----------------------------
--  Block Erase Logic
-----------------------------
	process (clk, reset)
	begin
		if (reset = '1') then
			er_cur_state <= idle;
		elsif (rising_edge(clk)) then
			er_cur_state <= er_next_state;
		end if;
	end process;
	
	-- I suppose that after erase operation there is next erase operation or
	-- fifo is empty (changing mode is done over empty command fifo).
	
	-- This state machine simply indicates 4 consecutive steps: send erase command to the flash,
	-- confirm it, check result status of the flash and clear status register of the flash.
	process(clk, reset, cmd_req)
	begin
		case er_cur_state is
			when idle =>
				if ((fifo_empty = '0') and (work_mode = ER_MODE) 
											and (flash_bsy = '0')) then
					er_next_state <= fst_cycle;
				else
					er_next_state <= idle;
					

				end if;
				
			when fst_cycle =>
				if (cmd_req = '1') then
					er_next_state <= scnd_cycle;
				else
					er_next_state <= fst_cycle;
				end if;
				
			when scnd_cycle =>
				if (cmd_req = '1') then
					er_next_state <= rd_sts_cycle;
				else
					er_next_state <= scnd_cycle;
				end if;
				
			when rd_sts_cycle =>
				if ((cmd_req = '1') and (read_data(7) = '1')) then
					er_next_state <= clr_sts_cycle;
				else
					er_next_state <= rd_sts_cycle;
				end if;
				
			when clr_sts_cycle =>
				if ((cmd_req = '1') and (fifo_a_empty = '0')) then
					er_next_state <= fst_cycle;
				elsif (cmd_req = '1') then
					er_next_state <= idle;
				else
					er_next_state <= clr_sts_cycle;
				end if;
		end case;
	end process;
	
	-- send commands when state machine says to do it
	process(clk, reset)
	begin
		if (reset = '1') then
			er_cmd <= (others => '0');
		elsif (rising_edge(clk)) then
			if (er_next_state = fst_cycle) then
				er_cmd(40) <= '1';
				er_cmd(39 downto 16) <= fifo_q(23 downto 0);
				er_cmd(15 downto 0) <= "00000000" & "0010" & "0000";
			elsif (er_next_state = scnd_cycle) then
				er_cmd(40) <= '1';
				er_cmd(39 downto 16) <= fifo_q(23 downto 0);
				er_cmd(15 downto 0) <= "00000000" & "1101" & "0000";
			elsif (er_next_state = rd_sts_cycle) then
				er_cmd(40) <= '0';
				er_cmd(39 downto 16) <= (others => '0');
				er_cmd(15 downto 0) <= (others => '0');
			else 
				er_cmd(40) <= '1';
				er_cmd(39 downto 16) <= (others => '0');
				er_cmd(15 downto 0) <= "00000000" & "0101" & "0000";
			end if;
		end if;			
	end process;

	-- fifo_empty - state machine cant give next command. flash_controller should w8
	er_cmd_nrdy <= 	'1' when (er_cur_state = idle)
			else	'0';

-----------------------------
--  Write Logic
-----------------------------
	process (clk, reset)
	begin
		if (reset = '1') then
			wr_cur_state <= idle;
		elsif (rising_edge(clk)) then
			wr_cur_state <= wr_next_state;
		end if;
	end process;
	
	-- I suppose that after write operation there is next write operation or
	-- fifo is empty (changing mode is done over empty command fifo).
	
	-- This state machine simply indicates 4 consecutive steps: send program command to the flash,
	-- send data and address, check result status of the flash and clear status register of the flash.
	process(clk, reset, cmd_req)
	begin
		case wr_cur_state is
			when idle =>
				if ((fifo_empty = '0') and (work_mode = WR_MODE) 
											and (flash_bsy = '0')) then
					wr_next_state <= fst_cycle;
				else
					wr_next_state <= idle;
				end if;
				
			when fst_cycle =>
				if (cmd_req = '1') then
					wr_next_state <= scnd_cycle;
				else
					wr_next_state <= fst_cycle;
				end if;
				
			when scnd_cycle =>
				if (cmd_req = '1') then
					wr_next_state <= rd_sts_cycle;
				else
					wr_next_state <= scnd_cycle;
				end if;
				
			when rd_sts_cycle =>
				if ((cmd_req = '1') and (read_data(7) = '1')) then
					wr_next_state <= clr_sts_cycle;
				else
					wr_next_state <= rd_sts_cycle;
				end if;
				
			when clr_sts_cycle =>
				if ((cmd_req = '1') and (fifo_a_empty = '0')) then
					wr_next_state <= fst_cycle;
				elsif (cmd_req = '1') then
					wr_next_state <= idle;
				else
					wr_next_state <= clr_sts_cycle;
				end if;
		end case;
	end process;
	
	-- send commands when state machine says to do it
	process(clk, reset)
	begin
		if (reset = '1') then
			wr_cmd <= (others => '0');
		elsif (rising_edge(clk)) then
			if (wr_next_state = fst_cycle) then
				wr_cmd(40) <= '1';
				wr_cmd(39 downto 16) <= fifo_q(47 downto 24);
				wr_cmd(15 downto 0) <= "00000000" & "0100" & "0000";
			elsif (wr_next_state = scnd_cycle) then
				wr_cmd(40) <= '1';
				wr_cmd(39 downto 16) <= fifo_q(47 downto 24);
				wr_cmd(15 downto 0) <= fifo_q(15 downto 0);
			elsif (wr_next_state = rd_sts_cycle) then
				wr_cmd(40) <= '0';
				wr_cmd(39 downto 16) <= (others => '0');
				wr_cmd(15 downto 0) <= (others => '0');
			else 
				wr_cmd(40) <= '1';
				wr_cmd(39 downto 16) <= (others => '0');
				wr_cmd(15 downto 0) <= "00000000" & "0101" & "0000";
			end if;
		end if;			
	end process;

	-- fifo_empty - state machine cant give next command. flash_controller should w8
	wr_cmd_nrdy <= 	'1' when (wr_cur_state = idle)
			else	'0';
			
-----------------------------
--  Read Logic
-----------------------------

	process (clk, reset)
	begin
		if (reset = '1') then
			rd_cur_state <= idle;
		elsif (rising_edge(clk)) then
			rd_cur_state <= rd_next_state;
		end if;
	end process;
	
	-- Strongly recommended to send 2 different read packets (to registers and to flash). They can overlap
	-- in TLP_IO bus. 
	
	-- Wait until all working with flash is done and then send read request. In other case read request can
	-- give no answer.
	
	-- This state machine simply indicates 2 consecutive steps: send read command to the flash and
	-- recieve data read.
	process(clk, reset, cmd_req)
	begin
		case rd_cur_state is
			when idle =>
				-- when there is no another operations and read request recieved
				if ((fifo_empty = '1') and (got_read = '1') and (rx_data(DATA_BAR_BIT_NUM) = '1') and (flash_bsy = '0')) then
					rd_next_state <= fst_cycle;
				else
					rd_next_state <= idle;
				end if;
				
			when fst_cycle =>
				if (cmd_req = '1') then
					rd_next_state <= scnd_cycle;
				else
					rd_next_state <= fst_cycle;
				end if;
				
			when scnd_cycle =>
				if (cmd_req = '1') then
					rd_next_state <= idle;
				else
					rd_next_state <= scnd_cycle;
				end if;
		end case;
	end process;
	
	-- send commands when state machine says to do it
	process(clk, reset)
	begin
		if (reset = '1') then
			rd_cmd <= (others => '0');
		elsif (rising_edge(clk)) then
			if (rd_next_state = fst_cycle) then
				rd_cmd(40) <= '1';
				rd_cmd(39 downto 16) <= (others => '0');
				rd_cmd(15 downto 0) <= "00000000" & "1111" & "1111";
			else
				rd_cmd(40) <= '0';
				rd_cmd(39 downto 16) <= rd_addr(23 downto 0);
				rd_cmd(15 downto 0) <= (others => '0');
			end if;
		end if;			
	end process;
	
	-- fifo_empty - state machine cant give next command. flash_controller should w8
	rd_cmd_nrdy <= 	'1' when (rd_cur_state = idle)
			else	'0';
			
---------------------------------------------------------
-- Buffered program logic
---------------------------------------------------------
	-- Logic copies data into buffer and checks it to be continiously and not to cross 
	-- 32-word(for example 1f - 20) boundary
	process(clk, reset)
	begin
		if (reset = '1') then
			bpbuf_cur_state <= idle;
		elsif (rising_edge(clk)) then
			bpbuf_cur_state <= bpbuf_next_state;
		end if;
	end process;
	
	-- This process describes state machine that copies data from input fifo to 
	-- internal buffer. Copied data is in consecutive order. When flash is ready to
	-- get more data, this logic provides this buffer with some descriptors (like addrress of first word and
	-- total count of words) and then starts to copy new part of data.
	process(clk, reset)
	begin
		-- Start working when it is our mode, have data and flash is not busy or is busy by us
		case bpbuf_cur_state is
			when idle =>
				if ( (fifo_empty = '0') and ((work_mode = BP_MODE) and 
						((flash_bsy = '0') or (bp_cur_state /= idle))) ) then
					bpbuf_next_state <= fill_buf;
				else
					bpbuf_next_state <= idle;
				end if;
				
			-- if flash is ready to recieve data - then get all appropriate data from input fifo and
			-- then should w8 for new - just go sent it. 
			when fill_buf =>
				if (work_mode /= BP_MODE) then
					bpbuf_next_state <= clear_buf;
				elsif (buf_req = '1') and (read_next = '0') then
					bpbuf_next_state <= give_buf;
				else
					bpbuf_next_state <= fill_buf;
				end if;
				
			-- i suppose that buffer is allways taken when give_buf state achived (buf_req = '1' always)
			when give_buf =>
				bpbuf_next_state <= idle;
				
			when clear_buf =>
				if (buf_cur_cnt = 0) then
					bpbuf_next_state <= idle;
				else
					bpbuf_next_state <= clear_buf;
				end if;		
				
		end case;				
	end process;
	
	read_next <= 	'1' when (fifo_empty = '0') and (word_conseq = '1') and (is_space = '1')
			else	'0';
			
	fifo_rdreq_bp <= 	'1' when (bpbuf_cur_state = fill_buf) and (read_next = '1')
				else	'0';
				
	buf_wrreq <= fifo_rdreq_bp;
	
	word_conseq <= 	'1' when (((fifo_q(47 downto 24) = STD_LOGIC_VECTOR(prev_addr + 1)) and 
								(fifo_q(28 downto 24) /= "00000")) or (new_block = '1')) 
							
			else	'0';
						
	-- determine is current fifo word first in transfer serie or not
	process(clk, reset)
	begin
		if (reset = '1') then
			new_block <= '1';
		elsif (rising_edge(clk)) then
			if (bpbuf_cur_state = idle) then
				new_block <= '1';
			elsif ((bpbuf_cur_state = fill_buf) and (read_next = '1')) then
				new_block <= '0';
			end if;
		end if;
	end process;						
	
	-- keep address of privous word to determine is new word consecutive or not
	process(clk, reset)
	begin
		if (reset = '1') then
			prev_addr <= (others => '0');
		elsif (rising_edge(clk)) then
			if ((bpbuf_cur_state = fill_buf) and (read_next = '1'))then
				prev_addr <= UNSIGNED(fifo_q(47 downto 24));
			end if;
		end if;
	end process;
	
	-- keep inforation about total free space in buffer
	process(clk, reset)
	begin
		if (reset = '1') then
			free_space <= to_UNSIGNED(BP_BUF_WRD_SZ, 6);
		elsif (rising_edge(clk)) then
			if (buf_wrreq = '1') and (buf_rdreq = '1') then
				free_space <= free_space;
			elsif (buf_wrreq = '1') then
				free_space <= free_space - 1;
			elsif (buf_rdreq = '1') then
				free_space <= free_space + 1;
			end if;
		end if;		
	end process;
	
	is_space <= 	'0' when (free_space = 0) 
			else	'1';
			
	-- keep address of first word that would be copied (first word allways would be copied) as start address.
	process(clk, reset)
	begin
		if (reset = '1') then
			buf_strt_addr <= (others => '0');
		elsif (rising_edge(clk)) then
			if (bpbuf_cur_state = idle) then
				buf_strt_addr <= fifo_q(47 downto 24);
			end if;
		end if;
	end process;
	
	-- Number of words in current transaction
	-- It is copied and cleared when flash operation cycle starts.
	-- It is needed, bacause new and old data is stored in same buffer, while
	-- flash operation is in progress. It is count of NEW data.
	process(clk, reset)
	begin
		if (reset = '1') then
			buf_cur_cnt <= (others => '0');
		elsif (rising_edge(clk)) then
			if (bp_cur_state = clear_buf) then
				buf_cur_cnt <= buf_cur_cnt - 1;
			elsif (bpbuf_cur_state = give_buf) then
				buf_cur_cnt <= (others => '0');
			elsif (buf_wrreq = '1') then
				buf_cur_cnt <= buf_cur_cnt + 1;
			end if;
		end if;
	end process;
	
	
	-- buffer is ready when we give it. And when it is rdy it should be taken.
	buf_rdy <= 	'1' when (bpbuf_cur_state = give_buf)
		else	'0';
		
	buf_req <= 	'1' when (bp_cur_state = ask_for_buf)
		else	'0';
	
	process(clk, reset)
	begin
		if (reset = '1') then
			bp_cur_state <= idle;
		elsif (rising_edge(clk)) then
			bp_cur_state <= bp_next_state;
		end if;
	end process; 

	-- This state machine takes buffer and it's descriptors then
	-- asks flash is its buffer ready to achive data. When buffer ready 
	-- FSM indicates to send data. After that confirms buffered program operation,
	-- and checks status of this operation until it is complete, then clear
	-- content of status register.
	-- Else it clears buffer, when buffer is filled and device mode changed
	
	process(clk, reset, cmd_req)
	begin
		case bp_cur_state is 
			when idle =>
				if ((work_mode = BP_MODE) and (flash_bsy = '0') and (buf_cur_cnt /= 0)) then
					bp_next_state <= ask_for_buf;
				elsif (bpbuf_cur_state = clear_buf) then
					bp_next_state <= clear_buf;
				else
					bp_next_state <= idle;
				end if;
			
			when clear_buf =>
				-- this condition is right - because on last cycle, when buf_cur_cnt = 1, 
				-- next_state will be idle, but cur_state still clear_buf. Therefore
				-- buf_cur_cnt will be decreased
				if (buf_cur_cnt = 1) then
					bp_next_state <= sync;
				else
					bp_next_state <= clear_buf;
				end if;					
				
			when sync =>
				-- this state synchronizes both state machines in clear states. In this state buf_cur_cnt = 0
				bp_next_state <= idle;
			
			when ask_for_buf =>
				if (buf_rdy = '1') then
					bp_next_state <= req_program;
				elsif (work_mode /= BP_MODE) then
					bp_next_state <= idle;
				else
					bp_next_state <= ask_for_buf;
				end if;
				
			when req_program =>
				if (cmd_req = '1') then
					bp_next_state <= check_sts;
				else
					bp_next_state <= req_program;
				end if;
				
			when check_sts =>
				if ((cmd_req = '1') and (read_data(7) = '1')) then
					bp_next_state <= write_word_cnt;
				elsif (cmd_req = '1') then
					bp_next_state <= req_program;
				else
					bp_next_state <= check_sts;
				end if;
				
			when write_word_cnt =>
				if (cmd_req = '1') then
					bp_next_state <= write_word;
				else
					bp_next_state <= write_word_cnt;
				end if;
				
			when write_word =>
				if ((cmd_req = '1') and (bp_word_cnt = 1)) then
					bp_next_state <= confirm;
				else
					bp_next_state <= write_word;
				end if;
				
			when confirm =>
				if (cmd_req = '1') then
					bp_next_state <= rd_op_sts;
				else
					bp_next_state <= confirm;
				end if;
			
			when rd_op_sts =>
				if ((cmd_req = '1') and (read_data(7) = '1')) then
					bp_next_state <= clr_sts;
				else
					bp_next_state <= rd_op_sts;
				end if;
				
			when clr_sts =>
				if (cmd_req = '1') then
					bp_next_state <= idle;
				else
					bp_next_state <= clr_sts;
				end if;
		end case;
	end process;
	
	
	-- when buffer is given, to this descriptor is assigned new value.
	-- bp_addr is current address of programmed word. It is used to iterate
	-- trough buffer. 
	process(clk, reset, cmd_req)
	begin
		if (reset = '1') then
			bp_addr <= (others => '0');
		elsif (rising_edge(clk)) then
			if (bpbuf_next_state = give_buf) then
				bp_addr <= UNSIGNED(buf_strt_addr);
			elsif ((bp_cur_state = write_word) and (cmd_req = '1')) then
				bp_addr <= bp_addr + 1;
			end if;
		end if;
	end process;
	
	-- This descriptor is base (start) address of operation. It is complitly the same
	-- as bp_addr, but it willn't increment while iterate trough buffer
	process(clk, reset)
	begin
		if (reset = '1') then
			bp_base_addr <= (others => '0');
		elsif (rising_edge(clk)) then
			if (bpbuf_next_state = give_buf) then
				bp_base_addr <= buf_strt_addr;
			end if;
		end if;
	end process;
	
	-- count of data that should be send
	process(clk, reset, cmd_req)
	begin
		if (reset = '1') then
			bp_word_cnt <= (others => '0');
		elsif (rising_edge(clk)) then
			if (bpbuf_cur_state = give_buf) then
				bp_word_cnt <= buf_cur_cnt;
			elsif ((bp_cur_state = write_word) and (cmd_req = '1')) then
				bp_word_cnt <= bp_word_cnt - 1;			
			end if;
		end if;
	end process;
	
	zero10 <= (others => '0');
	-- process that provides commands to flash
	process(clk, reset)
	begin
		if (reset = '1') then
			bp_cmd <= (others => '0');
		elsif (rising_edge(clk)) then
			if (bp_next_state = req_program) then
				bp_cmd(40) <= '1';
				bp_cmd(39 downto 16) <= STD_LOGIC_VECTOR(bp_base_addr);
				bp_cmd(15 downto 0) <= "00000000" & "1110" & "1000";
			elsif (bp_next_state = check_sts) then
				bp_cmd(40) <= '0';
				bp_cmd(39 downto 16) <= (others => '0');
				bp_cmd(15 downto 0) <= (others => '0');
			elsif (bp_next_state = write_word_cnt) then
				bp_cmd(40) <= '1';
				bp_cmd(39 downto 16) <= STD_LOGIC_VECTOR(bp_base_addr);
				bp_cmd(15 downto 0) <= zero10 & STD_LOGIC_VECTOR(bp_word_cnt - 1);
			elsif (bp_next_state = write_word) then
				bp_cmd(40) <= '1';
				bp_cmd(39 downto 16) <= STD_LOGIC_VECTOR(bp_addr);
				bp_cmd(15 downto 0) <= buf_q;
			elsif (bp_next_state = confirm) then
				bp_cmd(40) <= '1';
				bp_cmd(39 downto 16) <= STD_LOGIC_VECTOR(bp_base_addr);
				bp_cmd(15 downto 0) <= "00000000" & "1101" & "0000";
			elsif (bp_next_state = rd_op_sts) then
				bp_cmd(40) <= '0';
				bp_cmd(39 downto 16) <= (others => '0');
				bp_cmd(15 downto 0) <= (others => '0');
			else 
				bp_cmd(40) <= '1';
				bp_cmd(39 downto 16) <= (others => '0');
				bp_cmd(15 downto 0) <= "00000000" & "0101" & "0000";
			end if;
		end if;			
	end process;
	
	buf_rdreq <= 	'1' when (((bp_cur_state = write_word) and (cmd_req = '1')) or (bp_cur_state = clear_buf))
			else	'0';
			
	-- fifo_empty - state machine cant give next command. flash_controller should w8
	bp_cmd_nrdy <= 	'1' when ((bp_cur_state = idle) or (bp_cur_state = ask_for_buf))
			else	'0';
			
			
	buf_data <= fifo_q(15 downto 0);
BUF: buf_fifo16 port map (
	clock	=> clk,
	data	=> buf_data,
	rdreq	=> buf_rdreq,
	wrreq	=> buf_wrreq,
	empty	=> buf_empty,
	full	=> buf_full,
	q		=> buf_q
	);
---------------------------------------------------------
-- Logic that recievs read requests and send complitions
-----------------------------------	---------------------
	
	process(clk, reset)
	begin
		if (reset = '1') then
			rdrq_cur_state <= idle;
		elsif (rising_edge(clk)) then
			rdrq_cur_state <= rdrq_next_state;
		end if;
	end process;
			
	got_read <= '1' when (rdrq_next_state = recv_hdr1)
		else	'0';
	
	-- This state machine handles case when there is incoming read flash packet.
	-- With other logic - the FSM keeps read packet to make right complition and wait
	-- until the flash read reqested data. 
	process(clk, reset)
	begin
		case rdrq_cur_state is
			when idle =>
				if ((rx_sop = '1') and (rx_data(DATA_BAR_BIT_NUM) = '1') and (is_read = '1') ) then
					rdrq_next_state <= recv_hdr1;
				else
					rdrq_next_state <= idle;
				end if;
				
			-- recieving last q-word of read
			when recv_hdr1 =>
				rdrq_next_state <= wait_for_rdy;
				
			-- wait while manager reads data from flash
			when wait_for_rdy =>
				if (rddata_rdy = '1') then
					rdrq_next_state <= idle;
				else
					rdrq_next_state <= wait_for_rdy;
				end if;				
		end case;
	end process;
	
	-- indicate when requested data was read
	got_answer <= 	'1' when ((rdrq_cur_state = wait_for_rdy) and (rddata_rdy = '1'))
			else	'0';
	
	process(clk, reset)
	begin
		if (reset = '1') then
			tx_cur_state <= idle;
		elsif (rising_edge(clk)) then
			tx_cur_state <= tx_next_state;
		end if;
	end process;
	
	-- This state machine handels tx logic. When get response
	-- from flsh with requested data, keeped TLP_IO read header will be send,
	-- followed by requested data. 
	-- Also the FSM handles case when TLP_IO is not ready to recieve some part of packet.
	process(clk, reset)
	begin
		case tx_cur_state is
			when idle =>
				if (got_answer = '1') and (ej_ready = '1') then
					tx_next_state <= send_hdr0;
				elsif (got_answer = '1') then
					tx_next_state <= wait_for_rdy;
				else
					tx_next_state <= idle;
				end if;
				
			when wait_for_rdy =>
				if (ej_ready = '1') then
					tx_next_state <= send_hdr0;
				else
					tx_next_state <= wait_for_rdy;
				end if;
				
			when send_hdr0 =>
				if (ej_ready = '1') then
					tx_next_state <= send_hdr1;
				else 
					tx_next_state <= send_hdr0;
				end if;
				
			when send_hdr1 =>
				if (ej_ready = '1') then
					tx_next_state <= send_data;
				else
					tx_next_state <= send_hdr1;
				end if;
			
			when send_data =>
				if (ej_ready = '1') then
					tx_next_state <= idle;
				else 
					tx_next_state <= send_data;
				end if;
				
		end case;
	end process;
	
	flash_read <= 	'1' when (rdrq_cur_state /= idle) or (tx_cur_state /= idle)
			else	'0';
	-- temprory keep read packets for correct complition
	process(clk, reset)
	begin
		if (reset = '1') then
			read_reg <= (others => '0');
		elsif (rising_edge(clk)) then
			if (rdrq_next_state = recv_hdr1) then
				read_reg (63 downto 0) <= rx_data(63 downto 0);
			elsif (rdrq_cur_state = recv_hdr1) then
				read_reg (127 downto 64) <= rx_data(63 downto 0);
			end if;	
		end if;
	end process;
	
	-- Address in flash should be read
	rd_addr <= read_reg (ADDR_TOP downto ADDR_BOT);
	
	tx_data <= 	STD_LOGIC_VECTOR(UNSIGNED(read_reg(63 downto 0)) + 1) 
										when (tx_cur_state = send_hdr0)
		else	read_reg(127 downto 64) when (tx_cur_state = send_hdr1)
		else	zero48 & read_data when (tx_cur_state = send_data)
		else	tx_data_from_regs;
	
	tx_dvalid <= 	'1' when (tx_cur_state /= idle)
		else		tx_dvalid_from_regs;
	
----------------------------------------------------
-- Other main signals
----------------------------------------------------
									
	-- indicate to device registers that status read from flash was changed. Its status 
	-- of last operation
	sts_changed <= 	'1' when ((rddata_rdy = '1') and ((er_cur_state = rd_sts_cycle) or 
								(wr_cur_state = rd_sts_cycle) or (bp_cur_state = rd_op_sts)))
			else	'0';

	-- Read request from input fifo
	fifo_rdreq <= 	'1' when (((ul_cur_state = clr_sts_cycle) and (ul_next_state /= clr_sts_cycle)) or
							((er_cur_state = clr_sts_cycle) and (er_next_state /= clr_sts_cycle)) or
							((wr_cur_state = clr_sts_cycle) and (wr_next_state /= clr_sts_cycle)))
			else	fifo_rdreq_bp;
	
	-- Command to flash_controller
	cmd <= 		ul_cmd when (ul_cur_state /= idle)
		else	er_cmd when (er_cur_state /= idle)
		else	wr_cmd when (wr_cur_state /= idle)
		else	bp_cmd when (bp_cur_state /= idle)
		else	rd_cmd;
		
	-- Signal that indicates to flash_controller that FSMs cant provide next command now
	cmd_nrdy <=	ul_cmd_nrdy when (ul_cur_state /= idle)
		else	er_cmd_nrdy when (er_cur_state /= idle)
		else	wr_cmd_nrdy when (wr_cur_state /= idle)
		else	bp_cmd_nrdy when (bp_cur_state /= idle)
		else	rd_cmd_nrdy;
		
	flash_bsy <= 	'1' when ((ul_cur_state /= idle) or (er_cur_state /= idle)	or 
								(wr_cur_state /= idle) or (rd_cur_state /= idle) or 
								(bp_cur_state /= idle))
			else	'0';

-------------------------------------------------------
-- Logic that gives to PFL access to bus
-------------------------------------------------------
	process(clk, reset, cmd_req)
	begin
		if (reset = '1') then
			pfl_cur_state <= idle;
		elsif (rising_edge(clk)) then
			case pfl_cur_state is
				-- give access only when operation is complited or FSMs is in idle
				when idle =>
					if ( (pfl_flash_acc_req = '1') and

							(((work_mode = UL_MODE) and ((ul_cur_state = idle) or 
								((ul_cur_state = clr_sts_cycle) and (cmd_req = '1')))) or
							
							((work_mode = ER_MODE) and ((er_cur_state = idle) or 
								((er_cur_state = clr_sts_cycle) and (cmd_req = '1')))) or
							
							((work_mode = WR_MODE) and ((wr_cur_state = idle) or 
								((wr_cur_state = clr_sts_cycle) and (cmd_req = '1')))) or
					
							((work_mode = BP_MODE) and ((bp_cur_state = idle) or 
								((bp_cur_state = confirm) and (cmd_req = '1'))))) ) then
						pfl_cur_state <= req_deny;
					end if;
					
				-- ask flash_controller to discconect from bus
				when req_deny =>
					if (deny_ack = '1') then
						pfl_cur_state <= deny;
					end if;
					
				when deny =>
					if (pfl_flash_acc_req = '0') then
						pfl_cur_state <= idle;
					end if;
			end case;				
		end if;
	end process;
	

	deny_req <= '1' when ((pfl_cur_state = req_deny) or (pfl_cur_state = deny))
		else 	'0';
			
	pfl_flash_acc_grnt <= 	'1' when pfl_cur_state = deny
					else 	'0';
REGS : flash_manager_regs port map (
	clk				=> clk,
	reset			=> reset,
	fifo_empty		=> fifo_empty,
	sts_reg			=> read_data(7 downto 0),
	sts_changed		=> sts_changed,
	input_fifo_err 	=> input_fifo_err,
	flash_read		=> flash_read, 
	flash_bsy		=> flash_bsy,
	work_mode		=> work_mode,
	rx_data     	=> rx_data,
	rx_dvalid   	=> rx_dvalid,
	rx_sop			=> rx_sop,
	rx_eop    		=> rx_eop,
	tx_data     	=> tx_data_from_regs,
	tx_dvalid   	=> tx_dvalid_from_regs,
	ej_ready    	=> ej_ready
);

FIFO48 : fm_fifo48 port map (
	clock	=> clk,
	data	=> fifo_data,
	rdreq	=> fifo_rdreq,
	wrreq	=> fifo_wrreq,
	empty	=> fifo_empty,
	almost_empty => fifo_a_empty,
	full	=> fifo_full,
	q		=> fifo_q
);

flash_cntl : flash_controller port map (
	clk				=> clk,
	reset			=> reset,
	deny_req		=> deny_req,
	deny_ack		=> deny_ack,
	read_data 		=> read_data,
	rddata_rdy		=> rddata_rdy,
	fifo_data		=> cmd,
	fifo_empty		=> cmd_nrdy,
	fifo_rdreq		=> cmd_req,
	flash_address 	=> flash_address,
	nflash_ce		=> nflash_ce, 
	nflash_we		=> nflash_we,
	nflash_oe		=> nflash_oe,
	flash_data		=> flash_data 
	);
end architecture;
