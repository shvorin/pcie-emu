-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.util.all;


-- control
entity control is
	generic (capacity : positive);

	port (
		clk, reset		   : in	 std_logic;	 -- asynchronous reset (active high)
		--
		fifo_rd, fifo_wr   : in	 std_logic;	 -- read/write request signal
		rd_ptr, wr_ptr	   : out std_logic_vector(ceil_log2(capacity)-1 downto 0);	-- read/write pointer
		valid_rd, valid_wr : out std_logic;	 -- TODO: remove those ports
		full, empty		   : out std_logic;
		size			   : out std_logic_vector(ceil_log2(capacity+1)-1 downto 0));
end control;

architecture control of control is
	constant ptr_width	: positive := ceil_log2(capacity);
	constant size_width : positive := ceil_log2(capacity+1);

	subtype ptr_range is integer range 0 to capacity-1;

	signal size_s, size_a	  : std_logic_vector(size_width-1 downto 0);
	--
	signal i_valid_rd		  : std_logic;	-- read valid
	signal i_valid_wr		  : std_logic;	-- write valid
	--
	signal i_empty			  : std_logic;
	signal i_full			  : std_logic;
	--
	signal rd_ptr_a, wr_ptr_s : ptr_range;
	signal rd_ptr_s			  : ptr_range;
	signal rd_ovr_a, wr_ovr_s : std_logic;	-- overflow bits
	signal rd_ovr_s			  : std_logic;
	
	function eval_size(constant size : std_logic_vector(size_width-1 downto 0);
					   constant wr	 : std_logic;
					   constant rd	 : std_logic)
		return std_logic_vector is
	begin
		if wr = '1' and rd = '0' then
			return size + 1;

		elsif wr = '0' and rd = '1' then
			return size - 1;

		else
			return size;
		end if;
	end;
	
begin

	rd_ptr_COUNTER : entity work.counter
		generic map (N => capacity)
		port map (clk, reset, i_valid_rd,
				  q0		=> rd_ptr_a,
				  overflow0 => rd_ovr_a,
				  q			=> rd_ptr_s,
				  overflow	=> rd_ovr_s);

	wr_ptr_COUNTER : entity work.counter
		generic map (N => capacity)
		port map (clk, reset, i_valid_wr,
				  q		   => wr_ptr_s,
				  overflow => wr_ovr_s);

	process(reset, clk)
	begin
		if reset = '1' then				-- asynchronous reset (active high)
			size_s <= (others => '0');
			
		elsif clk = '1' and clk'event then
			size_s <= size_a;

		end if;
	end process;

	size_a <= eval_size(size_s, i_valid_wr, i_valid_rd);

	-- determine flags
	i_full	<= to_stdl(rd_ptr_s = wr_ptr_s and rd_ovr_s /= wr_ovr_s);
	i_empty <= to_stdl(wr_ptr_s = rd_ptr_s and rd_ovr_s = wr_ovr_s);

	full  <= i_full;
	empty <= i_empty;

	-- determine request validity
	i_valid_rd <= not i_empty and fifo_rd;
	i_valid_wr <= not i_full and fifo_wr;

	valid_rd <= i_valid_rd;
	valid_wr <= i_valid_wr;

	rd_ptr <= conv_std_logic_vector(rd_ptr_a, ceil_log2(capacity));
	wr_ptr <= conv_std_logic_vector(wr_ptr_s, ceil_log2(capacity));

	size <= size_s;
end control;
