-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.net_flit.all;
use work.msg_flit.all;
use work.vdata.all;
use work.configure;


entity msg_flit_counter_dual is
    port (
        clk, reset       : in  std_logic;  -- asynchronous reset (active high)
        --
        vdata_head       : in  vflit_t;
        vdata_body       : in  vflit_t;
        vdata_o          : out vflit_t;
        --
        re_head, re_body : out boolean;
        --
        ready            : in  boolean;
        --
        -- the following result values make sense only when vdata_o.dv
        sop              : out boolean;    -- start of packet
        rx_next_cell     : out boolean;
        head             : out net_head_t;
        isIdle           : out boolean);
end msg_flit_counter_dual;


architecture msg_flit_counter_dual of msg_flit_counter_dual is
    type state_t is (Idle, Head_B0, Head_0T, Head_BT, Body_B0, Body_BT, Tail, ExtraTail);

    subtype pktclen_range is integer range 0 to 2 ** configure.cell_logsize - 1;

    type fstate_t is record
        state    : state_t;
        body_cnt : pktlen_range;
        tail_cnt : pktclen_range;
        msg_head : msg_head_t;
    end record;

    constant idle_fstate : fstate_t := (Idle, 0, 0, decompose((others => '0')));

    function desired_head_not_body(fstate : fstate_t) return boolean is
    begin
        case fstate.state is
            when Idle | Head_0T | Tail | ExtraTail =>
                return true;
                
            when Head_B0 | Head_BT =>
                return false;
                
            when Body_BT | Body_B0 =>
                return fstate.body_cnt = 1;
        end case;
    end;

    function next_state(fstate   : fstate_t;
                        dv       : boolean;
                        msg_head : msg_head_t) return fstate_t
    is
        function mkFstate_newPacket return fstate_t is
            constant repr : msg_repr_t := msg_repr(msg_head.nBytes);

            constant body_cnt : pktlen_range  := 8 * repr.body_nCells;
            constant tail_cnt : pktclen_range := repr.head_nFlits;

            function state return state_t is
            begin
                if body_cnt = 0 then
                    return Head_0T;
                elsif tail_cnt = 0 then
                    return Head_B0;
                else
                    -- here must hold: tail_cnt /= 0
                    return Head_BT;
                end if;
            end;
        begin
            return (state, body_cnt, tail_cnt, msg_head);
        end;

        constant mkFstate_extraTail : fstate_t := (ExtraTail, 0, 0, fstate.msg_head);

    begin
        case fstate.state is
            when Idle =>
                if dv then
                    return mkFstate_newPacket;
                else
                    return fstate;
                end if;
                
            when Head_B0 =>
                if dv then
                    return (Body_B0, fstate.body_cnt, fstate.tail_cnt, fstate.msg_head);
                else
                    return fstate;
                end if;
                
            when Head_BT =>
                if dv then
                    return (Body_BT, fstate.body_cnt, fstate.tail_cnt, fstate.msg_head);
                else
                    return fstate;
                end if;
                
            when Head_0T =>
                if dv then
                    return (Tail, fstate.body_cnt, fstate.tail_cnt, fstate.msg_head);
                else
                    return fstate;
                end if;
                
            when Body_BT =>
                if fstate.body_cnt = 1 and dv then
                    return (Tail, fstate.body_cnt - 1, fstate.tail_cnt, fstate.msg_head);
                elsif dv then
                    return (fstate.state, fstate.body_cnt - 1, fstate.tail_cnt, fstate.msg_head);
                else
                    return fstate;
                end if;

            when Body_B0 =>
                if fstate.body_cnt = 1 then
                    -- ignore dv
                    return mkFstate_extraTail;
                elsif dv then
                    return (Body_B0, fstate.body_cnt - 1, fstate.tail_cnt, fstate.msg_head);
                else
                    return fstate;
                end if;
                
            when Tail =>
                if fstate.tail_cnt = 1 then
                    -- ingore dv
                    return mkFstate_extraTail;
                elsif dv then
                    return (fstate.state, fstate.body_cnt, fstate.tail_cnt - 1, fstate.msg_head);
                else
                    return fstate;
                end if;

            when ExtraTail =>
                if dv then
                    return mkFstate_newPacket;
                else
                    return idle_fstate;
                end if;
        end case;
    end;

    signal fstate_next, fstate_curr : fstate_t;

    signal msg_head : msg_head_t;

    signal vdata_curr, vdata_next : vflit_t;

    signal desired_head : boolean;

    function f_atSop(fstate : fstate_t) return boolean is
    begin
        case fstate.state is
            when Head_BT | Head_B0 | Head_0T => return true;
            when others                      => return false;
        end case;
    end;

    function f_atNeop(fstate : fstate_t) return boolean is
    begin
        case fstate.state is
            when Body_B0 => return fstate.body_cnt = 1;
            when Tail    => return fstate.tail_cnt = 1;
            when others  => return false;
        end case;
    end;

    -- FIXME!
    function f_rx_next_cell(fstate : fstate_t) return boolean is
    begin
        case fstate.state is
            when Head_0T => return fstate.tail_cnt = 1;
            when Tail    => return fstate.tail_cnt = 2;
            when Body_BT => return fstate.tail_cnt = 1 and fstate.body_cnt = 1;
            -- NB: here is the difference against f_atNeop. Fire the signal
-- earlier than neop to let parity_fifo have more time to increase it's rx.
            when Body_B0 => return fstate.body_cnt = 3;

            when others => return false;
        end case;
    end;

begin
    msg_head <= decompose(vdata_head.data);

    process (clk, reset, ready)
    begin
        if reset = '1' then
            fstate_curr   <= idle_fstate;
            vdata_curr.dv <= false;
            
        elsif rising_edge(clk) and ready then
            fstate_curr <= fstate_next;
            vdata_curr  <= vdata_next;
        end if;
    end process;

    vdata_next <= vdata_head when desired_head else vdata_body;

    vdata_o <= (compose(fstate_curr.msg_head), true) when fstate_curr.state = ExtraTail
               else (vdata_curr.data, vdata_curr.dv);

    fstate_next <= next_state(fstate_curr, (desired_head and vdata_head.dv) or (not desired_head and vdata_body.dv), msg_head);

    desired_head <= desired_head_not_body(fstate_curr);

    sop          <= f_atSop(fstate_curr) and vdata_curr.dv and ready;
    rx_next_cell <= f_rx_next_cell(fstate_curr) and vdata_curr.dv and ready;

    head   <= conv(fstate_curr.msg_head);
    isIdle <= fstate_curr.state = Idle;

    re_head <= ready and desired_head and not f_atNeop(fstate_curr);
    re_body <= ready and not desired_head;
    
end msg_flit_counter_dual;
