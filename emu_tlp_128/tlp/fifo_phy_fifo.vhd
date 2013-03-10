-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.tlp_package.all;

entity fifo_phy_fifo is
    generic (
        PMC2PCI_WIDTH : natural := 13;
        DATA_WAIT     : natural := 9);

    port (
        data    : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        wrreq   : in  std_logic;
        rdreq   : in  std_logic;
        q       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        wrfull  : out std_logic;
        rdempty : out std_logic;
        rdusedw : out std_logic_vector(PMC2PCI_WIDTH - 1 downto 0);

        clk   : in std_logic;
        reset : in std_logic;

        ------------------------------------------

        clkPHY : in std_logic;          -- 250 MHz

        rstb   : in  std_logic;
        txd    : out std_logic_vector(31 downto 0);
        txc    : out std_logic_vector(3 downto 0);
        tx_clk : out std_logic;

        rxd    : in std_logic_vector(31 downto 0);
        rxc    : in std_logic_vector(3 downto 0);
        rxh    : in std_logic_vector(3 downto 0);
        rx_clk : in std_logic;

        fault_tx : in std_logic;
        fault_rx : in std_logic);
end entity fifo_phy_fifo;
