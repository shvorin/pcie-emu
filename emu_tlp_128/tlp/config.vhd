-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use work.util.all;

package config is

    constant NUMBER_OF_PHYS : natural := 6;

    constant USE_TEST_PHYS : natural := 1;

    constant MDC_DIV_EXP : natural := 4;  -- MDC = PCIe_clk/(2^(MDC_DIV_EXP+1))

    constant PCIE_DBG : natural := 0;

    -- TODO: check those config parameters are the same as in pcie_core.vhd
    constant bar_size_mask : integer_array(0 to 7) :=
        (0      => 28,
         2      => 24,
         3      => 24,
         others => 0);

    constant ctrl_bar_num : integer := 2;

end package config;


