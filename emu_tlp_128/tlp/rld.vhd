-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.vdata.all;
use work.tlp_flit;


-- RLD stands for RAM-like device
package rld is
    subtype addr_t is tlp_flit.tlpaddr_t;

    type i_rld_t is record
        rd_addr : addr_t;
        --
        wr_addr : addr_t;
        wr_data : data_t;
        we      : std_logic;
    end record;

    subtype o_rld_t is vflit_t;

    type i_rld_array is array (integer range <>) of i_rld_t;
    type o_rld_array is array (integer range <>) of o_rld_t;

    constant nothing : o_rld_t := ((others => 'Z'), false);
    
    function rld_mux(a: o_rld_array) return o_rld_t;

    ---------------------------------------------------------------------------

    type seg_info_t is record
        seg_start, seg_end : addr_t;
    end record;

    type seg_info_array is array (integer range <>) of seg_info_t;
    
end rld;


package body rld is

    function rld_mux(a: o_rld_array) return o_rld_t is
        variable result: o_rld_t := nothing;
    begin
        for i in a'range loop
            if a(i).dv then
                result := a(i);
            end if;
        end loop;

        return result;
    end;
    
end rld;
