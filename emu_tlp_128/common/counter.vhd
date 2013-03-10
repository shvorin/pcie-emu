-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.util.all;


-- general purpose counter
entity counter is
	generic (N	   : positive;			-- a number of "states"
			 start : natural := 0		-- initial value
			 );

	port (
		clk		  : in	std_logic;
		reset	  : in	std_logic;
		ena		  : in	std_logic;
		q		  : out integer range 0 to N-1;
		overflow  : out std_logic;		-- to be kept during even cycle
		--
		-- the following outputs are pre-evaluated values of `q' and `overflow'
		q0		  : out integer range 0 to N-1;
		overflow0 : out std_logic);
end counter;

architecture counter of counter is
	subtype cnt_range is natural range 0 to N-1;

	type fstate_t is record
		cnt		 : cnt_range;
		overflow : std_logic;
	end record;

	constant max_cnt   : cnt_range := N-1;

	function next_state(constant state : fstate_t; constant ena : std_logic) return fstate_t is
	begin
		if ena = '1' then
			if state.cnt = max_cnt then
				return (0, not state.overflow);
			else
				return (state.cnt+1, state.overflow);
			end if;
		else
			return state;
		end if;
	end;

	signal snext, scurr : fstate_t;
	
begin
	process (clk, reset)
	begin
		if (reset = '1') then
			scurr <= (start, '0');
			
		elsif clk = '1' and clk'event then
			scurr <= snext;
		end if;
	end process;

	snext <= next_state(scurr, ena);

	(q, overflow)	<= scurr;
	(q0, overflow0) <= snext;
	
end architecture counter;
