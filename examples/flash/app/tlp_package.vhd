-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

package tlp_package is

    subtype dword is std_logic_vector(31 downto 0);
    subtype qword is std_logic_vector(63 downto 0);
    subtype qqword is std_logic_vector(127 downto 0);
    subtype tlp_header is qqword;

    -- common dword #0 for nearly all TLP packets
    type tlp_dw0 is record
        fmt  : std_logic_vector(2 downto 0);
        typ  : std_logic_vector(4 downto 0);
        -- r1
        tc   : std_logic_vector(2 downto 0);
        -- r2
        td   : std_logic_vector(0 downto 0);
        ep   : std_logic_vector(0 downto 0);
        attr : std_logic_vector(1 downto 0);
        at   : std_logic_vector(1 downto 0);
        len  : std_logic_vector(9 downto 0);
    end record;

    -- dword #1 for read and write request
    type tlp_dw1 is record
        req_id         : std_logic_vector(15 downto 0);
        tag            : std_logic_vector(7 downto 0);
        be_fst, be_lst : std_logic_vector(3 downto 0);
    end record;

    -- dword #1 for read completion
    type tlp_cpldw1 is record
        cpl_id : std_logic_vector(15 downto 0);
        status : std_logic_vector(2 downto 0);
        b      : std_logic_vector(0 downto 0);
        bc     : std_logic_vector(11 downto 0);
    end record;

    -- dword #2 for read completion
    type tlp_cpldw2 is record
        req_id   : std_logic_vector(15 downto 0);
        tag      : std_logic_vector(7 downto 0);
        -- r
        low_addr : std_logic_vector(6 downto 0);
    end record;

    function combine(dw : tlp_dw0) return dword;
    function combine(dw : tlp_dw1) return dword;
    function combine(dw : tlp_cpldw1) return dword;
    function combine(dw : tlp_cpldw2) return dword;

    function parse(raw : dword) return tlp_dw0;
    function parse(raw : dword) return tlp_dw1;
    function parse(raw : dword) return tlp_cpldw1;
    function parse(raw : dword) return tlp_cpldw2;

    ---------------------------------------------------------------------------
    -- TLP address resides in dwordss #2 and #3 (catenated to a single qword)
    ---------------------------------------------------------------------------

    subtype tlp_address is qword;

    function parse(raw    : qword; is_4dw : boolean) return tlp_address;
    function combine(addr : tlp_address; is_4dw : boolean) return qword;

    ---------------------------------------------------------------------------

    subtype tlp_kind is std_logic_vector(7 downto 0);

    constant kind_MRd32 : tlp_kind := "000" & "00000";
    constant kind_MRd64 : tlp_kind := "001" & "00000";
    constant kind_MWr32 : tlp_kind := "010" & "00000";
    constant kind_MWr64 : tlp_kind := "011" & "00000";
    constant kind_CplD  : tlp_kind := "010" & "01010";

    -- create read or write packet with addr32 either addr64
    function mk_rw_packet(kind   : tlp_kind;
                          len    : std_logic_vector(9 downto 0);
                          addr   : tlp_address;
                          --
                          tc     : std_logic_vector(2 downto 0)  := (others => '0');
                          td     : std_logic_vector(0 downto 0)  := "0";
                          ep     : std_logic_vector(0 downto 0)  := "0";
                          attr   : std_logic_vector(1 downto 0)  := (others => '0');
                          at     : std_logic_vector(1 downto 0)  := (others => '0');
                          --
                          req_id : std_logic_vector(15 downto 0) := (others => '0');
                          tag    : std_logic_vector(7 downto 0)  := (others => '0'))
        return tlp_header;

    -- create read completion
    function mk_cpl_packet(header    : tlp_header;
                           my_pci_id : std_logic_vector(15 downto 0) := (others => '0'))
        return tlp_header;

    ---------------------------------------------------------------------------

    type byte_placement is record
        bc    : std_logic_vector(11 downto 0);  -- byte count
        addrb : tlp_address;                    -- byte-precise address
    end record;

    type dword_placement is record
        len            : std_logic_vector(9 downto 0);
        addr           : tlp_address;   -- 2 LSB assumed to be zeroes
        be_fst, be_lst : std_logic_vector(3 downto 0);
    end record;

    function conv(bp  : byte_placement) return dword_placement;
    function conv(dwp : dword_placement) return byte_placement;

    type tlp_info is record
        kind         : tlp_kind;
        is_4dw       : boolean;         -- 3dw or 4dw header
        is_payloaded : boolean;
        is_qwaligned : boolean;         -- applicable only for 3dw header
        is_eofempty  : boolean;         -- whether to fire empty bit at eof
        bc           : std_logic_vector(11 downto 0);
        payload_len  : integer;
    end record;

    -- FIXME: current implementation relys on qword alignment
    function header_info(header : tlp_header) return tlp_info;

    ---------------------------------------------------------------------------
    -- TLP rx/tx interface
    ---------------------------------------------------------------------------

    type tlp_rx is record
        data   : std_logic_vector(127 downto 0);
        dvalid : std_logic;
        --
        sop    : std_logic;
        eop    : std_logic;
    end record;

    type tlp_tx is record
        data   : std_logic_vector(127 downto 0);
        dvalid : std_logic;
    end record;

    type tlp_tx_backpressure is record
        ej_ready : std_logic;
    end record;

    type tlp_rx_array is array (integer range <>) of tlp_rx;
    type tlp_tx_array is array (integer range <>) of tlp_tx;
    type tlp_tx_backpressure_array is array (integer range <>) of tlp_tx_backpressure;

    ---------------------------------------------------------------------------

    component tlp_io_128
        port (
            rx_data   : in  std_logic_vector(127 downto 0);
            rx_dvalid : in  std_logic;
            rx_sop    : in  std_logic;
            rx_eop    : in  std_logic;
            --
            tx_data   : out std_logic_vector(127 downto 0);
            tx_dvalid : out std_logic;
            ej_ready  : in  std_logic;
            --
            clk       : in  std_logic;
            reset     : in  std_logic);
    end component;

