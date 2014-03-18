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
        data : data_t;
        dv   : boolean;
    end record;

    type vdata256_t is record
        data : std_logic_vector(255 downto 0);
        dv   : boolean;
    end record;

    type vdata_array is array (integer range <>) of vdata_t;
    type vdata256_array is array (integer range <>) of vdata256_t;

    -- binary (i.e. via std_logic_vector) representation of vdata_t
    subtype vdata_binary is std_logic_vector(data_t'length + 1 - 1 downto 0);

    function compose(arg   : vdata_t) return vdata_binary;
    function decompose(arg : vdata_binary) return vdata_t;

    type vdata_binary_vector is array (integer range <>) of vdata_binary;

    -- valid bit is unset, other staff is meaningless
    constant invalid_vdata : vdata_t := (dv => false, data => (others => '0'));
end vdata;


package body vdata is
    function compose(arg : vdata_t) return vdata_binary is
    begin
        return to_stdl(arg.dv) & arg.data;
    end;

    function decompose(arg : vdata_binary) return vdata_t is
    begin
        return (dv   => arg(64) = '1',
                data => arg(data_t'range));
    end;

end vdata;
