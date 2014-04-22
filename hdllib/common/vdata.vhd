-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.types.all;
use work.util.all;


package vdata is
    ---------------------------------------------------------------------------
    -- vdata: a flit with 'data valid' bit
    ---------------------------------------------------------------------------

    type vdata_t is record
        data : qword;
        dv   : boolean;
    end record;

    type vdata256_t is record
        data : std_logic_vector(255 downto 0);
        dv   : boolean;
    end record;

    function nothing return vdata_t;
    function nothing return vdata256_t;

    type vdata_array is array (integer range <>) of vdata_t;
    type vdata256_array is array (integer range <>) of vdata256_t;

    -- binary (i.e. via std_logic_vector) representation of vdata256_t
    subtype vdata256_binary is std_logic_vector(256 + 1 - 1 downto 0);

    function compose(arg   : vdata256_t) return vdata256_binary;
    function decompose(arg : vdata256_binary) return vdata256_t;

    type vdata256_binary_array is array (integer range <>) of vdata256_binary;

    component vdata256_bypass
        port (
            vdata_i : in  vdata256_t;
            ready_i : out boolean;
            --
            vdata_o : out vdata256_t;
            ready_o : in  boolean;
            --
            clk     : in  std_logic;
            reset   : in  std_logic);
    end component;
end vdata;


package body vdata is
    function nothing return vdata_t is
    begin
        return (dv => false, data => (others => 'X'));
    end;

    function nothing return vdata256_t is
    begin
        return (dv => false, data => (others => 'X'));
    end;

    function compose(arg : vdata256_t) return vdata256_binary is
    begin
        return to_stdl(arg.dv) & arg.data;
    end;

    function decompose(arg : vdata256_binary) return vdata256_t is
    begin
        return (dv   => arg(arg'high) = '1',
                data => arg(data256_t'range));
    end;

end vdata;
