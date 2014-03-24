-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;

use ieee.std_logic_1164.all;

package types is
    -- measured in bytes
    constant dword_logsize   : natural := 2;
    constant qword_logsize   : natural := 3;
    constant qqword_logsize  : natural := 4;
    constant data256_logsize : natural := 5;
    constant cell_logsize    : natural := 6;

    ---------------------------------------------------------------------------

    subtype dword_range is integer range 2 ** (dword_logsize + 3) - 1 downto 0;
    subtype dword is std_logic_vector(dword_range);
    type    dword_array is array (integer range <>) of dword;

    subtype qword_range is integer range 2 ** (qword_logsize + 3) - 1 downto 0;
    subtype qword is std_logic_vector(qword_range);
    type    qword_array is array (integer range <>) of qword;

    subtype qqword_range is integer range 2 ** (qqword_logsize + 3) - 1 downto 0;
    subtype qqword is std_logic_vector(qqword_range);
    type    qqword_array is array (integer range <>) of qqword;

    subtype data256_range is integer range 2 ** (data256_logsize + 3) - 1 downto 0;
    subtype data256_t is std_logic_vector(data256_range);
    type    data256_array is array (integer range <>) of data256_t;

    ---------------------------------------------------------------------------

    type boolean_array is array (integer range <>) of boolean;
    type integer_array is array (integer range <>) of integer;
end types;
