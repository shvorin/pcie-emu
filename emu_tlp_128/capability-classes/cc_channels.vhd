-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- An abstract class declaring just the number of ports. Other port parameters
-- are to be declared in more specific classes.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc;
use work.rld.all;
use work.flit.all;
use work.util.all;
use work.cclasses.all;
use work.net_flit;
use work.configure;


package cc_channels is
    constant ccid  : data_t := x"EF752FB8B40FC1E8";
    constant ccver : data_t := extend64(1);

    constant f_id, f_low              : integer := 0;
    constant f_size                   : integer := 1;
    constant f_ver                    : integer := 2;
    -- defines the number of _addressable_ ports; so the maximum number of
-- ports is 2**f_lognPorts
    constant f_lognPorts              : integer := 3;
    -- the actual number of ports
    constant f_nPorts_enabled, f_high : integer := 4;

    constant fld_lengths : integer_array(f_low to f_high) :=
        (f_id             => 1,
         f_size           => 1,
         f_ver            => 1,
         f_lognPorts      => 1,
         f_nPorts_enabled => 1);

    constant markup : integer_array := mk_markup(fld_lengths);
    constant length : integer       := markup(markup'high);

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer;

    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t;
end cc_channels;


package body cc_channels is

    function offset(base : integer; fld_num : integer; local_offset : integer := 0) return integer is
    begin
        return base + markup(fld_num) + local_offset;
    end;


    function match_consts(base : integer; i_rld : i_rld_t) return o_rld_t is
        constant ccid_a : data_array := (0 => ccid);
        constant ccsize : data_t     := extend64(8 * length);

        constant values : data_array(0 to length - 1) :=
            ccid_a & ccsize & ccver
            & extend64(net_flit.portId_width)
            & extend64(configure.valid_nPorts);
    begin
        return match(base, i_rld, values);
    end;

end cc_channels;
