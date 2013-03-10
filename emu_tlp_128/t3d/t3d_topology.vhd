-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.net_flit.all;
use work.vdata.all;
use work.util.all;
use work.configure;


package t3d_topology is
    constant nDims : positive := 3;     -- torus dimension
    constant nDirs : positive := 2*nDims + configure.ports_perNode;  -- number of directions

    type dims3_t is (x, y, z);

    type integer_3vector is array (dims3_t) of integer;

    subtype dimension_range is integer range 0 to 15;  -- FIXME: should depend
-- on node_t format

    type coord_t is array (dims3_t) of dimension_range;

    subtype nodeId_range is integer range 0 to configure.nNodes - 1;

    subtype dirId_range is integer range 0 to nDirs - 1;
    subtype pe_dirId_range is integer range 0 to configure.ports_perNode - 1;
    subtype t3d_dirId_range is integer range configure.ports_perNode to dirId_range'high;

    ---------------------------------------------------------------------------
    -- "static" functions -- to be used to bind instances with signals

    function serial(size3   : integer_3vector; c : coord_t) return nodeId_range;
    function deserial(size3 : integer_3vector; n : nodeId_range) return coord_t;

    function neighbour(size3 : integer_3vector; c : coord_t; p : integer) return coord_t;
    function neighbour(size3 : integer_3vector; n : nodeId_range; p : integer) return nodeId_range;

    function ext_portId(n : nodeId_range;
                        p : valid_portId_range) return integer;

    function ext_portId(size3 : integer_3vector; a : portAddr_t) return integer;

    function opposite_dir(p : t3d_dirId_range) return t3d_dirId_range;

    ---------------------------------------------------------------------------
    -- "dynamic" functions -- to be used in logic

    function decompose(node : node_t) return coord_t;
    function compose(c      : coord_t) return node_t;

    subtype dirbits_t is std_logic_vector(5 downto 0);

    function mk_dirbits(size3 : integer_3vector; curr, dest : coord_t) return dirbits_t;
    
end t3d_topology;


package body t3d_topology is
    function serial(size3 : integer_3vector; c : coord_t) return nodeId_range is
    begin
        return c(x) + size3(x) * (c(y) + c(z) * size3(y));
    end;

    function deserial(size3 : integer_3vector; n : nodeId_range) return coord_t is
        constant n1 : natural := n / size3(x);
        constant n2 : natural := n1 / size3(y);
    begin
        assert n2 < size3(z) report "oops, coord overflow";
        return (n mod size3(x), n1 mod size3(y), n2);
    end;

    function neighbour(size3 : integer_3vector; c : coord_t; p : integer) return coord_t is
        constant d : integer := p - configure.ports_perNode;

        variable result : coord_t := c;
    begin
        -- FIXME: rewrite the code!
        case d is
            when 0 =>
                -- +X
                if c(x) = size3(x) - 1 then
                    result(x) := 0;
                else
                    result(x) := result(x) + 1;
                end if;
                
            when 1 =>
                -- +Y
                if c(y) = size3(y) - 1 then
                    result(y) := 0;
                else
                    result(y) := result(y) + 1;
                end if;

            when 2 =>
                -- +Z
                if c(z) = size3(z) - 1 then
                    result(z) := 0;
                else
                    result(z) := result(z) + 1;
                end if;

            when 3 =>
                -- -X
                if c(x) = 0 then
                    result(x) := size3(x) - 1;
                else
                    result(x) := result(x) - 1;
                end if;

            when 4 =>
                -- -Y
                if c(y) = 0 then
                    result(y) := size3(y) - 1;
                else
                    result(y) := result(y) - 1;
                end if;

            when 5 =>
                -- -Z
                if c(z) = 0 then
                    result(z) := size3(z) - 1;
                else
                    result(z) := result(z) - 1;
                end if;

            when others =>
                assert false;
                report "invalid data";
        end case;

        return result;
    end;

    function neighbour(size3 : integer_3vector; n : nodeId_range; p : integer) return nodeId_range is
    begin
        return serial(size3, neighbour(size3, deserial(size3, n), p));
    end;

    -- NB: result must be checked whether it belongs to valid_portId_range
    function ext_portId(n : nodeId_range;
                        p : valid_portId_range) return integer is
    begin
        return n * configure.ports_perNode + p;
    end;

    function ext_portId(size3 : integer_3vector;
                        a     : portAddr_t) return integer is
    begin
        return ext_portId(serial(size3, decompose(a.node)), a.portId);
    end;

    function opposite_dir(p : t3d_dirId_range) return t3d_dirId_range is
        constant d : integer := p - configure.ports_perNode;
    begin
        if d < 3 then
            return configure.ports_perNode + d + 3;
        else
            return configure.ports_perNode + d - 3;
        end if;
    end;

    ---------------------------------------------------------------------------

    subtype bx_range is integer range 11 downto 8;
    subtype by_range is integer range 7 downto 4;
    subtype bz_range is integer range 3 downto 0;

    function decompose(node : node_t) return coord_t is
    begin
        return (conv_integer(node(bx_range)),
                conv_integer(node(by_range)),
                conv_integer(node(bz_range)));
    end;

    function compose(c : coord_t) return node_t is
        variable node : node_t;

        function conv2(i : integer) return std_logic_vector is
        begin
            return conv_std_logic_vector(i, 4);
        end;
    begin
        node(bx_range) := conv2(c(x));
        node(by_range) := conv2(c(y));
        node(bz_range) := conv2(c(z));

        return node;
    end;

    function mk_dirbits(size3 : integer_3vector; curr, dest : coord_t) return dirbits_t is
        -- determines where to move along the given dimension
        type ringbits_t is record
            pos, neg : std_logic;
        end record;

        function ringbits(curr, dest : dimension_range; size : integer)
            return ringbits_t
        is
            constant half : dimension_range := size/2;

            variable pos, neg : boolean;
        begin
            if curr < half then
                pos := curr < dest and dest <= curr + half;
                neg := not pos and curr /= dest;
            else
                neg := curr - half <= dest and dest < curr;
                pos := not neg and curr /= dest;
            end if;

            return (to_stdl(pos), to_stdl(neg));
        end;

        variable result : dirbits_t;

        procedure set_ringbits(d : dims3_t) is
            constant pn : ringbits_t := ringbits(curr(d),
                                                 dest(d),
                                                 size3(d));
        begin
            -- NB: result's indices are determined by the meaning of
            -- dirbits_t's bits
            result(5 - dims3_t'pos(d)) := pn.pos;
            result(2 - dims3_t'pos(d)) := pn.neg;
        end;
        
    begin
        for d in dims3_t loop
            set_ringbits(d);
        end loop;

        return result;
    end;

    ---------------------------------------------------------------------------

--    function sanity_check return boolean is
--    begin
--        assert
--            configure.nNodes = size3(x) * size3(y) * size3(z);
--        report "Value of configure.nNodes is invalid";

--        assert
--            size3(x) < 16 and size3(y) < 16 and size3(z) < 16;
--        report "Torus sizes are too high; see node_t definition";

--        return true;
--    end;

--    constant is_sane : boolean := sanity_check;

end t3d_topology;

