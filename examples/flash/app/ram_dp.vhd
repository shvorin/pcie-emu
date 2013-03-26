-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.util.all;


package ram_package is
	-- common functions...
	function GCD(constant a0 : natural;
				 constant b0 : natural) return natural;

	-- also asserts argument is power of 2
	function log2(constant n0 : natural) return natural;

	-- also asserts b divides a
	function divide(constant a : natural; constant b : natural) return natural;

	-- RAM-specific functions
	function f_data_width(constant v_common : integer;
						  constant v_spec	: integer) return integer;

	function f_addr_width(constant bit_capacity		 : integer;
						  constant data_width_common : integer;
						  constant data_width_spec	 : integer) return integer;
end ram_package;


package body ram_package is
	function GCD(constant a0 : natural; constant b0 : natural) return natural is
		variable a : natural := a0;
		variable b : natural := b0;
		variable t : natural;
	begin
		while b /= 0 loop
			t := b;
			b := a mod b;
			a := t;
		end loop;

		return a;
	end;

	function log2(constant n0 : natural) return natural is
		variable result : natural := 0;
		variable n		: natural := n0;
	begin
		assert n /= 0 report "log2: argument must be a power of 2";

		while n > 1 loop
			assert n mod 2 = 0 report "log2: argument must be a power of 2";

			n	   := n/2;
			result := result + 1;
		end loop;

		return result;
	end;

	function divide(constant a : natural; constant b : natural) return natural is
	begin
		assert a mod b = 0 report "b must divide a";
		return a/b;
	end;

	function f_data_width(constant v_common : integer;
						  constant v_spec	: integer) return integer is
	begin
		if v_spec /= -1 then
			return v_spec;
		else
			assert v_common /= -1 report "common or specific value must be set";
			return v_common;
		end if;
	end;

	function f_addr_width(constant bit_capacity		 : integer;
						  constant data_width_common : integer;
						  constant data_width_spec	 : integer) return integer is
	begin
		return ceil_log2(bit_capacity / f_data_width(data_width_common, data_width_spec));
	end;
	
end ram_package;


library ieee;
library work;

use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.ram_package.all;
use work.util.all;

-- Dual port syncronous RAM: one port for reading, one for writing.
entity ram_dp is
	generic (
		data_width	  : integer := -1;
		rd_data_width : integer := -1;
		wr_data_width : integer := -1;
		bit_capacity  : integer			-- RAM capacity in bits
		);															   

	port (
		clk		: in  std_logic;
		--
		rd_addr : in  std_logic_vector (f_addr_width(bit_capacity, data_width, rd_data_width) - 1 downto 0);
		do		: out std_logic_vector (f_data_width(data_width, rd_data_width) - 1 downto 0);
		--
		wr_addr : in  std_logic_vector (f_addr_width(bit_capacity, data_width, wr_data_width) - 1 downto 0);
		we		: in  std_logic;
		di		: in  std_logic_vector (f_data_width(data_width, wr_data_width) - 1 downto 0)
		);
end ram_dp;


architecture ram_dp of ram_dp is
	constant rd_data_width0 : integer := f_data_width(data_width, rd_data_width);
	constant wr_data_width0 : integer := f_data_width(data_width, wr_data_width);
	--
	constant rd_addr_width	: integer := f_addr_width(bit_capacity, data_width, rd_data_width);
	constant wr_addr_width	: integer := f_addr_width(bit_capacity, data_width, wr_data_width);
	--
	constant blk_width		: natural := GCD(rd_data_width0, wr_data_width0);
	--
	constant rd_n_blk		: natural := rd_data_width0 / blk_width;
	constant wr_n_blk		: natural := wr_data_width0 / blk_width;
	--
	constant blk_depth		: integer := divide(bit_capacity, blk_width);

	subtype rd_data_range is integer range rd_data_width0-1 downto 0;
	subtype wr_data_range is integer range wr_data_width0-1 downto 0;

	subtype rd_data_t is std_logic_vector(rd_data_range);
	subtype wr_data_t is std_logic_vector(wr_data_range);

	function f_n_banks return natural is
	begin
		assert rd_n_blk = 1 or wr_n_blk = 1 report "oops, internal error";

		if rd_n_blk > 1 then
			return rd_n_blk;
		else
			return wr_n_blk;
		end if;
	end;

	constant n_banks  : natural := f_n_banks;
	constant rd_gt_wd : boolean := rd_n_blk > wr_n_blk;

	subtype banks_range is integer range n_banks - 1 downto 0;

	type conv_addr_t is record
		hi : natural;
		lo : natural;
	end record;

	function conv_addr(addr : std_logic_vector; lo_width : natural)
		return conv_addr_t is

		function hi return natural is
		begin
			-- return conv_integer(addr(addr'high downto lo_width));
			-- FIXME: conv_integer accepts no more than 31 bits, so addr is
-- truncated; hope that's OK since address space is always less than 2Gwords.
			return conv_integer(addr(minimum(addr'high, 30) downto lo_width));
		end;

		function lo return natural is
		begin
			return conv_integer(addr(addr'low + lo_width - 1 downto addr'low));
		end;
	begin

		if lo_width = addr'length then
			return (0, lo);
		elsif lo_width = 0 then
			return (hi, 0);
		else
			return (hi, lo);
		end if;
	end;


	type blk_array is array (banks_range) of std_logic_vector(blk_width-1 downto 0);

	signal WEs : std_logic_vector (banks_range);
	signal DOs : blk_array;
	signal DIs : blk_array;

	signal rd_addr_hi_int, wr_addr_hi_int : integer;
	signal rd_addr_lo_int, wr_addr_lo_int : integer;

	function map_DO(n : integer; DOs : blk_array) return rd_data_t is
		variable result : rd_data_t;
	begin
		if rd_gt_wd then
			for i in banks_range loop
				result(blk_width*(i+1)-1 downto blk_width*i) := DOs(i);
			end loop;
		else
			for i in banks_range loop
				if i = n then
					result := DOs(i);
				end if;
			end loop;
		end if;

		return result;
	end;

	function map_DI(n : integer; DI : wr_data_t) return blk_array is
		variable result : blk_array;
	begin
		if rd_gt_wd then
			for i in banks_range loop
				result(i) := DI;
			end loop;
		else
			for i in banks_range loop
				result(i) := DI(blk_width*(i+1)-1 downto blk_width*i);
			end loop;
		end if;

		return result;
	end;

	function map_WE(n : integer; WE : std_logic) return std_logic_vector is
		variable result : std_logic_vector (banks_range);
	begin
		if rd_gt_wd then
			for i in banks_range loop
				result(i) := to_stdl(n = i);
			end loop;
		else
			result := (others => '1');
		end if;

		return result and WE;
	end;

begin
	banks_of_ram : for i in banks_range generate
		simple_ram : entity work.ram_sdp
			generic map (
				data_width => blk_width,
				depth	   => blk_depth
				)
			port map (clk, rd_addr_hi_int, DOs(i), wr_addr_hi_int, WEs(i), DIs(i));

	end generate;

	do	<= map_DO(rd_addr_lo_int, DOs);
	DIs <= map_DI(wr_addr_lo_int, di);
	WEs <= map_WE(wr_addr_lo_int, we);

	-- NB: rd_addr conversion uses wr_n_blk and vice versa
	(rd_addr_hi_int, rd_addr_lo_int) <= conv_addr(rd_addr, log2(wr_n_blk));
	(wr_addr_hi_int, wr_addr_lo_int) <= conv_addr(wr_addr, log2(rd_n_blk));
	
end ram_dp;
