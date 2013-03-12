-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

entity clock_gen is
	
	generic (period : time := 10 ns);

	port (clk, reset : out std_logic);

end clock_gen;


architecture clock_gen of clock_gen is

begin  -- clock_gen

	reset <= '1', '0' after period*2;	-- asynchronous reset (active high)
	
	process
	begin
		clk <= '1', '0' after period/2;
		wait for period;
	end process;

end clock_gen;
