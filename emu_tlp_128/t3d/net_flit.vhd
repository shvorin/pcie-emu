-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- This is interface of the 'network' layer.

library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.util.all;
use work.configure;


package net_flit is
    -- Width of the 'pktlen' field in net_head_t data format. NB: this defines
    -- POTENTIAL maximum of a packet length (restricted by the number of bit
    -- reserved in the header). Compare with configure.max_pktlen (ACTUAL
    -- maximum).
    constant pktlen_width : positive := 12;

    -- All possible values of packet length. NB: not all values allowed.
    subtype pktlen_range is integer range 0 to 2 ** pktlen_width - 1;

    subtype node_t is std_logic_vector(11 downto 0);       -- 12
    subtype otherdata_t is std_logic_vector(34 downto 0);  -- 35

    -- This defines POTENTIAL number of ports. Compare with
    -- configure.portId_width (ACTUAL number of valid ports).
    constant portId_width : natural := 4;
    subtype portId_range is integer range 0 to 2 ** portId_width - 1;

    subtype valid_portId_range is integer range 0 to configure.valid_nPorts - 1;

    -- Full address of a port.
    type portAddr_t is record
        node   : node_t;
        portId : portId_range;
    end record;

    -- Header flit structure.
    type net_head_t is record
        -- NB: 'pktlen' is the number of all flits of a packet INCLUDING header.
        pktlen    : pktlen_range;
        dst       : portAddr_t;
        spec      : boolean;
        otherdata : otherdata_t;        -- may be used by other layers
    end record;

    constant dummy_net_head : net_head_t := (0, ((others => '0'), 0), false, (others => '0'));

    function decompose(data : data_t) return net_head_t;

    function compose(arg : net_head_t) return data_t;

    function wrap64(node : node_t) return data_t;
    function unwrap64(v  : data_t) return node_t;

    constant max_pkt_nBytes : integer;
end net_flit;


package body net_flit is
    subtype bpktlen_range is integer range 63 downto 52;   -- 12
    subtype dst_node_range is integer range 51 downto 40;  -- 12
    subtype dst_port_range is integer range 39 downto 36;  -- 4
    subtype spec_range is integer range 35 downto 35;      -- 1
    subtype otherdata_range is integer range 34 downto 0;  -- 35

    function decompose(data : data_t) return net_head_t is
    begin
        return (pktlen    => conv_integer(data(bpktlen_range)),
                dst       => (data(dst_node_range), conv_integer(data(dst_port_range))),
                spec      => data(spec_range) = "1",
                otherdata => data(otherdata_range));
    end;

    function compose(arg : net_head_t) return data_t is
        variable result : data_t;
    begin
        result(bpktlen_range)   := conv_std_logic_vector(arg.pktlen, pktlen_width);
        result(dst_node_range)  := arg.dst.node;
        result(dst_port_range)  := conv_std_logic_vector(arg.dst.portId, portId_width);
        result(spec_range)      := singleton(to_stdl(arg.spec));
        result(otherdata_range) := arg.otherdata;

        return result;
    end;

    function wrap64(node : node_t) return data_t is
        variable result : data_t := (others => '0');
    begin
        result(dst_node_range) := node;
        return result;
    end;

    function unwrap64(v : data_t) return node_t is
    begin
        return v(dst_node_range);
    end;

    function f_max_pkt_nBytes return integer is
        constant head_size : integer := configure.cell_size;
        constant body_size : integer :=
            2 ** minimum(configure.down_body_logfcapacity, configure.up_body_logfcapacity);
        -- extra flits added to network packet representation
        constant overhead_size : integer := 2;  -- FIMXE: 1 or 2?

        constant max_nFlits : integer :=
            minimum(configure.max_pktlen, head_size + body_size) - overhead_size;
    begin
        return 8 * max_nFlits;
    end;

    constant max_pkt_nBytes : integer := f_max_pkt_nBytes;

    function sanity_check return boolean is
    begin
        assert
            -- actual value does not exceed potential
            configure.max_pktlen <= pktlen_range'high
            report "Actual value of configure.max_pktlen is greater than possible";

        assert
            configure.valid_nPorts - 1 <= portId_range'high
            report "Actual value of configure.valid_nPorts is greater than possible";

        return true;
    end;

    constant is_sane : boolean := sanity_check;

end net_flit;
