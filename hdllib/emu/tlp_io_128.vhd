-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.tlp_package.all;

entity multiapp is
    generic (ARITY : positive);
    port (
        rx_data   : in  std_logic_vector(127 downto 0);
        rx_dvalid : in  std_logic;
        rx_sop    : in  std_logic;
        rx_eop    : in  std_logic;
        --
        tx_data   : out std_logic_vector(127 downto 0);
        tx_dvalid : out std_logic;
        ej_ready  : in  std_logic;
        --
        clk       : in  std_logic;
        reset     : in  std_logic);
end entity multiapp;


architecture multiapp of multiapp is
    subtype competitors_range is integer range 0 to ARITY-1;

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
    apps : for i in 0 to ARITY-1 generate
        app : tlp_io                    -- configurable
            generic map (APP_INDEX => i)
            port map (rx_data   => rx_subs(i).data,
                      rx_dvalid => rx_subs(i).dvalid,
                      rx_sop    => rx_subs(i).sop,
                      rx_eop    => rx_subs(i).eop,
                      tx_data   => tx_subs(i).data,
                      tx_dvalid => tx_subs(i).dvalid,
                      ej_ready  => tx_subs_bp(i).ej_ready,
                      clk       => clk,
                      reset     => reset);
    end generate;

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

end architecture multiapp;
