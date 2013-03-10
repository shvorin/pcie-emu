-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- Message passing implementation of the 'tlp_io' layer interface.

library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.tlp_flit.all;
use work.net_flit.all;
use work.util.all;
use work.down;
use work.up;
use work.configure;


package msg_flit is

    constant nBytes_width : natural := pktlen_width + 3;
    subtype nBytes_range is integer range 0 to 2 ** nBytes_width - 1;

    -- Header flit structure.
    type msg_head_t is record
        dst    : portAddr_t;
        parity : boolean;
        nBytes : nBytes_range;
        user   : std_logic_vector(31 downto 0);
    end record;

    -- FIXME: beginning of the segment is a magic constant
    constant down_segment_start : tlpaddr_t := (others => '0');  -- x"80000000";

    ---------------------------------------------------------------------------
    -- Conversions: 'msg_head' --compose--> 'data_t' --decompose--> 'msg_head'.
    ---------------------------------------------------------------------------

    function compose(arg    : msg_head_t) return data_t;
    function decompose(data : data_t) return msg_head_t;

    ---------------------------------------------------------------------------
    -- Conversion: 'msg_head' -> 'net_head'.
    ---------------------------------------------------------------------------

    -- reflects data distribution among the two (head and body) queues
    type msg_repr_t is record
        -- the number of data flits carried by the head queue
        head_nFlits : integer range 0 to 2 ** configure.cell_logsize - 1;
        --
        -- the number of cells used in the body queue
        body_nCells : integer range 0 to 2 ** (pktlen_width - configure.cell_logsize) - 1;
    end record;

    function msg_repr(nBytes : nBytes_range) return msg_repr_t;

    function conv(arg : msg_head_t) return net_head_t;

    -- Enhances fifo pointer to the nearest 64B (i.e. 8flit) bound.
    function enhance_8F_aligned(ptr : std_logic_vector) return std_logic_vector;

    ---------------------------------------------------------------------------
    -- 'rx_addr_t' is structural representation of incoming tlpaddr_t
    --

    type rx_kind_t is (CBody, CHead, Rx, Control, Unknown);

    type rx_tlpaddr_t is record
        kind    : rx_kind_t;
        --
        portId  : portId_range;
        --
        -- "flit offset"
        foffset : down.foffset_t;
    end record;

    ---------------------------------------------------------------------------
    -- 'tx_addr_t' is structural representation of outgoing tlpaddr_t

    type tx_kind_t is (CBody, CHead, Rx, Control);

    type tx_tlpaddr_t is record
        kind : tx_kind_t;

        -- NB: in case of 'Send_data' or 'Send_dram_tx' it means destination
        -- portId; in case of 'Send_fpga_rx' it means source portId.
        portId : portId_range;

        -- is significant in case of 'Send_data'
        foffset : up.foffset_t;
    end record;

    ---------------------------------------------------------------------------

    -- conversions: 'tx_addr' --compose--> 'tlpaddr' --decomose--> 'rx_addr'
    function compose_addr(arg    : tx_tlpaddr_t) return tlpaddr_t;
    function decompose_addr(addr : tlpaddr_t) return rx_tlpaddr_t;

end msg_flit;


