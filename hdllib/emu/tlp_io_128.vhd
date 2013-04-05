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

    component tlp_switch is
        generic (ARITY : positive);
        port (
            rx_root    : in  tlp_rx;
            rx_subs    : out tlp_rx_array(0 to ARITY-1);
            --
            tx_root    : out tlp_tx;
            tx_root_bp : in  tlp_tx_backpressure;
            tx_subs    : in  tlp_tx_array(0 to ARITY-1);
            tx_subs_bp : out tlp_tx_backpressure_array(0 to ARITY-1);
            --
            clk        : in  std_logic;
            reset      : in  std_logic);
    end component;

begin
    (tx_data, tx_dvalid) <= tx_root;
    rx_root              <= (rx_data, rx_dvalid, rx_sop, rx_eop);
    tx_root_bp.ej_ready  <= ej_ready;

    -- applications are the clients of TLP-switch
    apps : tlp_apps_c                   -- configurable
        generic map (ARITY => ARITY)
        port map (
            rx_subs    => rx_subs,
            --
            tx_subs    => tx_subs,
            tx_subs_bp => tx_subs_bp,
            --
            clk        => clk,
            reset      => reset);

    -- TLP-switch
    switch : tlp_switch                 -- configurable
        generic map (
            ARITY => ARITY)
        port map (
            rx_root    => rx_root,
            rx_subs    => rx_subs,
            --
            tx_root    => tx_root,
            tx_root_bp => tx_root_bp,
            tx_subs    => tx_subs,
            tx_subs_bp => tx_subs_bp,
            --
            clk        => clk,
            reset      => reset);

end architecture tlp_io_128;
