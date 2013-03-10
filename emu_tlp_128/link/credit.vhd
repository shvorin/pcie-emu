-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.util.all;
use work.configure;


package credit is
    type bubble_space_t is (none, one, many);

    type bubble_array is array (integer range <>) of bubble_space_t;

    function f_credit_width return integer;

    -- FIXME: this is workaround of GHDL bug
    -- constant credit_width: integer := f_credit_width;
    constant credit_width : integer := 4;

    subtype credit_t is std_logic_vector(credit_width - 1 downto 0);

    type credit_array is array (integer range <>) of credit_t;
end credit;

package body credit is
    function f_credit_width return integer is
    begin
        return ceil_log2(configure.ivc_buffer_bubble_capacity);
    end;

    function sanity_check return boolean is
    begin
        assert
            credit_width = f_credit_width
            report "credit_width value is invalid";

        return true;
    end;

    constant is_sane : boolean := sanity_check;
end credit;

