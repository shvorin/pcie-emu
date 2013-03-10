-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

architecture arch_emu of fifo_phy_fifo is
begin
    q       <= data;
    rdempty <= not wrreq;
    wrfull  <= not rdreq;

    -- stubbed signals

    txd    <= (others => '0');
    txc    <= (others => '0');
    tx_clk <= rx_clk;
    
end architecture arch_emu;
