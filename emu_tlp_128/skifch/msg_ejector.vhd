-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.tlp_flit;
use work.msg_flit.all;
use work.net_flit.all;
use work.vdata.all;
use work.util.all;
use work.t3d_topology.all;
use work.credit.all;
use work.rld.all;
use work.cclasses.all;
use work.up;
use work.configure;


entity msg_ejector is
    generic (
        portId   : portId_range;
        dbg_base : integer);

    port (
        clk, reset    : in  std_logic;  -- asynchronous reset (active high)
        --
        -- data input interface (i.e. RAM iface)
        --
        vdata_i       : in  vflit_t;
        has_bubble    : out boolean;
        ready_i       : out boolean;
        --
        -- data output iface
        --
        vdata_o       : out vflit_t;    -- to be MUXed
        --
        -- update registers
        --
        vdata_dram_rx : in  vflit_t;
        --
        -- arbiter client interface
        --
        req           : out std_logic;
        ack           : in  std_logic;
        --
        -- RLD iface for debug
        --
        i_rld_ctrl    : in  i_rld_t;
        o_rld_ctrl    : out o_rld_t);

end msg_ejector;

architecture msg_ejector of msg_ejector is
    -- rx/tx staff for head queue
    signal rx_head_wcell, tx_head_wcell : up.head_wcptr_t;
    alias tx_head_cell                  : up.head_cptr_t is tx_head_wcell(up.head_cptr_range);
    alias tx_parity                     : std_logic is tx_head_wcell(up.head_wcptr_range'high);

    -- rx/tx staff for body queue
    signal rx_body_wcell, tx_body_wcell : up.body_wcptr_t;
    alias tx_body_cell                  : up.body_cptr_t is tx_body_wcell(up.body_cptr_range);

    ---------------------------------------------------------------------------

    signal arbiter_allows, input_ready, output_ready : boolean;
    signal net_sop, net_eop                          : boolean;  -- start/end of net packet
    signal tlp_sop                                   : boolean;
    signal ready, ready_1                            : boolean;

    signal vdata_1 : vflit_t;

    signal tx_tlp : tlp_flit.tlp_head_t;

    -- measured in cells
    function sufficient_space(head_csize : integer range up.head_ccapacity downto 0;
                              body_csize : integer range up.body_ccapacity downto 0)
        return boolean
    is
    begin
        return up.head_ccapacity - head_csize >= 1
            and up.body_ccapacity - body_csize >= configure.max_pktlen/configure.cell_size;
    end;

    function fix_parity(data : data_t; parity : boolean) return data_t is
        variable msg_head : msg_head_t := decompose(data);
    begin
        msg_head.parity := parity;

        return compose(msg_head);
    end;

    ---------------------------------------------------------------------------
    -- FSM

    type state_t is (Idle, Send_body, Send_tail, Skip, Send_head);

    -- the predicted path in the state graph
    type state_path_t is (BTS, BT, BS, TS, T, S);  -- NB: S is actually impossible

    type fstate_t is record
        state       : state_t;
        path        : state_path_t;
        --
        net_head    : net_head_t;
        --
        -- FIXME: integer types
        -- the number of full cache-lines to be sent
        body_nLines : integer;               -- countdown
        -- the value of counter at the end of tail
        end_ofTail  : integer range 0 to 7;  -- constant
        --
        -- the number flits left is the current cache-line
        count       : integer range 0 to 8;  -- countdown; 8 means TLP header
    end record;

    -- actually a constant
    function idle_fstate return fstate_t is
        variable result : fstate_t;
    begin
        result.state := Idle;
        result.count := 1;              -- 0, 7 and 8 have special meanings
        return result;
    end;
    
    function next_state(fstate         : fstate_t;
                        net_head       : net_head_t;
                        input_ready    : boolean;
                        output_ready   : boolean;
                        arbiter_allows : boolean) return fstate_t
    is
        function mk_newPacket return fstate_t is
            constant l           : integer := net_head.pktlen - 2;
            constant body_nLines : integer := l / 8;
            constant tail        : integer := l mod 8;

            constant end_ofTail : integer := conv_integer("000"-conv_std_logic_vector(tail, 3));

            function f_path return state_path_t is
                constant bits : std_logic_vector(0 to 2) :=
                    (to_stdl(body_nLines /= 0),             -- has B
                     to_stdl(tail /= 0),                    -- has T
                     to_stdl(tail /= 7)                     -- has S
                     );
            begin
                case bits is
                    when "111"  => return BTS;
                    when "101"  => return BS;
                    when "110"  => return BT;
                    when "011"  => return TS;
                    when "010"  => return T;
                    when others => assert false; return S;  -- impossible
                end case;
            end;

            constant path : state_path_t := f_path;

            function mkState return state_t is
            begin
                case path is
                    when BTS | BS | BT => return Send_body;
                    when TS | T        => return Send_tail;
                    when S             => return Skip;  -- impossible
                end case;
            end;
            
        begin
            return (mkState, path, net_head, body_nLines, end_ofTail, 8);
        end;

        variable result : fstate_t := fstate;
        
    begin
        case fstate.state is
            when Idle =>
                if input_ready and output_ready then
                    return mk_newPacket;
                else
                    return fstate;
                end if;

            when Send_body =>
                if not arbiter_allows or not input_ready then
                    return fstate;
                end if;

                if fstate.count = 0 then
                    result.count := 8;

                    if fstate.body_nLines = 1 then
                        case fstate.path is
                            when BTS | BT => result.state := Send_tail;
                            when BS       => result.state := Skip;
                            when others   => assert false;
                        end case;
                    end if;

                    result.body_nLines := fstate.body_nLines - 1;
                else
                    result.count := fstate.count - 1;
                end if;

            when Send_tail =>
                if not arbiter_allows or not input_ready then
                    return fstate;
                end if;

                case fstate.path is
                    when BTS | TS =>
                        if fstate.count = fstate.end_ofTail then
                            result.state := Skip;
                        end if;

                    when BT | T =>
                        if fstate.count = 1 then
                            result.state := Send_head;
                        end if;
                        
                    when others => assert false;
                end case;

                if fstate.count /= 0 then  -- FIXME: if
                    result.count := fstate.count - 1;
                end if;

            when Skip =>
                if not arbiter_allows then
                    return fstate;
                end if;

                if fstate.count = 1 then
                    result.state := Send_head;
                end if;

                result.count := fstate.count - 1;

            when Send_head =>
                if not arbiter_allows or not input_ready then
                    return fstate;
                end if;

                -- FIXME: this may be optimized: in some cases return
-- mk_newPacket (?)
                return idle_fstate;
        end case;

        return result;
    end;

    signal fstate_next, fstate_curr : fstate_t;

    function tx_addr(state        : state_t;
                     tx_head_cell : up.head_cptr_t;
                     tx_body_cell : up.body_cptr_t) return tx_tlpaddr_t
    is
        variable foffset : up.foffset_t := (others => '0');
        variable kind    : tx_kind_t;
    begin

        if state = Send_body then
            kind                                                           := CBody;
            foffset(up.body_cptr_t'high + 3 downto up.body_cptr_t'low + 3) := tx_body_cell;
        else
            kind                                                           := CHead;
            foffset(up.head_cptr_t'high + 3 downto up.head_cptr_t'low + 3) := tx_head_cell;
        end if;

        return (kind, portId, foffset);
    end;

    constant rfifo_capacity : integer := configure.max_pktlen * 3;

    signal rfifo_size : integer range 0 to rfifo_capacity;

    ---------------------------------------------------------------------------
    -- debug stuff

    function conv(state : state_t) return data_t is
    begin
        return conv_std_logic_vector(state_t'pos(state), 64);
    end;

begin
    fstate_next <= next_state(fstate         => fstate_curr,
                              net_head       => decompose(vdata_1.data),
                              input_ready    => input_ready,
                              output_ready   => output_ready,
                              arbiter_allows => arbiter_allows);

    with fstate_curr.state select ready <=
        false                                       when Skip,
        arbiter_allows and (net_sop or not tlp_sop) when others;

    with fstate_curr.state select vdata_o.dv <=
        false                          when Idle,
        arbiter_allows                 when Skip,
        arbiter_allows and input_ready when others;

    input_ready <= vdata_1.dv;
    output_ready <= sufficient_space(conv_integer(tx_head_wcell - rx_head_wcell),
                                     conv_integer(tx_body_wcell - rx_body_wcell));

    rfifo : entity work.rfifo
        generic map (capacity    => rfifo_capacity,
                     data_width  => data_t'length,
                     bubble_size => configure.max_pktlen)

        port map (
            clk          => clk,
            reset        => reset,
            --
            data_i       => vdata_i.data,
            dv_i         => vdata_i.dv,
            ready_i      => ready_i,
            ready_bubble => has_bubble,
            size         => rfifo_size,
            --
            data_o       => vdata_1.data,
            dv_o         => vdata_1.dv,
            ready_o      => ready_1);

    ready_1 <= ready or not input_ready;

    arbiter_client : entity work.msg_arbiter_client
        port map (
            clk   => clk,
            reset => reset,
            --
            sop   => net_sop,
            eop   => net_eop,
            --
            req   => req,
            ack   => ack,
            --
            allow => arbiter_allows);

    process (clk, reset)
    begin
        if reset = '1' then
            tx_head_wcell <= (others => '0');
            tx_body_wcell <= (others => '0');
            rx_head_wcell <= (others => '0');
            rx_body_wcell <= (others => '0');

            fstate_curr <= idle_fstate;
            
        elsif rising_edge(clk) then
            if vdata_dram_rx.dv then
                rx_head_wcell <= vdata_dram_rx.data(up.head_wcptr_range'high + 6 downto up.head_wcptr_range'low + 6);
                rx_body_wcell <= vdata_dram_rx.data(up.body_wcptr_range'high + 6 + 32 downto up.body_wcptr_range'low + 6 + 32);
            end if;

            if fstate_curr.count = 0 and arbiter_allows then
                if fstate_curr.state = Send_body then
                    tx_body_wcell <= tx_body_wcell + 1;
                else
                    tx_head_wcell <= tx_head_wcell + 1;
                end if;
            end if;

            fstate_curr <= fstate_next;
        end if;
    end process;

    vdata_o.data <= tlp_flit.compose(tx_tlp) when tlp_sop
                    else vdata_1.data                              when fstate_curr.state = Send_body or fstate_curr.state = Send_tail
                    else fix_parity(vdata_1.data, tx_parity = '1') when fstate_curr.state = Send_head
                    else (others => '0');
    
    tx_tlp <= (len      => 8,
               read_req => false,
               addr     => compose_addr(tx_addr(fstate_curr.state, tx_head_cell, tx_body_cell)));

    tlp_sop <= fstate_curr.count = 8;

    -- FIXME: a weird way to determine the head of packet
    net_sop <= fstate_curr.count = 8 and (fstate_curr.net_head.pktlen - 2)/8 = fstate_curr.body_nLines
               -- extra condition is needed to avoid TLP packet be broken
               and rfifo_size >= fstate_curr.net_head.pktlen;
    
    net_eop <= fstate_curr.state = Send_head;

    ---------------------------------------------------------------------------
    -- debug stuff
    o_rld_ctrl <= rld_mux(match(dbg_base, i_rld_ctrl, extend64(rx_head_wcell))
                          & match(dbg_base + 1, i_rld_ctrl, extend64(tx_head_wcell))
                          & match(dbg_base + 2, i_rld_ctrl, conv(fstate_next.state))
                          );

end msg_ejector;
