-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.



library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity tlp_io is
    generic (
        DATA_WIDTH : natural := 64
        );
    port (
        rx_data   : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        rx_dvalid : in std_logic;

        rx_sop : in std_logic;
        rx_eop : in std_logic;

        tx_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        tx_dvalid : out std_logic;
        ej_ready  : in  std_logic;

        clk   : in std_logic;
        reset : in std_logic
        );
end entity tlp_io;
