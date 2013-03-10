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
use work.svnversion;
use work.configure;


package cc_issue is
    constant ccid  : data_t     := x"81266946FF4BE5B3";
    constant ccver : data_t     := extend64(1);
    constant url   : data_array := conv(svnversion.url, C);
    constant rev   : data_array := conv(svnversion.rev, C);

    function mk_comment return string;

    constant comment : data_array := conv(mk_comment, C);

    constant f_id, f_low       : integer := 0;
    constant f_size            : integer := 1;
    constant f_ver             : integer := 2;
    constant f_url             : integer := 3;
    constant f_rev             : integer := 4;
    constant f_comment, f_high : integer := 5;

    constant fld_lengths : integer_array(f_low to f_high) :=
        (f_id      => 1,
         f_size    => 1,
         f_ver     => 1,
         f_url     => url'length,
         f_rev     => rev'length,
         f_comment => comment'length);

    constant markup : integer_array := mk_markup(fld_lengths);
    constant length : integer       := markup(markup'high);

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer;

    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t;
end cc_issue;


package body cc_issue is

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer is
    begin
        return base + markup(fld_num) + local_offset;
    end;


    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t is
        constant ccid_a : data_array := (0 => ccid);
        constant ccsize : data_t     := extend64(8 * length);

        constant values : data_array(0 to length - 1) :=
            ccid_a & ccsize & ccver & url & rev & comment;
        
    begin
        return match(base, i_rld, values);
    end;

    function mk_comment return string is
    begin
        case configure.network_selected is
            when configure.shortcut =>
                return "*** MODE: shortcut ***";
            when configure.passthru =>
                return "*** MODE: pass-thru node ***";
            when configure.t3d_network =>
                return "*** MODE: t3d network ***";
            when configure.t3d_node =>
                return "*** MODE: t3d node (no network!) ***";
        end case;
        
    end;

end cc_issue;
