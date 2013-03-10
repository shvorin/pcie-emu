-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.vdata.all;
use work.net_flit.all;
use work.util.all;
use work.credit.all;
use work.rld.all;
use work.cclasses.all;
use work.cc_meta.all;
use work.cc_dbg_ivc;
use work.configure;


entity ivc_buffer is
    generic (
        ID              : natural;
        bubble_capacity : positive      -- queue capacity
        );

    port (
        clk, reset : in  std_logic;     -- asynchronous reset (active high)
        --
        -- rfifo input iface
        vdata_i    : in  vflit_t;
        --
        -- this value must be capable to represent any value from 0 to bubble_capacity
        -- FIXME: name
        rxcredit   : out credit_t;
        -- TODO: assert rxcredit'high >= ceil_log2(bubble_capacity + 1) - 1
        --
        -- rfifo output iface
        vdata_o    : out vflit_t;
        ready_o    : in  boolean;
        --
        -- RAM-like device iface for control
        --
        i_rld_ctrl : in  i_rld_t;
        o_rld_ctrl : out o_rld_t);
end ivc_buffer;


architecture ivc_buffer of ivc_buffer is

    signal vdata_1, vdata_2, vdata_3 : vflit_t;
    signal ready                     : boolean;
    signal sop_pre, eop_post         : boolean;

    signal w_pkt_rx, w_pkt_tx : std_logic_vector(31 downto 0);
    alias pkt_rx              : credit_t is w_pkt_rx(credit_width - 1 downto 0);
    alias pkt_tx              : credit_t is w_pkt_tx(credit_width - 1 downto 0);

    signal o_rld_dbg : o_rld_t;
    signal dbg_value : data_t;

begin
    vdata_o <= vdata_3;

    flit_counter_1 : entity work.net_flit_counter
        port map (
            clk     => clk,
            reset   => reset,
            --
            vdata_i => vdata_i,
            vdata_o => vdata_1,
            --
            ready   => ready,
            --
            sop     => sop_pre);

    rfifo_2 : entity work.rfifo
        generic map (capacity    => configure.max_pktlen * bubble_capacity,
                     data_width  => data_t'length,
                     bubble_size => configure.max_pktlen)
        port map (
            clk          => clk,
            reset        => reset,
            --
            data_i       => vdata_1.data,
            dv_i         => vdata_1.dv,
            ready_i      => ready,
            ready_bubble => open,
            --
            data_o       => vdata_2.data,
            dv_o         => vdata_2.dv,
            ready_o      => ready_o);

    -- FIXME: redundant counter; sop/eop may be reusable
    flit_counter_3 : entity work.net_flit_counter
        port map (
            clk     => clk,
            reset   => reset,
            --
            vdata_i => vdata_2,
            vdata_o => vdata_3,
            ready   => ready_o,
            --
            eop     => eop_post);

    rxcredit <= pkt_rx;

    w_pkt_rx <= (others => '0') when reset = '1' else
                w_pkt_rx + 1 when rising_edge(clk) and eop_post and vdata_3.dv and ready_o;

    dbg : if configure.dbg_buffers generate
        w_pkt_tx <= (others => '0') when reset = '1' else
                    w_pkt_tx + 1 when rising_edge(clk) and sop_pre and vdata_1.dv and ready;

        dbg_value <= w_pkt_rx & w_pkt_tx;
        
        o_rld_dbg <= match(cc_dbg_ivc.offset(offset(f_dbg_ivc), cc_dbg_ivc.f_values, ID), i_rld_ctrl, dbg_value);

        ID_zero : if ID = 0 generate
            o_rld_ctrl <= rld_mux(cc_dbg_ivc.match_consts(offset(f_dbg_ivc), i_rld_ctrl)
                                  & o_rld_dbg);
        end generate;
        -- else generate
        ID_others : if not (ID = 0) generate
            o_rld_ctrl <= o_rld_dbg;
        end generate;
        
        
    end generate;
    -- else if generate
    not_dbg : if not configure.dbg_buffers generate
        o_rld_ctrl <= nothing;
    end generate;

end ivc_buffer;
