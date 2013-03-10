-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- This class describes all SkifCh2 ports.

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


package cc_portdesc is
    constant ccid  : data_t := x"B6BFA6BEF5E45912";
    constant ccver : data_t := extend64(1);

    -- NB: all values measured in bytes!
    constant down_hard : data_array := (
        extend64(configure.down_seg_logfsize + 3),
        extend64(configure.down_head_logfcapacity + 3),
        extend64(configure.down_body_logfcapacity + 3));

    constant up_hard : data_array := (
        extend64(configure.up_seg_logfsize + 3),
        extend64(configure.up_head_logfcapacity + 3),
        extend64(configure.up_body_logfcapacity + 3));

    constant f_id, f_low : integer := 0;
    constant f_size      : integer := 1;
    constant f_ver       : integer := 2;

    constant f_down_hard       : integer := 3;
    constant f_down_soft       : integer := 4;
    constant f_up_hard         : integer := 5;
    constant f_up_soft, f_high : integer := 6;

    constant fld_lengths : integer_array(f_low to f_high) :=
        (f_id                      => 1,
         f_size                    => 1,
         f_ver                     => 1,
         f_down_hard | f_down_soft => down_hard'length,
         f_up_hard | f_up_soft     => up_hard'length);

    constant markup : integer_array := mk_markup(fld_lengths);
    constant length : integer       := markup(markup'high);

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer;

    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t;
end cc_portdesc;


package body cc_portdesc is

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer is
    begin
        return base + markup(fld_num) + local_offset;
    end;


    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t is
        constant ccid_a : data_array := (0 => ccid);
        constant ccsize : data_t     := extend64(8 * length);

        constant down_soft : data_array(down_hard'range) := (others => placeholder0);
        constant up_soft   : data_array(up_hard'range)   := (others => placeholder0);

        constant values : data_array(0 to length - 1) :=
            ccid_a & ccsize & ccver
            & down_hard
            & down_soft
            & up_hard
            & up_soft;
    begin
        return match(base, i_rld, values);
    end;

end cc_portdesc;
