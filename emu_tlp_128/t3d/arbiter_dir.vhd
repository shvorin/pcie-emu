-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- This is version of OVC arbiter capable to treat one specified port (so
-- called direct) specially. The direct port requires 1 bubble of space while
-- others require 2 bubbles.

library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use work.credit.all;
use work.util.all;


entity arbiter_dir is
    generic (
        nCompetitors : integer;
        useDirect    : boolean := false;  -- whether to use direct
        direct       : integer := 0);

    port (
        clk, reset   : in  std_logic;   -- asynchronous reset (active high)
        --
        bubble_space : in  bubble_space_t;
        --
        -- FIXME
        sop          : out boolean;
        --
        req          : in  std_logic_vector(0 to nCompetitors-1);
        ack          : out std_logic_vector(0 to nCompetitors-1));
end arbiter_dir;


architecture arbiter_dir of arbiter_dir is
    subtype competitors_range is integer range 0 to nCompetitors-1;
    subtype competitors_t is std_logic_vector(competitors_range);

    type state_t is (idle, busy, swch);  -- pure FSM state

    type fstate_t is record             -- the full state of FSM
        state : state_t;                -- pure FSM state
        win   : competitors_t;          -- the winner; some bit must be set
    end record;

    
    function next_state (
        constant fstate       : fstate_t;       -- current full state of FSM
        constant req          : competitors_t;  -- input requests
        constant bubble_space : bubble_space_t
        ) return fstate_t is

        function req_filtered return competitors_t is
            variable filter : competitors_t;
        begin
            if useDirect then
                filter         := (others => to_stdl(bubble_space = many));
                filter(direct) := to_stdl(bubble_space /= none);
            else
                filter := (others => to_stdl(bubble_space /= none));
            end if;

            return req and filter;
        end;

        constant req_1 : competitors_t := req_filtered;

        -----------------------------------------------------------------------
        -- nr stands for "all reqs with higher priority than mine are unset"
        type nr_t is array (competitors_range) of competitors_t;

        function jor_ranged (constant l : natural; constant r : natural)
            return std_logic is
        begin
            if l >= r then
                return or_reduce(req_1(r to l));
            else
                return or_reduce(req_1(req_1'left to l)) or or_reduce(req_1(r to req_1'right));
            end if;
        end;


        function to_range(x : integer) return natural is
        begin
            return req_1'low + (x - req_1'low) mod req_1'length;
        end;


        function no_competitors (constant lowest_pri : natural; constant i : natural)
            return std_logic is

            constant highest_pri : natural := to_range(lowest_pri+1);
            constant i1          : natural := to_range(i-1);
        begin
            if highest_pri = i then
                return '1';
            else
                return not jor_ranged(i1, highest_pri);
            end if;
        end;


        function win return competitors_t is
            variable result : competitors_t := (others => '0');
        begin
            for i in competitors_t'range loop
                for p in competitors_t'range loop
                    result(i) := result(i) or (fstate.win(p) and no_competitors(p, i));
                end loop;  -- p
            end loop;  -- i

            return result and req_1;
        end;
        
    begin  -- next_state
        case fstate.state is
            when busy =>
                if not nor_reduce(fstate.win and not req) then
                    return (swch, fstate.win);
                else
                    return (fstate.state, fstate.win);
                end if;
                
            when idle | swch =>
                if not nor_reduce(req_1) then
                    return (busy, win);
                else
                    return (idle, fstate.win);
                end if;
        end case;
    end;  -- next_state

    signal scurr, snext : fstate_t;

begin  -- arbiter
    process (clk, reset)
    begin
        if reset = '1' then             -- asynchronous reset (active high)

            -- set scurr to initial state
            scurr.state                    <= idle;
            scurr.win(0 to nCompetitors-2) <= (others => '0');
            -- NB: the 0-th competitor must have the highest proirity,
            -- so light the last (lowest priority) bit
            scurr.win(nCompetitors-1)      <= '1';

        elsif rising_edge(clk) then
            scurr <= snext;
        end if;
    end process;

    snext <= next_state(scurr, req, bubble_space);

    ack <= scurr.win and to_stdl(scurr.state /= idle);

    -- FIXME: this may be incorrect...
    sop <= snext.state = busy and scurr.state /= busy;
end arbiter_dir;
