-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.vdata.all;
use work.credit.all;
use work.link_data.all;
use work.util.all;
use work.rld.all;
use work.cclasses.all;
use work.cc_meta.all;
use work.cc_dbg_ilink;
use work.configure;


entity ilink_adapter is
    generic (ID : natural);
    
    port(
        clk, reset : in  std_logic;     -- asynchronous reset (active high)
        --
        vdata_o    : out vflit_t;
        rxcredit_o : out credit_t;      -- must be always valid
        --
        -- input link iface (FIFO)
        raw_data   : in  data_t;
        raw_dv     : in  std_logic;
        ready      : out std_logic;
        --
        -- RAM-like device iface for control
        --
        i_rld_ctrl : in  i_rld_t;
        o_rld_ctrl : out o_rld_t);
end ilink_adapter;


architecture ilink_adapter of ilink_adapter is
    signal cnt     : lpack_len_t;
    signal lheader : lheader_t;
    signal atHead  : boolean;

    signal ready0 : std_logic;

    -- debug stuff

    signal flowcount_mine, flowcount_recvd, flowcount_mine_x : std_logic_vector(31 downto 0);
    signal flow_error                                        : boolean;

    signal o_rld_dbg : o_rld_t;
    signal dbg_value : data_t;
    
begin
    lheader <= decompose(raw_data);
    atHead  <= cnt = 0;

    process (clk, reset)
    begin
        if reset = '1' then
            cnt        <= 0;
            rxcredit_o <= (others => '0');

        elsif rising_edge(clk) and raw_dv = '1' and ready0 = '1' then
            if atHead then
                cnt        <= lheader.lpack_len;
                rxcredit_o <= lheader.credit;
            else
                cnt <= cnt - 1;
            end if;
        end if;
    end process;

    vdata_o <= (raw_data, raw_dv = '1' and not atHead and ready0 = '1');

    ready0 <= '1';
    ready  <= ready0;

    ---------------------------------------------------------------------------

    dbg : if configure.dbg_buffers generate
        flow_error     <= flowcount_mine_x /= flowcount_recvd;
        flowcount_mine <= (others => '0') when reset = '1'
                          else flowcount_mine + 1 when rising_edge(clk) and cnt = 1 and raw_dv = '1' and ready0 = '1';
        flowcount_recvd <= (others => '0') when reset = '1' else
                           lheader.flowcount when rising_edge(clk) and atHead;
        flowcount_mine_x <= (others => '0') when reset = '1' else flowcount_mine when rising_edge(clk);


        o_rld_dbg <= match(cc_dbg_ilink.offset(offset(f_dbg_ilink), cc_dbg_ilink.f_values, ID), i_rld_ctrl, dbg_value);

        ID_zero : if ID = 0 generate
            o_rld_ctrl <= rld_mux(cc_dbg_ilink.match_consts(offset(f_dbg_ilink), i_rld_ctrl)
                                  & o_rld_dbg);
        end generate;
        -- else generate
        ID_others : if not (ID = 0) generate
            o_rld_ctrl <= o_rld_dbg;
        end generate;

        dbg_value <= flowcount_mine_x & flowcount_recvd;
    end generate;

end ilink_adapter;

