-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.util.all;


package vdata is

    ---------------------------------------------------------------------------
    -- Compound data: data + valid bit.
    ---------------------------------------------------------------------------

    -- extend raw data with info about packet stage
    type mdata_t is record
        data     : data_t;              -- data
        sop, eop : boolean;             -- start/end of packet
    end record;

    -- vectorized representation: to be kept in FIFOs, RAM, etc
    subtype mdata_vec_t is std_logic_vector(data_t'high + 2 downto data_t'low);

    function compose(data     : data_t;
                     sop, eop : boolean) return mdata_vec_t;

    function compose(arg : mdata_t) return mdata_vec_t;

    function decompose(arg : mdata_vec_t) return mdata_t;

    type vdata_t is record
        val : mdata_t;
        vb  : std_logic;                -- valid bit
    end record;

    -- valid bit is unset, other staff is meaningless
    constant invalid_vdata : vdata_t := (vb  => '0',
                                         val => decompose((others => '0')));

    type vdata_vector is array (integer range <>) of vdata_t;

    ---------------------------------------------------------------------------
    -- vflit: a flit with 'data valid' bit
    ---------------------------------------------------------------------------

    type vflit_t is record
        data : data_t;
        dv   : boolean;
    end record;

    type vflit_vector is array (integer range <>) of vflit_t;

    -- binary (i.e. via std_logic_vector) representation of vflit_t
    subtype vflit_binary is std_logic_vector(data_t'length + 1 - 1 downto 0);

    function compose(arg   : vflit_t) return vflit_binary;
    function decompose(arg : vflit_binary) return vflit_t;

    type vflit_binary_vector is array (integer range <>) of vflit_binary;

    -- valid bit is unset, other staff is meaningless
    constant invalid_vflit : vflit_t := (dv => false, data => (others => '0'));
end vdata;


package body vdata is
    function compose(data     : data_t;
                     sop, eop : boolean) return mdata_vec_t is
        variable result : mdata_vec_t;
    begin
        result(65)           := to_stdl(sop);
        result(64)           := to_stdl(eop);
        result(data_t'range) := data;

        return result;
    end;

    function compose(arg : mdata_t) return mdata_vec_t is
    begin
        return compose(arg.data, arg.sop, arg.eop);
    end;

    function decompose(arg : mdata_vec_t) return mdata_t is
    begin
        return (sop  => arg(65) = '1',
                eop  => arg(64) = '1',
                data => arg(data_range));
    end;

    function compose(arg : vflit_t) return vflit_binary is
    begin
        return to_stdl(arg.dv) & arg.data;
    end;

    function decompose(arg : vflit_binary) return vflit_t is
    begin
        return (dv   => arg(64) = '1',
                data => arg(data_t'range));
    end;

end vdata;
