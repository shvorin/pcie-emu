-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use work.util.all;


entity arbiter is
    generic (
        NCOMPETITORS : positive);

    port (
        clk, reset : in  std_logic;     -- asynchronous reset (active high)
        --
        ena        : in  std_logic;
        --
        req        : in  std_logic_vector(0 to NCOMPETITORS-1);
        ack        : out std_logic_vector(0 to NCOMPETITORS-1));
end arbiter;


architecture arbiter of arbiter is
    subtype competitors_range is integer range 0 to NCOMPETITORS-1;
    subtype competitors_t is std_logic_vector(competitors_range);

    type state_t is (idle, busy, swch);  -- pure FSM state

    type fstate_t is record             -- the full state of FSM
        state : state_t;                -- pure FSM state
        win   : competitors_t;          -- the winner; some bit must be set
    end record;

    
    function next_state (
        constant fstate : in fstate_t;       -- current full state of FSM
        constant req    : in competitors_t;  -- input requests
        constant ena    : in std_logic
        ) return fstate_t is

        -----------------------------------------------------------------------
        -- nr stands for "all reqs with higher priority than mine are unset"
        type nr_t is array (competitors_range) of competitors_t;

        function jor_ranged (constant l : natural; constant r : natural)
            return std_logic is
        begin
            if l >= r then
                return or_reduce(req(r to l));
            else
                return or_reduce(req(req'left to l)) or or_reduce(req(r to req'right));
            end if;
        end;


        function to_range(x : integer) return natural is
        begin
            return req'low + (x - req'low) mod req'length;
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
            assert or_reduce(req) report "win: invalid call";

            for i in competitors_t'range loop
                for p in competitors_t'range loop
                    result(i) := result(i) or (fstate.win(p) and no_competitors(p, i));
                end loop;  -- p
            end loop;  -- i

            return result and req;
        end;
        
    begin  -- next_state
        case fstate.state is
            when idle =>
                if or_reduce(req) and ena = '1' then
                    return (busy, win);
                else
                    return fstate;      -- no changes
                end if;

            when busy =>
                if or_reduce(fstate.win and not req) then
                    return (swch, fstate.win);
                else
                    return fstate;
                end if;
                
            when swch =>
                if or_reduce(req) and ena = '1' then
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
            scurr.win(0 to NCOMPETITORS-2) <= (others => '0');
            -- NB: the 0-th competitor must have the highest proirity,
            -- so light the last (lowest priority) bit
            scurr.win(NCOMPETITORS-1)      <= '1';
            
        elsif rising_edge(clk) then
            scurr <= snext;
        end if;
    end process;

    snext <= next_state(scurr, req, ena);

    ack <= scurr.win and to_stdl(scurr.state /= idle);
end arbiter;
