-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

use work.pautina_package.all;

configuration emu_top_cfg of emu_top256 is
    for emu_top256
        for app : ast_ext_io
            use entity work.pautina_wrap_emu;
        end for;
    end for;
end;