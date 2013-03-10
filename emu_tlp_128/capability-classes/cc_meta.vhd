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
use work.cc_base;
use work.cc_issue;
use work.cc_control;
use work.cc_channels;
use work.cc_skifch2;
use work.cc_portdesc;
use work.cc_t3dnetwork;
use work.cc_t3dnode;
use work.cc_dbg_t3dnode;
use work.cc_dbg_ilink;
use work.cc_dbg_ivc;
use work.cc_dbg_credit;
use work.configure;


package cc_meta is
    function optional(a : integer; ena : boolean) return integer;

    constant f_base, f_low         : integer := 0;
    constant f_channels            : integer := 1;
    constant f_control             : integer := 2;
    constant f_issue               : integer := 3;
    constant f_portdesc            : integer := 4;
    constant f_skifch2             : integer := 5;
    constant f_dbg_ilink           : integer := 6;
    constant f_dbg_ivc             : integer := 7;
    constant f_t3dnetwork          : integer := 8;
    constant f_t3dnode             : integer := 9;
    constant f_dbg_credit          : integer := 10;
    constant f_dbg_t3dnode, f_high : integer := 11;

    constant fld_lengths : integer_array(f_low to f_high) :=
        (f_base        => cc_base.length,
         f_channels    => cc_channels.length,
         f_control     => cc_control.length,
         f_issue       => cc_issue.length,
         f_portdesc    => cc_portdesc.length,
         f_skifch2     => cc_skifch2.length,
         f_dbg_ilink   => optional(cc_dbg_ilink.length, configure.dbg_buffers),
         f_dbg_ivc     => optional(cc_dbg_ivc.length, configure.dbg_buffers),
         f_t3dnetwork  => optional(cc_t3dnetwork.length, cc_t3dnetwork.enabled),
         f_t3dnode     => optional(cc_t3dnode.length, cc_t3dnode.enabled),
         f_dbg_credit  => optional(cc_dbg_credit.length, cc_dbg_credit.enabled),
         f_dbg_t3dnode => optional(cc_dbg_t3dnode.length, cc_dbg_t3dnode.enabled));

    constant markup : integer_array := mk_markup(fld_lengths);
    constant length : integer       := markup(markup'high);

    function offset(fld_num : integer) return integer;
    
end cc_meta;


package body cc_meta is
    function optional(a : integer; ena : boolean) return integer is
    begin
        if ena then
            return a;
        else
            return 0;
        end if;
    end;

    function offset(fld_num : integer) return integer is
    begin
        return markup(fld_num);
    end;

end cc_meta;