package body msg_flit is

    subtype dst_node_range is integer range 63 downto 52;  -- 12
    subtype dst_port_range is integer range 51 downto 48;  -- 4
    subtype parity_range is integer range 47 downto 47;    -- 1
    subtype b_nBytes_range is integer range 46 downto 32;  -- 15
    subtype user_range is integer range 31 downto 0;

    function compose(arg : msg_head_t) return data_t is
        variable result : data_t;
    begin
        result(user_range)     := arg.user;
        result(dst_node_range) := arg.dst.node;
        result(dst_port_range) := conv_std_logic_vector(arg.dst.portId, portId_width);
        result(parity_range)   := singleton(to_stdl(arg.parity));
        result(b_nBytes_range) := conv_std_logic_vector(arg.nBytes, nBytes_width);

        return result;
    end;



    function decompose(data : data_t) return msg_head_t is
    begin
        return (dst    => (node => data(dst_node_range), portId => conv_integer(data(dst_port_range))),
                parity => data(parity_range) = "1",
                nBytes => conv_integer(data(b_nBytes_range)),
                user   => data(user_range));
    end;

    ---------------------------------------------------------------------------

    -- Enhances fifo pointer to the nearest 64B (i.e. 8flit) bound.
    -- NB: does not depend on pointer size.
    function enhance_8F_aligned(ptr : std_logic_vector) return std_logic_vector is
    begin
        return (ptr(ptr'high downto ptr'low + 3) + 1) & "000";
    end;

    ---------------------------------------------------------------------------

    function msg_repr(nBytes : nBytes_range) return msg_repr_t is
        constant x : integer range 0 to 63 := nBytes mod 64;
        constant y : integer               := nBytes / 64;
    begin
        case x is
            when 57 to 60 =>
                return (7, y);

            when 61 to 63 =>
                return (0, y + 1);

            when others =>
                return ((x + 7) / 8, y);
        end case;
    end;

    -- the following types define bit placement of net_flit.otherdata
    subtype od_user_range is integer range 34 downto 3;      -- 32
    subtype od_nBytesLow_range is integer range 2 downto 0;  -- 3

    subtype nb_range is integer range nBytes_width - 1 downto 0;
    subtype nbLow_range is integer range 2 downto 0;

    -- NB: parity bit is lost by this conversion
    function conv(arg : msg_head_t) return net_head_t is
        constant repr : msg_repr_t := msg_repr(arg.nBytes);
    begin
        return (dst       => arg.dst,
                pktlen    => repr.head_nFlits + repr.body_nCells * 8 + 2,
                spec      => false,
                otherdata => (others => 'X'));
    end;

    ---------------------------------------------------------------------------

    function compose_addr(arg : tx_tlpaddr_t) return tlpaddr_t is
        subtype unused_align_range is integer range 2 downto 0;   -- 3
        subtype foffset_range is integer range 21 downto 3;       -- 19
        subtype isdata_range is integer range 22 downto 22;       -- 1
        subtype portId_range is integer range 26 downto 23;       -- 4
        subtype ctrl_range is integer range 27 downto 27;         -- 1
        subtype unused_high_range is integer range 31 downto 28;  -- the reset

        -- FIXME: beginning of the segment is a magic constant
        constant segment_start : tlpaddr_t := x"40000000";
        variable result        : tlpaddr_t := (others => '0');

        constant portId_vec : std_logic_vector(portId_width-1 downto 0) := conv_std_logic_vector(arg.portId, portId_width);

    begin
        result(portId_range) := portId_vec;

        case arg.kind is
            when Control =>
                result(ctrl_range)   := "1";
                result(portId_range) := (others => '0');  -- rewrite
                
            when Rx =>
                result(foffset_range'high) := '1';

            when CHead =>
                result(foffset_range)      := arg.foffset;
                result(foffset_range'high) := '0';  -- rewrite the highest bit

            when CBody =>
                result(foffset_range) := arg.foffset;
                result(isdata_range)  := "1";
        end case;

        return segment_start + result;
    end;

    ---------------------------------------------------------------------------

    function decompose_addr(addr : tlpaddr_t) return rx_tlpaddr_t is
        subtype foffset_range is integer range 13 downto 3;       -- 11
        subtype isdata_range is integer range 14 downto 14;       -- 1
        subtype portId_range is integer range 18 downto 15;       -- 4
        subtype ctrl_range is integer range 19 downto 19;         -- 1
        subtype unused_high_range is integer range 31 downto 20;  -- the reset

        constant addr0 : tlpaddr_t := addr - down_segment_start;

        function kind return rx_kind_t is
        begin
            if or_reduce(addr0(unused_high_range)) then
                return Unknown;
            end if;

            if addr0(ctrl_range) = "1" then
                return Control;
            end if;

            if addr0(isdata_range) = "1" then
                return CBody;
            end if;

            if addr0(foffset_range'high) = '0' then
                return CHead;
            else
                if or_reduce(addr0(foffset_range'high - 1 downto foffset_range'low)) then
                    return Unknown;
                end if;

                return Rx;
            end if;
        end;

    begin
        return (kind, conv_integer(addr0(portId_range)), addr0(foffset_range));
    end;

end msg_flit;
