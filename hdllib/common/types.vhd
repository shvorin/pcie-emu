-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;

use ieee.std_logic_1164.all;

package types is
    subtype dword is std_logic_vector(31 downto 0);
    subtype qword is std_logic_vector(63 downto 0);
    subtype qqword is std_logic_vector(127 downto 0);

    subtype data_range is integer range 63 downto 0;
    subtype data_t is std_logic_vector(data_range);
    type    data_array is array (integer range <>) of data_t;

    subtype data256_range is integer range 255 downto 0;
    subtype data256_t is std_logic_vector(data256_range);
    type    data256_array is array (integer range <>) of data256_t;

    type boolean_array is array (integer range <>) of boolean;
    type integer_array is array (integer range <>) of integer;
end types;
