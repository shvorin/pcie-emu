-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use work.types.all;
use work.ast256.all;

-- emulation version of wrap
entity wrap_emu is
    port (
        clk   : in std_logic;
        reset : in std_logic;

        -- Avalon-ST
        ast_rx       : in  ast_t;
        ast_tx       : out ast_t;
        ast_tx_bp    : in  ast_bp_t;
        rx_st_bardec : in  std_logic_vector(7 downto 0));
end entity;

architecture wrap_emu of wrap_emu is
begin
end architecture;
