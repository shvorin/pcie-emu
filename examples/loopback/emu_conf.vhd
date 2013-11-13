-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

use work.tlp_package.all;
use work.ast256.all;

configuration emu_conf of emu_top256 is
    for emu_top256
        for app : ast_ext_io
            use entity work.pautina_ast(pautina_ast_impl)
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

