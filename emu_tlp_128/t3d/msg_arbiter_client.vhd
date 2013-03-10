-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;

use work.util.all;


entity msg_arbiter_client is
    port (
        clk, reset : in  std_logic;
        --
        sop, eop   : in  boolean;
        --
        req        : out std_logic;
        ack        : in  std_logic;
        --
        allow      : out boolean);
end entity msg_arbiter_client;

architecture msg_arbiter_client of msg_arbiter_client is
    type state_t is (idle, waiting, transmit, tail);  -- FSM

    type next_state_t is record
        state : state_t;
        req   : std_logic;
        allow : boolean;
    end record;
    
    function next_state(state    : state_t;
                        sop, eop : boolean;
                        ack      : std_logic) return next_state_t is
    begin
        case state is
            when idle =>
                if sop then
                    return (waiting, '1', false);
                else
                    return (state, '0', false);
                end if;

            when waiting =>
                if ack = '1' then
                    return (transmit, '1', true);
                else
                    return (state, '1', false);
                end if;
                
            when transmit =>
                if eop then
                    return (tail, '0', true);  -- drop request
                else
                    return (state, '1', true);
                end if;

            when tail =>
                if sop then
                    return (waiting, '1', false);
                else
                    return (idle, '0', false);
                end if;
        end case;
    end;

    signal scurr, snext : state_t;
begin
    (snext, req, allow) <= next_state(scurr, sop, eop, ack);

    process (clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then         -- synchronous reset (active high)
                scurr <= idle;
            else
                scurr <= snext;
            end if;
        end if;
    end process;
end architecture msg_arbiter_client;
