-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.tlp_package.all;


architecture tlp_io_128 of tlp_io_128e is
    constant ARITY : positive := 2;
    subtype  competitors_range is integer range 0 to ARITY-1;

    signal rx_root    : tlp_rx;
    signal rx_subs    : tlp_rx_array(competitors_range);
    --
    signal tx_root    : tlp_tx;
    signal tx_root_bp : tlp_tx_backpressure;
    signal tx_subs    : tlp_tx_array(competitors_range);
    signal tx_subs_bp : tlp_tx_backpressure_array(competitors_range);

begin
    (tx_data, tx_dvalid) <= tx_root;
    rx_root              <= (rx_data, rx_dvalid, rx_sop, rx_eop);
    tx_root_bp.ej_ready  <= ej_ready;

    -- applications are the clients of TLP-switch
    apps : tlp_apps_c -- entity work.tlp_apps_e(loopback_apps)
        generic map (ARITY => ARITY)
        port map (
            rx_subs    => rx_subs,
            --
            tx_subs    => tx_subs,
            tx_subs_bp => tx_subs_bp,
            --
            clk        => clk,
            reset      => reset);

    -- DMX part of TLP-switch
    dmx : tlp_rx_dmx_c
        generic map (ARITY => ARITY)
        port map (root  => rx_root,
                  subs  => rx_subs,
                  --
                  clk   => clk,
                  reset => reset);

    -- MUX part of TLP-switch
    mux : entity work.tlp_tx_mux
        generic map (ARITY => ARITY)
        port map (root    => tx_root,
                  root_bp => tx_root_bp,
                  subs    => tx_subs,
                  subs_bp => tx_subs_bp,
                  --
                  clk     => clk,
                  reset   => reset);
end architecture tlp_io_128;
