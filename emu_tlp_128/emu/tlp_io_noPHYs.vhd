-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.tlp_package.all;

architecture tlp_io_noPHYs of tlp_io is
begin

    ni : entity work.ni_iface
        generic map (use_PHYs => false)

        port map (
            -- tlp_io iface
            -------------------------------------------------------------------
            rx_data, rx_dvalid, rx_sop, rx_eop, tx_data, tx_dvalid, ej_ready, clk, reset,

            -- dummy PHYs
            -------------------------------------------------------------------
            clkPHY => '0',

            rstb_arr   => (others => '0'),
            txd_arr    => open,
            txc_arr    => open,
            tx_clk_arr => open,

            rxd_arr    => (others => (others => '0')),
            rxc_arr    => (others => (others => '0')),
            rxh_arr    => (others => (others => '0')),
            rx_clk_arr => (others => '0'),

            fault_tx_arr => (others => '0'),
            fault_rx_arr => (others => '0'));

end architecture tlp_io_noPHYs;