end package tlp_package;

package body tlp_package is
    ---------------------------------------------------------------------------
    -- combine/parse for tlp_dw0
    ---------------------------------------------------------------------------

    procedure bidir_conv(dir_combine :       boolean;
                         raw         : inout dword;
                         dw          : inout tlp_dw0)
    is
        type flds is (fmt, typ, r1, tc, r2, td, ep, attr, at, len);
        type idx is array (flds) of integer;

        -- the higher index of field's interval
        constant higher : idx := (
            fmt  => 31,
            typ  => 28,
            r1   => 23,                 -- reserved
            tc   => 22,
            r2   => 19,                 -- reserved
            td   => 15,
            ep   => 14,
            attr => 13,
            at   => 11,
            len  => 9);

        -- the lower index of field's interval
        function lower(i : flds) return integer is
        begin
            if i = flds'high then
                return 0;
            else
                return higher(flds'succ(i)) + 1;
            end if;
        end;

        procedure assign(fld : flds; val : inout std_logic_vector) is
        begin
            case dir_combine is
                when true =>
                    raw(higher(fld) downto lower(fld)) := val;
                when false =>
                    val := raw(higher(fld) downto lower(fld));
            end case;
        end;
    begin
        assign(fmt, dw.fmt);
        assign(typ, dw.typ);
        assign(tc, dw.tc);
        assign(td, dw.td);
        assign(ep, dw.ep);
        assign(attr, dw.attr);
        assign(at, dw.at);
        assign(len, dw.len);
    end;

    function combine(dw : tlp_dw0) return dword is
        variable raw_v : dword   := (others => '0');
        variable dw_v  : tlp_dw0 := dw;

    begin
        bidir_conv(true, raw_v, dw_v);
        return raw_v;
    end;

    function parse(raw : dword) return tlp_dw0 is
        variable raw_v : dword := raw;
        variable dw_v  : tlp_dw0;
    begin
        bidir_conv(false, raw_v, dw_v);
        return dw_v;
    end;

    ---------------------------------------------------------------------------
    -- combine/parse for tlp_dw1
    ---------------------------------------------------------------------------

    procedure bidir_conv(dir_combine :       boolean;
                         raw         : inout dword;
                         dw          : inout tlp_dw1)
    is
        type flds is (req_id, tag, be_fst, be_lst);
        type idx is array (flds) of integer;

        -- the higher index of field's interval
        constant higher : idx := (
            req_id => 31,
            tag    => 15,
            be_fst => 7,
            be_lst => 3);

        -- the lower index of field's interval
        function lower(i : flds) return integer is
        begin
            if i = flds'high then
                return 0;
            else
                return higher(flds'succ(i)) + 1;
            end if;
        end;

        procedure assign(fld : flds; val : inout std_logic_vector) is
        begin
            case dir_combine is
                when true =>
                    raw(higher(fld) downto lower(fld)) := val;
                when false =>
                    val := raw(higher(fld) downto lower(fld));
            end case;
        end;
    begin
        assign(req_id, dw.req_id);
        assign(tag, dw.tag);
        assign(be_fst, dw.be_fst);
        assign(be_lst, dw.be_lst);
    end;

    function combine(dw : tlp_dw1) return dword is
        variable raw_v : dword   := (others => '0');
        variable dw_v  : tlp_dw1 := dw;

    begin
        bidir_conv(true, raw_v, dw_v);
        return raw_v;
    end;

    function parse(raw : dword) return tlp_dw1 is
        variable raw_v : dword := raw;
        variable dw_v  : tlp_dw1;
    begin
        bidir_conv(false, raw_v, dw_v);
        return dw_v;
    end;

    ---------------------------------------------------------------------------
    -- combine/parse for tlp_cpldw1
    ---------------------------------------------------------------------------

    procedure bidir_conv(dir_combine :       boolean;
                         raw         : inout dword;
                         dw          : inout tlp_cpldw1)
    is
        type flds is (cpl_id, status, b, bc);
        type idx is array (flds) of integer;

        -- the higher index of field's interval
        constant higher : idx := (
            cpl_id => 31,
            status => 15,
            b      => 12,
            bc     => 11);

        -- the lower index of field's interval
        function lower(i : flds) return integer is
        begin
            if i = flds'high then
                return 0;
            else
                return higher(flds'succ(i)) + 1;
            end if;
        end;

        procedure assign(fld : flds; val : inout std_logic_vector) is
        begin
            case dir_combine is
                when true =>
                    raw(higher(fld) downto lower(fld)) := val;
                when false =>
                    val := raw(higher(fld) downto lower(fld));
            end case;
        end;
    begin
        assign(cpl_id, dw.cpl_id);
        assign(status, dw.status);
        assign(b, dw.b);
        assign(bc, dw.bc);
    end;

    function combine(dw : tlp_cpldw1) return dword is
        variable raw_v : dword      := (others => '0');
        variable dw_v  : tlp_cpldw1 := dw;

    begin
        bidir_conv(true, raw_v, dw_v);
        return raw_v;
    end;

    function parse(raw : dword) return tlp_cpldw1 is
        variable raw_v : dword := raw;
        variable dw_v  : tlp_cpldw1;
    begin
        bidir_conv(false, raw_v, dw_v);
        return dw_v;
    end;

    ---------------------------------------------------------------------------
    -- combine/parse for tlp_cpldw2
    ---------------------------------------------------------------------------

    procedure bidir_conv(dir_combine :       boolean;
                         raw         : inout dword;
                         dw          : inout tlp_cpldw2)
    is
        type flds is (req_id, tag, r, low_addr);
        type idx is array (flds) of integer;

        -- the higher index of field's interval
        constant higher : idx := (
            req_id   => 31,
            tag      => 15,
            r        => 7,              -- reserved
            low_addr => 6);

        -- the lower index of field's interval
        function lower(i : flds) return integer is
        begin
            if i = flds'high then
                return 0;
            else
                return higher(flds'succ(i)) + 1;
            end if;
        end;

        procedure assign(fld : flds; val : inout std_logic_vector) is
        begin
            case dir_combine is
                when true =>
                    raw(higher(fld) downto lower(fld)) := val;
                when false =>
                    val := raw(higher(fld) downto lower(fld));
            end case;
        end;
    begin
        assign(req_id, dw.req_id);
        assign(tag, dw.tag);
        assign(low_addr, dw.low_addr);
    end;

    function combine(dw : tlp_cpldw2) return dword is
        variable raw_v : dword      := (others => '0');
        variable dw_v  : tlp_cpldw2 := dw;

    begin
        bidir_conv(true, raw_v, dw_v);
        return raw_v;
    end;

    function parse(raw : dword) return tlp_cpldw2 is
        variable raw_v : dword := raw;
        variable dw_v  : tlp_cpldw2;
    begin
        bidir_conv(false, raw_v, dw_v);
        return dw_v;
    end;

    ---------------------------------------------------------------------------
    -- combine/parse for TLP address (resides in dwords #2 and #3)
    ---------------------------------------------------------------------------

    function safe_copy(src : qword) return qword is
        variable dst : qword := src;
    begin
        -- just in case
        dst(63 downto 32) := (others => '0');
        dst(1 downto 0)   := (others => '0');
        return dst;
    end;

    procedure bidir_conv_64(dir_combine :       boolean;
                            addr        : inout tlp_address;
                            raw         : inout qword)
    is
        type flds is (addr_lo, r, addr_hi);
        type idx is array (flds) of integer;

        -- the higher index of field's interval
        constant higher : idx := (
            addr_lo => 63,
            r       => 33,              -- reserved
            addr_hi => 31);

        -- the lower index of field's interval
        function lower(i : flds) return integer is
        begin
            if i = flds'high then
                return 0;
            else
                return higher(flds'succ(i)) + 1;
            end if;
        end;

        procedure assign(fld : flds; val : inout std_logic_vector) is
        begin
            case dir_combine is
                when true =>
                    raw(higher(fld) downto lower(fld)) := val;
                when false =>
                    val := raw(higher(fld) downto lower(fld));
            end case;
        end;
    begin
        assign(addr_lo, addr(31 downto 2));
        assign(addr_hi, addr(63 downto 32));
    end;

    function parse(raw : qword; is_4dw : boolean) return tlp_address is
        variable a  : tlp_address := (others => '0');
        variable qw : qword       := raw;
    begin
        if is_4dw then
            bidir_conv_64(false, a, qw);
        else
            a := safe_copy(raw);
        end if;
        return a;
    end;


    function combine(addr : tlp_address; is_4dw : boolean) return qword is
        variable a  : tlp_address := addr;
        variable qw : qword       := (others => '0');
    begin
        if is_4dw then
            bidir_conv_64(true, a, qw);
        else
            qw := safe_copy(addr);
        end if;
        return qw;
    end;

    ---------------------------------------------------------------------------

    function mk_rw_packet(kind   : tlp_kind;
                          len    : std_logic_vector(9 downto 0);
                          addr   : tlp_address;
                          --
                          tc     : std_logic_vector(2 downto 0)  := (others => '0');
                          td     : std_logic_vector(0 downto 0)  := "0";
                          ep     : std_logic_vector(0 downto 0)  := "0";
                          attr   : std_logic_vector(1 downto 0)  := (others => '0');
                          at     : std_logic_vector(1 downto 0)  := (others => '0');
                          --
                          req_id : std_logic_vector(15 downto 0) := (others => '0');
                          tag    : std_logic_vector(7 downto 0)  := (others => '0'))
        return tlp_header
    is
        -- TODO: use byte count to evaluate both len and be
        constant be_fst : std_logic_vector(3 downto 0) := (others => '1');
        constant be_lst : std_logic_vector(3 downto 0) := (others => '1');

        constant fmt : std_logic_vector(2 downto 0) := kind(7 downto 5);
        constant dw0 : tlp_dw0 := (fmt  => fmt,
                                   typ  => kind(4 downto 0),
                                   tc   => tc,
                                   td   => td,
                                   ep   => ep,
                                   attr => attr,
                                   at   => at,
                                   len  => len);
        constant dw1    : tlp_dw1 := (req_id, tag, be_fst, be_lst);
        constant is_4dw : boolean := fmt(0) = '1';
    begin
        return combine(addr, is_4dw) & combine(dw1) & combine(dw0);
    end;

    function mk_cpl_packet(
        tc       : std_logic_vector(2 downto 0) := (others => '0');
        td       : std_logic_vector(0 downto 0) := "0";
        ep       : std_logic_vector(0 downto 0) := "0";
        attr     : std_logic_vector(1 downto 0) := (others => '0');
        at       : std_logic_vector(1 downto 0) := (others => '0');
        --
        cpl_id   : std_logic_vector(15 downto 0);
        status   : std_logic_vector(2 downto 0) := (others => '0');
        bc       : std_logic_vector(11 downto 0);
        --
        req_id   : std_logic_vector(15 downto 0);
        tag      : std_logic_vector(7 downto 0);
        low_addr : std_logic_vector(6 downto 0))
        return tlp_header
    is
        constant dw0 : tlp_dw0 := (fmt  => kind_CplD(7 downto 5),
                                   typ  => kind_CplD(4 downto 0),
                                   tc   => tc,
                                   td   => td,
                                   ep   => ep,
                                   attr => attr,
                                   at   => at,
                                   len  => bc(11 downto 2));  -- a case of aligned address

        constant dw1 : tlp_cpldw1 := (cpl_id => cpl_id,
                                      status => status,
                                      b      => "0",
                                      bc     => bc);
        constant dw2   : tlp_cpldw2 := (req_id, tag, low_addr);
        constant zeros : dword      := (others => '0');
    begin
        return zeros & combine(dw2) & combine(dw1) & combine(dw0);
    end;

    function mk_cpl_packet(header    : tlp_header;
                           my_pci_id : std_logic_vector(15 downto 0) := (others => '0'))
        return tlp_header
    is
        constant dw0    : tlp_dw0 := parse(header(31 downto 0));
        constant dw1    : tlp_dw1 := parse(header(63 downto 32));
        constant is_4dw : boolean := dw0.fmt(0) = '1';
    begin
        return mk_cpl_packet(
            cpl_id   => my_pci_id,
            bc       => dw0.len & "00",
            req_id   => dw1.req_id,
            tag      => dw1.tag,
            low_addr => parse(header(127 downto 64), is_4dw)(6 downto 0),
            attr     => dw0.attr,
            tc       => dw0.tc);
    end;

    ---------------------------------------------------------------------------

    -- FIXME: current implementations works for aligned data only
    function conv(bp : byte_placement) return dword_placement is
    begin
        return (len    => bp.bc(11 downto 2),
                addr   => bp.addrb,
                be_fst => (others => '1'),
                be_lst => (others => '1'));
    end;

    function conv(dwp : dword_placement) return byte_placement is
    begin
        return (bc    => dwp.len & "00",
                addrb => dwp.addr);
    end;

    ---------------------------------------------------------------------------

    type byte_placement_low is record
        bc       : std_logic_vector(11 downto 0);
        low_addr : std_logic_vector(6 downto 0);
    end record;

    -- FIXME: current implementation relys on qword alignment
    function header_info(header : tlp_header) return tlp_info is
        constant dw0          : tlp_dw0    := parse(header(31 downto 0));
        constant dw1          : tlp_dw1    := parse(header(63 downto 32));
        constant cpldw1       : tlp_cpldw1 := parse(header(63 downto 32));
        constant cpldw2       : tlp_cpldw2 := parse(header(95 downto 64));
        constant kind         : tlp_kind   := dw0.fmt & dw0.typ;
        constant is_4dw       : boolean    := dw0.fmt(0) = '1';
        constant is_payloaded : boolean    := dw0.fmt(1) = '1';


        function mk_bp_low return byte_placement_low is
            -- TODO: may be useful to create cpl packet
            function aux_rw return byte_placement_low is
                constant dwp : dword_placement :=
                    (dw0.len, parse(header(127 downto 64), is_4dw), dw1.be_fst, dw1.be_lst);
                constant bp : byte_placement := conv(dwp);
            begin
                return (bp.bc, bp.addrb(6 downto 0));
            end;
        begin
            case kind is
                when kind_CplD => return (cpldw1.bc, cpldw2.low_addr);
                when others    => return aux_rw;
            end case;
        end;

        constant bp_low : byte_placement_low := mk_bp_low;

        -- FIXME: works for dwaligned only
        constant is_qwaligned : boolean := bp_low.low_addr(2) = '0';

        -- FIXME: works for qwaligned only
        function payload_len return integer is
            constant len1 : std_logic_vector(10 downto 0) := ('0' & dw0.len) + "11";
        begin
            if is_payloaded then
                return conv_integer(len1(10 downto 2));
            else
                return 0;
            end if;
        end;

        -- FIXME: works only for qwaligned only
        constant is_eofempty : boolean := dw0.len(1) = '1' and is_payloaded;
    begin
        return (
            kind         => kind,
            is_4dw       => is_4dw,
            is_payloaded => is_payloaded,
            is_qwaligned => is_qwaligned,
            is_eofempty  => is_eofempty,
            bc           => bp_low.bc,
            payload_len  => payload_len);
    end;
    
end package body tlp_package;
