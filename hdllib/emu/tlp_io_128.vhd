-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.tlp_package.all;


entity tlp_io_128 is
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
end entity tlp_io_128;

architecture tlp_io_128 of tlp_io_128 is
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
    apps : for i in competitors_range generate
        app : entity work.tlp_fifo_loopback
            generic map (DATA_WIDTH => 128,
                         APP_INDEX  => i)
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

    -- DMX part of TLP-switch
    dmx : entity work.tlp_rx_dmx
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
