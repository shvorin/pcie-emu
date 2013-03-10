-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

-- Description: This module defines constants (some of them is 
--				parameters in form of constants) and its values
--				that are used by flash_manager and flash_controller

LIBRARY ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package fm_pkg is
	-----------------------------
	-- flash_controller section
	-----------------------------
	
	-- Delay constants that describes flash_controller bus cycles.
	-- Delay is measured in ns.
	constant WR_CYCLE_T 		: natural := 60;
	constant POST_WR_DELAY_T 	: natural := 30;
	constant RD_CYCLE_T 		: natural := 90;
	constant POST_RD_DELAY_T 	: natural := 25;
	constant AFTER_RST_DELAY_T 	: natural := 150;
	
	constant FREQUENCY 			: natural := 250; -- in MHz
	
	-- Constants that determines wide size of flash_managers input fifo
	constant CMD_SZ 			: natural := 1;
	constant ADDR_SZ 			: natural := 24;
	constant DATA_SZ 			: natural := 16;
	
	constant FIFO_DATA_SZ 		: natural := CMD_SZ + ADDR_SZ + DATA_SZ;
	
	-- time in ns of 1 clock cycle.
	constant CYCLE_TIME 		: integer := integer(1000 / FREQUENCY);
	
	-- Delay times in CLK cycles
	constant WR_CYCLE 			: UNSIGNED(7 downto 0) := TO_UNSIGNED(integer(WR_CYCLE_T / CYCLE_TIME) + 1, 8);
	constant POST_WR_DELAY 		: UNSIGNED(7 downto 0) := TO_UNSIGNED(integer(POST_WR_DELAY_T / CYCLE_TIME) + 1, 8);
	constant RD_CYCLE 			: UNSIGNED(7 downto 0) := TO_UNSIGNED(integer(RD_CYCLE_T / CYCLE_TIME) + 1, 8);
	constant POST_RD_DELAY 		: UNSIGNED(7 downto 0) := TO_UNSIGNED(integer(POST_RD_DELAY_T / CYCLE_TIME) + 1, 8);
	constant AFTER_RST_DELAY 	: UNSIGNED(7 downto 0) := TO_UNSIGNED(integer(AFTER_RST_DELAY_T / CYCLE_TIME) + 1, 8);
	
	-----------------------------
	-- flash_manager section
	-----------------------------
	
	-- top and bottom boundaries of TLP address that is translated into flash
	constant ADDR_TOP 			: natural := 58;
	constant ADDR_BOT 			: natural := 35;
	
	-- flash_manager working modes
	constant UL_MODE			: STD_LOGIC_VECTOR(1 downto 0) := "00";
	constant ER_MODE			: STD_LOGIC_VECTOR(1 downto 0) := "01";
	constant WR_MODE			: STD_LOGIC_VECTOR(1 downto 0) := "10";
	constant BP_MODE			: STD_LOGIC_VECTOR(1 downto 0) := "11";
	
	-- data bar address bit
	constant DATA_BAR_BIT_NUM	: natural := 24 + 32 + 3;
	
	-- size of buffer program buffer
	constant BP_BUF_WRD_SZ		: integer := 32;
end package;

	
