-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- This package contains common types and functions; not router-specific stuff.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc;


package util is
    type boolean_array is array (integer range <>) of boolean;
    type integer_array is array (integer range <>) of integer;
    type integer_array2 is array (integer range <>, integer range <>) of integer;

    function maximum (constant t1, t2 : natural) return natural;
    function minimum (constant t1, t2 : natural) return natural;

    -- nearly the same as UNSIGNED_NUM_BITS from ieee.numeric_bit
    -- NB: UNSIGNED_NUM_BITS seem to be incorrect ;)
    function ceil_log2 (constant x : positive) return natural;

    function nor_reduce(v  : std_logic_vector) return std_logic;
    function or_reduce(v   : std_logic_vector) return std_logic;
    function and_reduce(v  : std_logic_vector) return std_logic;
    function nand_reduce(v : std_logic_vector) return std_logic;

    function nor_reduce(v  : std_logic_vector) return boolean;
    function or_reduce(v   : std_logic_vector) return boolean;
    function and_reduce(v  : std_logic_vector) return boolean;
    function nand_reduce(v : std_logic_vector) return boolean;

    -- "unary logarithm": finds the highest set bit and drops all other bits;
-- if argument is zero the result is also zero
    function unary_log (constant v : std_logic_vector) return std_logic_vector;

    function "and" (constant arg : std_logic_vector; constant s : std_logic)
        return std_logic_vector;

    -- encodes bit range into binary representation (i.e. returns the number of
-- (the only) lit bit, otherwise result is meaningless). FIXME: why to
-- (re-)implement a simple library function?!
    function encode (constant arg : std_logic_vector) return natural;

    function to_stdl (constant v : in boolean) return std_logic;

    -- drop all bits except the lowest fired
    function lowest_fired (arg : std_logic_vector) return std_logic_vector;

    function invert(arg : std_logic_vector) return std_logic_vector;

    function singleton(arg : std_logic) return std_logic_vector;

    function align2_down(v : std_logic_vector) return std_logic_vector;
    function align8_down(v : std_logic_vector) return std_logic_vector;
    function align8_up(v   : std_logic_vector) return std_logic_vector;
end util;


package body util is

    function ceil_log2 (constant x : positive)
        return natural is

        function hlp (constant x : natural) return natural is
        begin
            if x < 1 then
                return 0;
            else
                return 1 + hlp(x/2);
            end if;
        end;
        
    begin  -- ceil_log2
        return hlp(x-1);
    end ceil_log2;


    function nor_reduce(v : std_logic_vector) return std_logic is
    begin
        return std_logic_misc.nor_reduce(v);
    end;

    function or_reduce(v : std_logic_vector) return std_logic is
    begin
        return std_logic_misc.or_reduce(v);
    end;

    function and_reduce(v : std_logic_vector) return std_logic is
    begin
        return std_logic_misc.and_reduce(v);
    end;

    function nand_reduce(v : std_logic_vector) return std_logic is
    begin
        return std_logic_misc.nand_reduce(v);
    end;

    function nor_reduce(v : std_logic_vector) return boolean is
    begin
        return nor_reduce(v) = '1';
    end;

    function or_reduce(v : std_logic_vector) return boolean is
    begin
        return or_reduce(v) = '1';
    end;

    function and_reduce(v : std_logic_vector) return boolean is
    begin
        return and_reduce(v) = '1';
    end;

    function nand_reduce(v : std_logic_vector) return boolean is
    begin
        return nand_reduce(v) = '1';
    end;


    function unary_log (constant v : std_logic_vector)
        return std_logic_vector is
        alias u : std_logic_vector(v'high downto v'low) is v;

        variable result : std_logic_vector(u'range);
    begin
        for i in u'range loop
            if i = u'high then
                result(i) := u(i);
            else
                result(i) := u(i) and nor_reduce(u(u'high downto i+1));  -- FIXME
            end if;
        end loop;  -- i

        return result;
    end unary_log;


    function maximum (constant t1, t2 : natural) return natural is
    begin
        if t1 > t2 then return t1; else return t2; end if;
    end maximum;

    function minimum (constant t1, t2 : natural) return natural is
    begin
        if t1 < t2 then return t1; else return t2; end if;
    end minimum;


    function "and" (constant arg : std_logic_vector; constant s : std_logic)
        return std_logic_vector is

        variable result : std_logic_vector(arg'range);
    begin  -- "and"
        for i in arg'range loop
            result(i) := arg(i) and s;
        end loop;  -- i

        return result;
    end "and";


    function encode (constant arg : std_logic_vector) return natural is
        alias xarg      : std_logic_vector(0 to arg'length-1) is arg;
        constant sz     : natural := ceil_log2(xarg'length);
        variable result : std_logic_vector(sz-1 downto 0);

        variable sum : std_logic;

        variable b, p : natural;

        variable t : natural := 1;
    begin
        for i in 0 to sz-1 loop
            b   := t;
            t   := 2 * t;
            p   := t;
            sum := '0';

            eval_result_i : loop
                exit when b > xarg'high;
                
                sum := sum or not nor_reduce(xarg(xarg'low + b
                                                  to xarg'low + minimum(p-1, xarg'high)));

                b := b + t;
                p := p + t;

            end loop eval_result_i;

            result(i) := sum;

        end loop;  -- i

        return conv_integer(result);
    end;


    function to_stdl (constant v : in boolean) return std_logic is
    begin
        if v then
            return '1';
        else
            return '0';
        end if;
    end;

    function lowest_fired (arg : std_logic_vector) return std_logic_vector is
        variable result : std_logic_vector(arg'range);

        function no_competitors(i : integer) return std_logic is
        begin
            if i = arg'low then
                return '1';
            end if;

            if arg'ascending then
                return nor_reduce(arg(arg'low to i-1));
            else
                return nor_reduce(arg(i-1 downto arg'low));
            end if;
        end;
        
    begin
        for i in arg'range loop
            result(i) := arg(i) and no_competitors(i);
        end loop;

        return result;
    end;

    function invert(arg : std_logic_vector) return std_logic_vector is
        variable result : std_logic_vector(arg'range);
        
    begin
        for i in arg'range loop
            result(i) := arg(arg'left + arg'right - i);
        end loop;

        return result;
    end;

    function singleton(arg : std_logic) return std_logic_vector is
    begin
        return (0 => arg);
    end;

    function align8_down(v : std_logic_vector) return std_logic_vector is
    begin
        return v(v'high downto v'low + 3) & "000";
    end;

    function align2_down(v : std_logic_vector) return std_logic_vector is
    begin
        return v(v'high downto v'low + 1) & "0";
    end;

    function align8_up(v : std_logic_vector) return std_logic_vector is
        constant v1 : std_logic_vector(v'range) := v + "111";
    begin
        return v1(v'high downto v'low + 3) & "000";
    end;

end util;
