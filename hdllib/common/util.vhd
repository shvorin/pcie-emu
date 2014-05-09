-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

-- This package contains common types and functions; not router-specific stuff.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc;
use work.types.all;


package util is
    function maximum(constant t1, t2 : natural) return natural;
    function maximum(constant a      : integer_array) return integer;
    function minimum(constant t1, t2 : natural) return natural;
    function minimum(constant t1, t2 : std_logic_vector) return std_logic_vector;
    function minimum(constant a      : integer_array) return integer;

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

    -- treat segment descriptor
    function desc2mask(x : std_logic_vector) return std_logic_vector;
    function desc2base(x : std_logic_vector) return std_logic_vector;
    --
    -- optimized version; hint_logsize must be guaranteed to be no greater than
    -- actual logsize
    function desc2mask(x : std_logic_vector; hint_logsize : natural; exact : boolean := false) return std_logic_vector;
    function desc2base(x : std_logic_vector; hint_logsize : natural; exact : boolean := false) return std_logic_vector;

    function extend64(v : std_logic_vector) return qword;
    function extend64(i : integer) return qword;

    function extend(size : natural; v : std_logic_vector) return std_logic_vector;

    -- from std_logic_1164_additions
    function to_hstring (value : std_ulogic_vector) return string;
    function to_hstring (value : std_logic_vector) return string;
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

    function maximum (constant a : integer_array) return integer is
        variable result : integer := a(a'low);
    begin
        for i in a'range loop
            if a(i) > result then
                result := a(i);
            end if;
        end loop;
        return result;
    end;

    function minimum (constant t1, t2 : natural) return natural is
    begin
        if t1 < t2 then return t1; else return t2; end if;
    end minimum;

    function minimum (constant t1, t2 : std_logic_vector) return std_logic_vector is
    begin
        if t1 < t2 then return t1; else return t2; end if;
    end;

    function minimum (constant a : integer_array) return integer is
        variable result : integer := a(a'low);
    begin
        for i in a'range loop
            if a(i) < result then
                result := a(i);
            end if;
        end loop;
        return result;
    end;

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

    -- treat segment descriptor
    function desc2mask(x : std_logic_vector) return std_logic_vector is
    begin
        return (x-1) xor x;
    end;

    function desc2base(x : std_logic_vector) return std_logic_vector is
    begin
        return (x-1) and x;
    end;

    function desc2mask(x : std_logic_vector; hint_logsize : natural; exact : boolean := false)
        return std_logic_vector
    is
        subtype hi_range is integer range x'high downto x'low + hint_logsize;
        subtype lo_range is integer range x'low + hint_logsize - 1 downto x'low;

        variable result : std_logic_vector(x'range);
    begin
        result(lo_range) := (others => '1');

        if exact then
            result(hi_range) := (others => '0');
        else
            result(hi_range) := desc2mask(x(hi_range));
        end if;
        return result;
    end;

    function desc2base(x : std_logic_vector; hint_logsize : natural; exact : boolean := false)
        return std_logic_vector
    is
        constant tail : std_logic_vector(hint_logsize - 1 downto 0) := (others => '0');
    begin
        if exact then
            return x(x'high downto x'low + hint_logsize) & tail;
        else
            return desc2base(x(x'high downto x'low + hint_logsize)) & tail;
        end if;
    end;

    function extend64(v : std_logic_vector) return qword is
        variable result : qword := (others => '0');
    begin
        result(v'length - 1 downto 0) := v;

        return result;
    end;

    function extend64(i : integer) return qword is
    begin
        return conv_std_logic_vector(i, 64);
    end;

    function extend(size : natural; v : std_logic_vector) return std_logic_vector is
        variable result : std_logic_vector(size - 1 downto 0) := (others => '0');
    begin
        result(v'length - 1 downto 0) := v;

        return result;
    end;

    function to_hstring (value : std_ulogic_vector) return string is
        constant ne     : integer := (value'length+3)/4;
        variable pad    : std_ulogic_vector(0 to (ne*4 - value'length) - 1);
        variable ivalue : std_ulogic_vector(0 to ne*4 - 1);
        variable result : string(1 to ne);
        variable quad   : std_ulogic_vector(0 to 3);
    begin
        if value'length < 1 then
            return "";
        else
            if value (value'left) = 'Z' then
                pad := (others => 'Z');
            else
                pad := (others => '0');
            end if;
            ivalue := pad & value;
            for i in 0 to ne-1 loop
                quad := To_X01Z(ivalue(4*i to 4*i+3));
                case quad is
                    when x"0"   => result(i+1) := '0';
                    when x"1"   => result(i+1) := '1';
                    when x"2"   => result(i+1) := '2';
                    when x"3"   => result(i+1) := '3';
                    when x"4"   => result(i+1) := '4';
                    when x"5"   => result(i+1) := '5';
                    when x"6"   => result(i+1) := '6';
                    when x"7"   => result(i+1) := '7';
                    when x"8"   => result(i+1) := '8';
                    when x"9"   => result(i+1) := '9';
                    when x"A"   => result(i+1) := 'A';
                    when x"B"   => result(i+1) := 'B';
                    when x"C"   => result(i+1) := 'C';
                    when x"D"   => result(i+1) := 'D';
                    when x"E"   => result(i+1) := 'E';
                    when x"F"   => result(i+1) := 'F';
                    when "ZZZZ" => result(i+1) := 'Z';
                    when others => result(i+1) := 'X';
                end case;
            end loop;
            return result;
        end if;
    end function to_hstring;

    function to_hstring (value : std_logic_vector) return string is
    begin
        return to_hstring (to_stdulogicvector (value));
    end function to_hstring;
end util;
