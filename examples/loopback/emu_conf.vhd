-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
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

    subtype skifch_range is integer range 0 to SKIFCH_QTY-1;

    signal int_vdata : vdata256_array(skifch_range);
    signal int_ready : std_logic_vector(skifch_range);
begin
    p_ast : entity work.pautina_ast
        port map (
            clk   => clk,
            reset => reset,

            tx_vdata => int_vdata,
            tx_ready => int_ready,

            rx_vdata => int_vdata,
            rx_ready => int_ready,

            ast_rx       => ast_rx,
            ast_tx       => ast_tx,
            ast_tx_bp    => ast_tx_bp,
            rx_st_bardec => rx_st_bardec,

            i_avmm      => open,
            o_avmm_data => nothing);
end architecture;


use work.ast256.all;

configuration emu_conf of emu_top256 is
    for emu_top256
        for app : ast_ext_io
            use entity work.pautina_ast_loopback
                port map (
                    clk          => clk,
                    reset        => reset,
                    --
                    ast_rx       => rx,
                    ast_tx       => tx,
                    ast_tx_bp    => tx_bp,
                    rx_st_bardec => rx_st_bardec);
        end for;
    end for;
end;

