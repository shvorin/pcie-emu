-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- This class states that a whole network of t3d routers (not a single node) is
-- used. Also description of topology and parameters of the network is given.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc;
use work.rld.all;
use work.util.all;
use work.flit.all;
use work.cclasses.all;
use work.configure;


package cc_t3dnetwork is
    constant enabled : boolean :=
        not configure.eq(configure.t3d_node, configure.network_selected);

    constant ccid  : data_t := x"A0D5265CEB46CEF0";
    constant ccver : data_t := extend64(4);

    constant f_id, f_low             : integer := 0;
    constant f_size                  : integer := 1;
    constant f_ver                   : integer := 2;
    constant f_size3                 : integer := 3;
    constant f_ppn                   : integer := 4;
    constant f_nodedir2PHY_i         : integer := 5;
    constant f_nodedir2PHY_o, f_high : integer := 6;


    constant fld_lengths : integer_array(f_low to f_high) :=
        (f_id                              => 1,
         f_size                            => 1,
         f_ver                             => 1,
         f_size3                           => 1,
         f_ppn                             => 1,
         f_nodedir2PHY_i | f_nodedir2PHY_o => configure.nNodes * 6);

    constant markup : integer_array := mk_markup(fld_lengths);
    constant length : integer       := markup(markup'high);

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer;

    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t;
end cc_t3dnetwork;


package body cc_t3dnetwork is

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer is
    begin
        return base + markup(fld_num) + local_offset;
    end;

    function place_array(arr : integer_array2(0 to configure.nNodes - 1, 0 to 5)) return data_array is
        variable result : data_array(0 to configure.nNodes * 6 - 1);
        variable i      : integer := 0;
    begin
        for n in arr'range(1) loop
            for p in arr'range(2) loop
                result(i) := extend64(arr(n, p));
                i         := i + 1;
            end loop;
        end loop;

        return result;
    end;

    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t is
        constant ccid_a : data_array := (0 => ccid);
        constant ccsize : data_t     := extend64(8 * length);
        constant a      : data_array := (0 => extend64(configure.ports_perNode));
    begin
        return rld_mux(
            match(base, i_rld, ccid_a & ccsize & ccver)
            & match(offset(base, f_ppn), i_rld,
                    a
                    & place_array(configure.map_nodedir2PHY_o)
                    & place_array(configure.map_nodedir2PHY_i)));
    end;

end cc_t3dnetwork;
