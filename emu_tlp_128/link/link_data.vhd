-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.credit.all;
use work.configure;


package link_data is
    subtype lpack_len_t is integer range 0 to 7;  -- TODO: tune maximum length!

    type lheader_t is record
        credit    : credit_t;
        lpack_len : lpack_len_t;
        flowcount : std_logic_vector(31 downto 0);
    end record;

    function compose(head   : lheader_t) return data_t;
    function decompose(data : data_t) return lheader_t;

end link_data;


package body link_data is
    subtype credit_range is integer range 63 downto 64 - credit_width;
    subtype unused_range is integer range 64 - credit_width - 1 downto 3;
    subtype flowcount_range is integer range 34 downto 3;
    subtype len_range is integer range 2 downto 0;  -- 3

    function compose(head : lheader_t) return data_t is
        variable data : data_t;
    begin
        data(credit_range)    := head.credit;
        data(unused_range)    := (others => '0');
        data(flowcount_range) := head.flowcount;
        data(len_range)       := conv_std_logic_vector(head.lpack_len, 3);

        return data;
    end;

    function decompose(data : data_t) return lheader_t is
    begin
        return (credit    => data(credit_range),
                lpack_len => conv_integer(data(len_range)),
                flowcount => data(flowcount_range));
    end;

end link_data;
