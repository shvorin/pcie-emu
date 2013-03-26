-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;

use work.util.all;


entity msg_arbiter_client is
    port (
        clk, reset : in  std_logic;
        --
        sop, eop   : in  std_logic;
        --
        req        : out std_logic;
        ack        : in  std_logic;
        --
        allow      : out std_logic);
end entity msg_arbiter_client;

architecture msg_arbiter_client of msg_arbiter_client is
    type state_t is (idle, waiting, transmit, tail);  -- FSM

    type next_state_t is record
        state : state_t;
        req   : std_logic;
        allow : std_logic;
    end record;
    
    function next_state(state    : state_t;
                        sop, eop : std_logic;
                        ack      : std_logic) return next_state_t is
    begin
        case state is
            when idle =>
                if sop = '1' then
                    return (waiting, '1', '0');
                else
                    return (state, '0', '0');
                end if;

            when waiting =>
                if ack = '1' then
                    return (transmit, '1', '1');
                else
                    return (state, '1', '0');
                end if;
                
            when transmit =>
                if eop = '1' then
                    return (tail, '0', '1');  -- drop request
                else
                    return (state, '1', '1');
                end if;

            when tail =>
                if sop = '1' then
                    return (waiting, '1', '0');
                else
                    return (idle, '0', '0');
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
