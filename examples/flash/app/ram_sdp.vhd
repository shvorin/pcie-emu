-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- Simple dual port syncronous RAM: one port for reading, one for writing.
entity ram_sdp is
	generic (
		data_width : integer;
		depth	   : integer
		);															   

	port (
		clk : in std_logic;
		--
		rd_addr : in  integer range 0 to depth-1;
		do		: out std_logic_vector (data_width-1 downto 0);
		--
		wr_addr : in integer range 0 to depth-1;
		we		: in std_logic;
		di		: in std_logic_vector (data_width-1 downto 0)
		);
end ram_sdp;


architecture ram_sdp of ram_sdp is
	type ram_type is array(depth-1 downto 0) of std_logic_vector(data_width-1 downto 0);

	signal ram : ram_type;

begin
	process (clk)
	begin
		if rising_edge(clk) then
			do <= RAM(rd_addr);

			if we = '1' then
				RAM(wr_addr) <= di;
			end if;
		end if;
	end process;
end ram_sdp;
