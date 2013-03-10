-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;

use ieee.std_logic_1164.all;

package stdl_matrix is

    -- alias type with unified name
    subtype stdl_vector is std_logic_vector;

    -- unconstrained 2d matrix
    type stdl_matrix is array (integer range <>, integer range <>) of std_logic;
    
    ---------------------------------------------------------------------------
    -- Curry/uncurry functions are used to convert 2d matrix to 2d vector (an
    -- array of array) and vice versa.
    -- FIXME: It's impossible to define a generic 2d vector type. Have to
    -- copy-paste implementations for all needed array ranges. VHDL sucks. :(
    --
    -- An example of curry/uncurry functions for a certain 2d bit vector
    -- follows. Just copy-paste and replace 'SOME_TYPE_vector2d' type name to
    -- something desired.
    --
    -- type SOME_TYPE_vector2d is array (integer range <>) of stdl_vecor(SOME_RANGE);

    ---------------------------------------------------------------------------
    -- EXAMPLE BEGIN -- cut here
    ---------------------------------------------------------------------------
--    function curry_indices(mat : stdl_matrix) return SOME_TYPE_vector2d is
--        variable vec2d : SOME_TYPE_vector2d(mat'range(1));
--    begin
--        for i in mat'range(1) loop
--            for j in mat'range(2) loop
--                vec2d(i)(j) := mat(i, j);
--            end loop;
--        end loop;

--        return vec2d;
--    end;

--    function uncurry_indices(vec2d : SOME_TYPE_vector2d) return stdl_matrix is
--        variable mat : stdl_matrix(vec2d'range, vec2d(vec2d'low)'range);
--    begin
--        for i in mat'range(1) loop
--            for j in mat'range(2) loop
--                mat(i, j) := vec2d(i)(j);
--            end loop;
--        end loop;

--        return mat;
--    end;
    ---------------------------------------------------------------------------
    -- EXAMPLE END -- cut here
    ---------------------------------------------------------------------------
    
end stdl_matrix;
