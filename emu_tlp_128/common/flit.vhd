-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.configure;


package flit is
    ---------------------------------------------------------------------------
    -- Flit ("FLoating unIT") is the very basic type of raw data.
    ---------------------------------------------------------------------------

    subtype data_range is integer range configure.flitWidth-1 downto 0;

    subtype data_t is std_logic_vector(data_range);

    type data_array is array (integer range <>) of data_t;

    function extend64(v : std_logic_vector) return data_t;
    function extend64(i : integer) return data_t;

end flit;


package body flit is
    function extend64(v : std_logic_vector) return data_t is
        variable result : data_t := (others => '0');
    begin
        assert v'length               <= configure.flitWidth;
        result(v'length - 1 downto 0) := v;

        return result;
    end;

    function extend64(i : integer) return data_t is
    begin
        return conv_std_logic_vector(i, configure.flitWidth);
    end;
    
    function sanity_check return boolean is
    begin
        assert
--            bpktlen_t'length = configure.flit_sizeWidth
--            and
            configure.flitWidth = 64
            report "invalid/unsupported configuration";

        return true;
    end;

    constant is_sane : boolean := sanity_check;

end flit;
