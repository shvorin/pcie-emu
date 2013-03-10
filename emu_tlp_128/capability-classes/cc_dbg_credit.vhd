-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc;
use work.rld.all;
use work.util.all;
use work.flit.all;
use work.cclasses.all;
use work.cc_t3dnode;
use work.t3d_topology.all;
use work.configure;


package cc_dbg_credit is
    constant enabled : boolean := configure.dbg_credit;

    function nItems return integer;

    constant ccid  : data_t := x"3BD63E7362A256D2";
    constant ccver : data_t := extend64(2);

    constant f_id, f_low            : integer := 0;
    constant f_size                 : integer := 1;
    constant f_ver                  : integer := 2;
    constant f_nItems               : integer := 3;
    constant f_credit_fresh         : integer := 4;
    constant f_credit_stale, f_high : integer := 5;

    constant fld_lengths : integer_array(f_low to f_high) :=
        (f_id           => 1,
         f_size         => 1,
         f_ver          => 1,
         f_nItems       => 1,
         f_credit_fresh => nItems,
         f_credit_stale => nItems);

    constant markup : integer_array := mk_markup(fld_lengths);
    constant length : integer       := markup(markup'high);

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer;

    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t;
end cc_dbg_credit;

package body cc_dbg_credit is

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer is
    begin
        return base + markup(fld_num) + local_offset;
    end;


    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t is
        constant ccid_a : data_array := (0 => ccid);
        constant ccsize : data_t     := extend64(8 * length);

    begin
        return match(base, i_rld, ccid_a & ccsize & ccver & extend64(nItems));
    end;

    function nItems return integer is
    begin
        if cc_t3dnode.enabled then
            return 6;
        else
            -- network mode
            return 6 * configure.nNodes;
        end if;
    end;

end cc_dbg_credit;
