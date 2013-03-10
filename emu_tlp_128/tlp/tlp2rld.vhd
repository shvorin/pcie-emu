-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.vdata.all;
use work.util.all;
use work.tlp_flit;
use work.tlp_package.all;
use work.rld.all;
use work.config;


-- used to convert TLP stream into RAM requests
entity tlp2rld is
    generic (
        BAR_NUM    : integer range 0 to 7;
        READ_DELAY : integer range 0 to 2 := 0);

    port (
        clk, reset : in  std_logic;
        --
        -- TLP_IO frontend
        i_tlp      : in  i_tlp_t;
        o_tlp      : out o_tlp_t;
        --
        -- RAM-like device backend
        i_rld      : out i_rld_t;
        o_rld      : in  o_rld_t);
end entity tlp2rld;


architecture tlp2rld of tlp2rld is
    constant mask : addr_t := shl(conv_std_logic_vector(1, addr_t'length),
                                  conv_std_logic_vector(config.bar_size_mask(BAR_NUM), addr_t'length)) - 1;

    -- read request info
    type req_info_t is record
        addr : tlp_flit.tlpaddr_t;
        spec : data_t;                  -- used only for read request
    end record;

    -- binary representation of req_info_t
    subtype req_info_b is std_logic_vector(data_t'length + tlp_flit.tlpaddr_t'length - 1 downto 0);

    function compose(arg : req_info_t) return req_info_b is
    begin
        return arg.addr & arg.spec;
    end;

    function decompose(data : req_info_b) return req_info_t is
    begin
        return (data(95 downto 64), data(63 downto 0));
    end;

    -- see https://sites.google.com/site/keldyshpat/tlp_io
    function nFlits(arg : req_info_t) return tlp_flit.len_range is
    begin
        -- +1 is for spec flit
        return conv_integer(arg.spec(9 downto 1)) + 1;
    end;

    signal tlp_head : tlp_flit.tlp_head_t;

    signal req_o, req_i : req_info_t;

    signal fifo_data_i, fifo_data_o                         : req_info_b;
    signal fifo_ready_i, fifo_dv_i, fifo_dv_o, fifo_ready_o : boolean;

    constant c_head  : integer := -2;
    constant c_spec  : integer := -1;
    --
    constant c_check : integer := -3;
    constant c_req   : integer := c_check - READ_DELAY;

    signal count          : integer range -5 to tlp_flit.len_range'high;
    signal brk            : boolean;
    signal rx_dv, ready_o : boolean;

    signal vdata : vflit_t;

    type state_t is (Idle, ReadReq, WriteReq, Ignored);

    type fstate_t is record
        state : state_t;
        count : tlp_flit.len_range;
        --
        head  : tlp_flit.tlp_head_t;
        spec  : data_t;
    end record;

    function mkFstate_idle return fstate_t is
        variable result : fstate_t;
    begin
        result.state := Idle;
        -- all fields except state are meaningless
        return result;
    end;

    function next_state(fstate  : fstate_t;
                        rx_data : data_t;
                        ena     : boolean) return fstate_t is
        function mkFstate_newPacket return fstate_t is
            constant head : tlp_flit.tlp_head_t := tlp_flit.decompose(rx_data);

            function mkState return state_t is
            begin
                if rx_data(tlp_bar_range) /= BAR_NUM then
                    return Ignored;
                elsif head.read_req then
                    return ReadReq;
                else
                    return WriteReq;
                end if;
            end;
        begin
            return (state => mkState,
                    count => 0,
                    head  => head,
                    spec  => (others => 'X'));
        end;

        function mkFstate_step return fstate_t is
        begin
            if fstate.count = 1 then
                return (fstate.state, fstate.count + 1, fstate.head, rx_data);
            else
                return (fstate.state, fstate.count + 1, fstate.head, fstate.spec);
            end if;
        end;

    begin
        case fstate.state is
            when Idle =>
                if ena then
                    return mkFstate_newPacket;
                else
                    return mkFstate_idle;
                end if;
                
            when ReadReq | WriteReq | Ignored =>
                if fstate.count = fstate.head.len then
                    if ena then
                        return mkFstate_newPacket;
                    else
                        return mkFstate_idle;
                    end if;
                    
                else
                    if ena then
                        return mkFstate_step;
                    else
                        return fstate;
                    end if;
                end if;
        end case;
    end;

    signal fstate, fstate_ff : fstate_t;
    
begin

    fstate    <= next_state(fstate_ff, i_tlp.rx_data, rx_dv);
    fstate_ff <= mkFstate_idle when reset = '1' else fstate when rising_edge(clk);

    rx_dv   <= i_tlp.rx_dvalid = '1';
    ready_o <= i_tlp.ej_ready = '1';

    read_req_fifo : entity work.rfifo
        generic map (capacity   => 5,
                     data_width => req_info_b'length)

        port map (
            clk          => clk,
            reset        => reset,
            --
            data_i       => fifo_data_i,
            dv_i         => fifo_dv_i,
            ready_i      => fifo_ready_i,
            ready_bubble => open,
            --
            data_o       => fifo_data_o,
            dv_o         => fifo_dv_o,
            ready_o      => fifo_ready_o);

    -- 1. FIFO input
    -- NB: just drop incomping request when fifo is full
    fifo_dv_i   <= fstate.state = ReadReq and fstate.count = 1 and rx_dv and fifo_ready_i;
    fifo_data_i <= compose(req_i);
    req_i       <= (fstate.head.addr, i_tlp.rx_data);

    -- 2. FIFO output
    tlp_head <= (req_o.addr, nFlits(req_o), true);
    req_o    <= decompose(fifo_data_o);


    -----------------------------------------------------------------------

    process (clk, reset)
    begin
        if reset = '1' then
            count <= c_req;
        elsif rising_edge(clk) and fifo_dv_o then
            if brk then
                count <= c_req;
            elsif count < c_head or ready_o then
                count <= count + 1;
            end if;
        end if;
    end process;

    -- "eop" or "device does not want to reply"
    brk <= (count = tlp_head.len - 2 and ready_o) or (count = c_check and not o_rld.dv);

    fifo_ready_o <= brk or not fifo_dv_o;

    i_rld.rd_addr <= (req_o.addr + (count + READ_DELAY) * 8) and mask when count >= -READ_DELAY
                     else req_o.addr and mask;

    i_rld.wr_addr <= (fstate.head.addr + (fstate.count - 1) * 8) and mask;
    i_rld.we      <= to_stdl(rx_dv and fstate.state = WriteReq and fstate.count /= 0);
    i_rld.wr_data <= i_tlp.rx_data;

    o_tlp.tx_dvalid <= to_stdl(fifo_dv_o and count >= c_head);
    with count select o_tlp.tx_data <=
        tlp_flit.compose(tlp_head) when c_head,  -- header flit
        req_o.spec                 when c_spec,  -- spec flit
        o_rld.data                 when others;  -- data flits
    
end architecture tlp2rld;
