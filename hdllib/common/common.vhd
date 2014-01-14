-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;

use ieee.std_logic_1164.all;

package common is

    subtype dword is std_logic_vector(31 downto 0);
    subtype qword is std_logic_vector(63 downto 0);
    subtype qqword is std_logic_vector(127 downto 0);

    subtype data256_t is std_logic_vector(255 downto 0);
end common;
