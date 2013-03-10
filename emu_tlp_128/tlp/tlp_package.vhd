-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

package tlp_package is

    constant DATA_WIDTH : natural := 64;

    type ch_data_t is array (integer range <>) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    type phy_data_t is array (integer range <>) of std_logic_vector(31 downto 0);
    type phy_lane_t is array (integer range <>) of std_logic_vector(3 downto 0);

    subtype tlp_length_range is integer range 8 downto 0;
    subtype tlp_bar_range is integer range 31 downto 29;

    type bar_info_t is record
        num       : std_logic_vector(2 downto 0);
        size_mask : natural;
    end record;

    ---------------------------------------------------------------------------

    type i_tlp_t is record
        rx_data        : std_logic_vector(DATA_WIDTH - 1 downto 0);
        rx_dvalid      : std_logic;
        rx_sop, rx_eop : std_logic;
        --
        ej_ready       : std_logic;
    end record;

    type o_tlp_t is record
        tx_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);
        tx_dvalid : std_logic;
    end record;

    type i_tlp_array is array (integer range <>) of i_tlp_t;
    type o_tlp_array is array (integer range <>) of o_tlp_t;

end package tlp_package;

