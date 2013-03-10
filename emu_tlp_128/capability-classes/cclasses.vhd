-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- This package describes Capability Classes staff.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc;
use work.rld.all;
use work.util.all;
use work.flit.all;
use work.config;


package cclasses is
    constant ccname_length : integer := 256/8;  -- 256 bytes

    subtype word8_t is std_logic_vector(7 downto 0);

    type word8_array is array (integer range <>) of word8_t;

    type string_style_t is (C,          -- append '\0' at the end
                            Pascal,     -- insert 32 bits prefix with size 
                            None);

    function conv(s : string; style : string_style_t) return word8_array;
    function conv(s : string; style : string_style_t) return data_array;

    function conv_w8_to_w64(a : word8_array) return data_array;

    function expand(a       : data_array; length : integer) return data_array;
    function mk_ccname(name : string) return data_array;

    function eq(addr : addr_t; i : integer) return boolean;

    constant placeholder0 : data_t             := (others => 'Z');
    constant placeholder  : data_array(0 to 0) := (0      => placeholder0);

    constant zero0 : data_t     := (others => '0');
    constant zero  : data_array := (0      => zero0);

    function mk_markup(fld_lengths : integer_array) return integer_array;

    function match(offset : integer; i_rld : i_rld_t; value : data_t) return o_rld_t;
    function match(offset : integer; i_rld : i_rld_t; values : data_array) return o_rld_t;
    function match(offset : integer; i_rld : i_rld_t) return boolean;
    
end cclasses;


package body cclasses is
    function conv(c : character) return std_logic_vector is
    begin
        return conv_std_logic_vector(character'pos(c), 8);
    end;

    function conv(s : string; style : string_style_t) return word8_array is
        variable result : word8_array(s'range);

        constant zero : word8_t := (others => '0');

        function prefix return word8_array is
            constant size : std_logic_vector(31 downto 0) := conv_std_logic_vector(s'length, 32);
        begin
            return (size(7 downto 0),
                    size(15 downto 8),
                    size(23 downto 16),
                    size(31 downto 24));
        end;
        
    begin
        for i in s'range loop
            result(i) := conv(s(i));
        end loop;

        case style is
            when None => return result;

            when C => return result & zero;

            when Pascal => return prefix & result;
        end case;
    end;

    function conv_w8_to_w64(a : word8_array) return data_array is
        function expand_w8 return word8_array is
            constant extra_len : integer := (-a'length) mod 8;

            function zeroes return word8_array is
            begin
                return (1 to extra_len => (others => '0'));
            end;

        begin
            if extra_len = 0 then
                return a;
            else
                return a & zeroes;
            end if;
        end;

        constant w8_length : integer := (a'length + 7) / 8 * 8;

        constant w8 : word8_array(0 to w8_length - 1) := expand_w8;

        variable result : data_array(0 to w8_length/8 - 1);
        
    begin
        for i in result'range loop
            for k in 0 to 7 loop
                result(i)(8*k + 7 downto 8*k)
                    := w8(w8'low + 8*i + k);
            end loop;
        end loop;

        return result;
    end;

    function conv(s : string; style : string_style_t) return data_array is
    begin
        return conv_w8_to_w64(conv(s, style));
    end;

    function expand(a : data_array; length : integer) return data_array is
        variable result : data_array(0 to length - 1) := (others => (others => '0'));
    begin
        assert a'length <= length;

        for i in a'range loop
            result(i - a'low) := a(i);
        end loop;

        return result;
    end;

    function mk_ccname(name : string) return data_array is
    begin
        return expand(conv(name, C), ccname_length);
    end;

    function eq(addr : addr_t; i : integer) return boolean is
        constant ctrl_bar_logsize : integer := config.bar_size_mask(config.ctrl_bar_num);
    begin
        return addr(ctrl_bar_logsize downto 3) = conv_std_logic_vector(i, ctrl_bar_logsize - 3);
    end;

    function mk_markup(fld_lengths : integer_array) return integer_array is

        variable result : integer_array(fld_lengths'low to fld_lengths'high + 1);

        variable offset : integer := 0;
    begin

        for k in fld_lengths'range loop
            result(k) := offset;
            offset    := offset + fld_lengths(k);
        end loop;

        result(result'high) := offset;

        return result;
    end;

    function match(offset : integer; i_rld : i_rld_t; value : data_t) return o_rld_t is
        variable result : o_rld_t := nothing;
    begin
        if eq(i_rld.rd_addr, offset) then
            result := (value, true);
        end if;

        return result;
    end;

    function match(offset : integer; i_rld : i_rld_t; values : data_array) return o_rld_t is
        variable result : o_rld_t := nothing;
    begin
        for k in values'range loop
            if eq(i_rld.rd_addr, offset + k - values'low) then
                result := (values(k), true);
            end if;
        end loop;

        return result;
    end;

    function match(offset : integer; i_rld : i_rld_t) return boolean is
    begin
        return i_rld.we = '1' and eq(i_rld.wr_addr, offset);
    end;

end cclasses;

