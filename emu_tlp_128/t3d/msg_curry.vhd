-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.vdata.all;
use work.stdl_matrix.all;


package msg_curry is

    ---------------------------------------------------------------------------
    -- vflit
    ---------------------------------------------------------------------------
    
    function curry_indices(mat     : stdl_matrix) return vflit_binary_vector;
    function uncurry_indices(vec2d : vflit_binary_vector) return stdl_matrix;

    function map_decompose(mat : stdl_matrix) return vflit_vector;
    function map_compose(arr   : vflit_vector) return stdl_matrix;

end msg_curry;

package body msg_curry is

    -- curry/uncurry functions are copy-pasted from example in stdl_matrix.vhd
    
    function curry_indices(mat : stdl_matrix) return vflit_binary_vector is
        variable vec2d : vflit_binary_vector(mat'range(1));
    begin
        for i in mat'range(1) loop
            for j in mat'range(2) loop
                vec2d(i)(j) := mat(i, j);
            end loop;
        end loop;

        return vec2d;
    end;


    function uncurry_indices(vec2d : vflit_binary_vector) return stdl_matrix is
        variable mat : stdl_matrix(vec2d'range, vec2d(vec2d'low)'range);
    begin
        for i in mat'range(1) loop
            for j in mat'range(2) loop
                mat(i, j) := vec2d(i)(j);
            end loop;
        end loop;

        return mat;
    end;

    ---------------------------------------------------------------------------

    function map_decompose(mat : stdl_matrix) return vflit_vector is
        constant gdata_all : vflit_binary_vector(mat'range(1)) := curry_indices(mat);

        variable vdata_all : vflit_vector(mat'range(1));
    begin
        for n in mat'range(1) loop
            vdata_all(n) := decompose(gdata_all(n));
        end loop;

        return vdata_all;
    end;

    function map_compose(arr : vflit_vector) return stdl_matrix is

        variable gdata_all : vflit_binary_vector(arr'range);
    begin
        for n in arr'range loop
            gdata_all(n) := compose(arr(n));
        end loop;

        return uncurry_indices(gdata_all);
    end;

end msg_curry;
