-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use work.types.all;
use work.ast256.all;
use work.avmm.all;
use work.pautina_package.all;

entity pautina_ast_loopback is
    port (
        clk   : in std_logic;
        reset : in std_logic;

        -- Avalon-ST
        ast_rx       : in  ast_t;
        ast_tx       : out ast_t;
        ast_tx_bp    : in  ast_bp_t;
        rx_st_bardec : in  std_logic_vector(7 downto 0));
end entity;

architecture pautina_ast_loopback of pautina_ast_loopback is
    use work.vdata.all;

    subtype link_range is integer range 0 to -1;

    signal rx_vdata, tx_vdata : vdata256_array(link_range);
    signal rx_ready, tx_ready : std_logic_vector(link_range);

begin
    p_ast : pautina_ast
        generic map (
            nPorts => skifch_num,
            nLinks => 0)
        port map (
            clk   => clk,
            reset => reset,

            tx_vdata => tx_vdata,
            tx_ready => tx_ready,

            rx_vdata => rx_vdata,
            rx_ready => rx_ready,

            ast_rx       => ast_rx,
            ast_tx       => ast_tx,
            ast_tx_bp    => ast_tx_bp,
            rx_st_bardec => rx_st_bardec,

            i_avmm      => open,
            o_avmm_data => nothing);
end architecture;

-- TODO: move comm upper
configuration foo of pautina_ast is
    for pautina_ast
        for comm0 : comm
            use entity work.comm(comm_loopback);
        end for;
    end for;
end;

use work.ast256.all;
use work.pautina_package.all;

configuration emu_conf of emu_top256 is
    for emu_top256
        for app : ast_ext_io
            use entity work.pautina_ast_loopback;
            for pautina_ast_loopback
                for p_ast : pautina_ast
                    use configuration work.foo;
                    --use entity work.pautina_ast(pautina_ast);
                    --for pautina_ast
                    --    for comm0 : comm
                    --        use entity work.comm(comm_loopback);
                    --    end for;
                    --end for;
                end for;
            end for;
        end for;
    end for;
end;

