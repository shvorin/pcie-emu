-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.tlp_package.all;
use work.util.all;

entity tlp_tx_128 is
    port (
        clk_in : in std_logic;
        rsts   : in std_logic;

        tx_stream_data0_0     : out std_logic_vector(74 downto 0);
        tx_stream_data0_1     : out std_logic_vector(74 downto 0);
        tx_stream_valid0      : out std_logic;
        tx_stream_ready0      : in  std_logic;
        tx_stream_mask0       : in  std_logic;
        tx_stream_fifo_empty0 : in  std_logic;
        tx_stream_cred0       : in  std_logic_vector(36 - 1 downto 0);  -- FIXME

        tx_data   : in  std_logic_vector(127 downto 0);
        tx_dvalid : in  std_logic;
        ej_ready  : out std_logic);
end entity tlp_tx_128;

architecture tlp_tx_128 of tlp_tx_128 is
    type parsed_tx_stream is record
        data  : std_logic_vector(127 downto 0);
        err   : std_logic;
        empty : std_logic;
        sop   : std_logic;
        eop   : std_logic;
    end record;

    type raw_tx_stream is record
        data0_0, data0_1 : std_logic_vector(74 downto 0);
    end record;

    function combine(tx_st : parsed_tx_stream) return raw_tx_stream is
    begin
        return (
            -- 74       73          72            71:64   63:0
            tx_st.err & tx_st.sop & tx_st.empty & x"00" & tx_st.data(63 downto 0),
            tx_st.err & tx_st.sop & tx_st.eop & x"00" & tx_st.data(127 downto 64));
    end;

    signal tx_st : parsed_tx_stream;

    signal sop, eop  : std_logic;
    signal ej_ready0 : std_logic;
    signal info      : tlp_info;

begin
    markup : entity work.tlp_markup
        port map (
            tx_data   => tx_data,
            tx_dvalid => tx_dvalid,
            ej_ready  => ej_ready0,
            --
            sop       => sop,
            eop       => eop,
            info      => info,
            --
            clk       => clk_in,
            reset     => rsts);

    tx_st            <= (tx_data, '0', to_stdl(info.is_eofempty), sop, eop);
    ej_ready         <= ej_ready0;
    ej_ready0        <= '1';            -- FIXME
    tx_stream_valid0 <= tx_dvalid;

    tx_stream_valid0                       <= tx_dvalid;
    (tx_stream_data0_0, tx_stream_data0_1) <= combine(tx_st);
end architecture tlp_tx_128;
