-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- This is interface of the 'tlp_io' layer.

library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.util.all;


package tlp_flit is
    -- all possible values of packet size; FIXME: should depend on
    -- configure.maxPacketSize
    subtype len_range is integer range 0 to 2 ** 9 - 1;

    subtype tlpaddr_t is std_logic_vector(31 downto 0);

    -- Header flit structure. TODO: there will be more generic packet kind.
    type tlp_head_t is record
        addr     : tlpaddr_t;
        len      : len_range;
        read_req : boolean;
    end record;

    function compose(arg : tlp_head_t) return data_t;

    function decompose(data : data_t) return tlp_head_t;

end tlp_flit;


package body tlp_flit is
    -- Header flit bits layout.
    subtype tlpaddr_range is integer range 63 downto 32;  -- 32
    subtype unused_range is integer range 31 downto 10;   -- 22
    subtype readreq_range is integer range 9 downto 9;    -- 1
    subtype blen_range is integer range 8 downto 0;       -- 9

    function compose(arg : tlp_head_t) return data_t is
        variable result : data_t;
    begin
        result(tlpaddr_range) := arg.addr;
        result(readreq_range) := (others => to_stdl(arg.read_req));
        result(blen_range)    := conv_std_logic_vector(arg.len, blen_range'high - blen_range'low + 1);
        result(unused_range)  := (others => '0');

        return result;
    end;

    function decompose(data : data_t) return tlp_head_t is
    begin
        return (addr     => data(tlpaddr_range),
                len      => conv_integer(data(blen_range)),
                read_req => data(readreq_range) = "1");
    end;

end tlp_flit;
