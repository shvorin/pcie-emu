-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;

use work.flit.all;
use work.vdata.all;


entity mux_comb is
    generic (N : positive);

    port (
        sel          : in  integer range 0 to N-1;
        vdata_inputs : in  vdata_vector(0 to N-1);
        vdata_output : out vdata_t);

end entity mux_comb;

architecture mux of mux_comb is
    subtype sel_range is integer range 0 to N-1;

    function selection(sel : sel_range; inputs : vdata_vector(sel_range)) return vdata_t is
    begin
        for i in sel_range loop
            if i = sel then
                return inputs(i);
            end if;
        end loop;

        -- impossible case
        return invalid_vdata;
    end;

    constant IMPLEMENTATION_FUNC : boolean := true;
begin
    ---------------------------------------------------------------------------
    -- implementation 1: using tristate values
    ---------------------------------------------------------------------------
    impl1 : if not IMPLEMENTATION_FUNC generate
        all_n : for n in sel_range generate
            vdata_output <= vdata_inputs(n) when sel = n else (decompose((others => 'Z')), 'Z');
        end generate;
    end generate;

    ---------------------------------------------------------------------------
    -- implementation 2: using function
    ---------------------------------------------------------------------------
    impl2 : if IMPLEMENTATION_FUNC generate
        vdata_output <= selection(sel, vdata_inputs);
    end generate;

end architecture mux;
