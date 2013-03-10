-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- This package represents Base class in Capability Classes paradigm.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc;
use work.rld.all;
use work.util.all;
use work.flit.all;
use work.cclasses.all;


package cc_base is
    constant ccid  : data_t := x"ED3EF9A9BB066D65";
    constant ccver : data_t := extend64(1);

    constant f_id, f_low   : integer := 0;
    constant f_size        : integer := 1;
    constant f_ver, f_high : integer := 2;

    constant fld_lengths : integer_array(f_low to f_high) :=
        (f_id   => 1,
         f_size => 1,
         f_ver  => 1);

    constant markup : integer_array := mk_markup(fld_lengths);
    constant length : integer       := markup(markup'high);

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer;

    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t;
end cc_base;


package body cc_base is

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer is
    begin
        return base + markup(fld_num) + local_offset;
    end;


    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t is
        constant ccid_a : data_array                  := (0 => ccid);
        constant ccsize : data_t                      := extend64(8 * length);
        constant values : data_array(0 to length - 1) := ccid_a & ccsize & ccver;
        
    begin
        return match(base, i_rld, values);
    end;

end cc_base;
