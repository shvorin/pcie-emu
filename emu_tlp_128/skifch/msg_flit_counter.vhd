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


entity msg_flit_counter is
    port (
        clk, reset     : in  std_logic;  -- asynchronous reset (active high)
        --
        vdata_i        : in  vflit_t;
        vdata_o        : out vflit_t;
        --
        ready          : in  boolean;
        --
        -- the following result values make sense only when vdata_o.dv
        sop, eop, neop : out boolean;   -- "start"/"end"/"nearly end" of packet
        head           : out net_head_t;
        isIdle         : out boolean;
        count          : out pktlen_range);
end msg_flit_counter;


architecture msg_flit_counter of msg_flit_counter is
    type state_t is (Idle, Run);

    type fstate_t is record
        state : state_t;
        count : pktlen_range;
        head  : net_head_t;
    end record;

    constant idle_fstate : fstate_t := (Idle, 0, decompose((others => '0')));

    function next_state(fstate : fstate_t;
                        dv     : boolean;
                        head   : net_head_t) return fstate_t
    is
        constant mkFstate_newPacket : fstate_t := (Run, head.pktlen, head);

        function mkFstate_step return fstate_t is
            variable result : fstate_t := fstate;
        begin
            result.count := result.count - 1;
            return result;
        end;
        
    begin
        case fstate.state is
            when Idle =>
                if dv then
                    return mkFstate_newPacket;
                else
                    return fstate;
                end if;
                
            when Run =>
                if fstate.count = 1 then
                    if dv then
                        return mkFstate_newPacket;
                    else
                        return idle_fstate;
                    end if;
                else
                    if dv then
                        return mkFstate_step;
                    else
                        return fstate;
                    end if;
                end if;
        end case;
    end;

    signal fstate, fstate_ff : fstate_t;

    signal msg_head : msg_head_t;
    signal net_head : net_head_t;

    signal vdata_ff : vflit_t;
    
begin
    msg_head <= decompose(vdata_i.data);
    net_head <= conv(msg_head);

    process (clk, reset, ready)
    begin
        if reset = '1' then
            fstate_ff   <= idle_fstate;
            vdata_ff.dv <= false;
            
        elsif rising_edge(clk) and ready then
            fstate_ff <= fstate;
            vdata_ff  <= vdata_i;
        end if;
    end process;

    vdata_o <= vdata_ff;

    fstate <= next_state(fstate_ff, vdata_i.dv, net_head);

    count <= fstate_ff.count;
    sop   <= fstate_ff.count = fstate_ff.head.pktlen and vdata_ff.dv;
    eop   <= fstate_ff.count = 1 and vdata_ff.dv;
    neop  <= fstate_ff.count = 2 and vdata_ff.dv;  -- "nearly end of packet"

    head   <= fstate_ff.head;
    isIdle <= fstate_ff.state = Idle;
    
end msg_flit_counter;
