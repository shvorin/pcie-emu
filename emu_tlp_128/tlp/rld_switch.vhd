-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.util.all;
use work.rld.all;


-- forks a RAM-like device into a number of such devices
entity rld_switch is
    generic (
        -- keeps segment start and end of each child RLD
        -- TODO: assert than segments do not overlap
        SEG_INFO : seg_info_array);

    port (
        i_root : in  i_rld_t;
        o_root : out o_rld_t;
        --
        i_chld : out i_rld_array(0 to SEG_INFO'length - 1);
        o_chld : in  o_rld_array(0 to SEG_INFO'length - 1));
end entity rld_switch;


architecture rld_switch of rld_switch is
    -- NB: do not access seg_bases directly, use this function instead!
    function fseg(i : integer) return seg_info_t is
    begin
        return SEG_INFO(SEG_INFO'low + i);
    end;

    function seg_num(addr : addr_t) return integer is
    begin
        for i in i_chld'range loop
            if fseg(i).seg_start <= addr and addr < fseg(i).seg_end then
                return i;
            end if;
        end loop;

        return i_chld'high + 1;         -- meaningless, marked as out of range
    end;

    function fmux(addr : addr_t; inputs : o_rld_array) return o_rld_t is
        variable result : o_rld_t;
    begin
        for i in inputs'range loop
            if seg_num(addr) = i then
                result := inputs(i);
            end if;
        end loop;

        return result;
    end;

begin
    -- DMX
    dmx : for i in i_chld'range generate
        i_chld(i) <= (
            rd_addr => i_root.rd_addr - fseg(i).seg_start,
            wr_addr => i_root.wr_addr - fseg(i).seg_start,
            wr_data => i_root.wr_data,
            we      => i_root.we and to_stdl(i = seg_num(i_root.wr_addr)));

    end generate;

    -- MUX
    o_root <= fmux(i_root.rd_addr, o_chld);
    
end architecture rld_switch;
