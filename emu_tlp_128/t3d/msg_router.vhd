-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.vdata.all;
use work.msg_curry.all;
use work.util.all;
use work.rld.all;
use work.flit.all;
use work.net_flit.all;
use work.t3d_topology.all;
use work.cclasses.all;
use work.cc_meta.all;
use work.cc_t3dnode;
use work.cc_t3dnetwork;
use work.configure;


architecture msg_router of router_iface is
    subtype i_range is integer range 0 to nIVCs - 1;
    subtype o_range is integer range 0 to nOVCs - 1;

    type stdl_i_vector2d is array (i_range) of stdl_vector(o_range);
    type stdl_o_vector2d is array (o_range) of stdl_vector(i_range);

    subtype stdl_i_vector is std_logic_vector(i_range);

    subtype vflit_i_vector is vflit_vector(i_range);
    subtype vflit_o_vector is vflit_vector(o_range);

    signal reqs_i_all             : stdl_i_vector2d;
    signal reqs_o_all, acks_o_all : stdl_o_vector2d;
    signal ack_i_all              : stdl_i_vector;

    signal vdata_i_all, vdata_inner_all : vflit_i_vector;
    signal vdata_o_all                  : vflit_o_vector;

    ---------------------------------------------------------------------------

    -- used to map reqs
    function transpose(vec2 : stdl_i_vector2d) return stdl_o_vector2d is
        variable result : stdl_o_vector2d;
        
    begin
        for i in i_range loop
            for o in o_range loop
                result(o)(i) := vec2(i)(o);
            end loop;
        end loop;

        return result;
    end;

    -- used to map acks
    function or_reduce_transpose(vec2 : stdl_o_vector2d) return stdl_i_vector is
        variable result : stdl_i_vector;
        
    begin
        for i in i_range loop
            result(i) := '0';

            for o in o_range loop
                result(i) := result(i) or vec2(o)(i);
            end loop;
        end loop;

        return result;
    end;

    ---------------------------------------------------------------------------

    function sanity_check return boolean is
    begin
        assert
            vflit_binary'length = gdata_i_width
            and vflit_binary'length = gdata_o_width
            report "This router architecture has fixed data widths";

        return true;
    end;

    constant is_sane : boolean := sanity_check;

    ---------------------------------------------------------------------------

    signal my_node_we : boolean;
    signal my_node    : node_t;

    signal size3_we : boolean;
    signal size3    : integer_3vector;  -- FIXME: type

    function unwrap64(d : data_t) return integer_3vector is
    begin
        return (conv_integer(d(7 downto 0)), conv_integer(d(15 downto 8)), conv_integer(d(23 downto 16)));
    end;

    function wrap64(v : integer_3vector) return data_t is
        variable result : data_t := (others => '0');
    begin
        result(7 downto 0)   := conv_std_logic_vector(v(x), 8);
        result(15 downto 8)  := conv_std_logic_vector(v(y), 8);
        result(23 downto 16) := conv_std_logic_vector(v(z), 8);

        return result;
    end;

    -- FIXME: func names

    function unwrap64_n(d : data_t) return node_t is
        constant v : integer_3vector := unwrap64(d);
        constant c : coord_t         := (v(x), v(y), v(z));
    begin
        return compose(c);
    end;

    function wrap64_n(n : node_t) return data_t is
        constant c : coord_t         := decompose(n);
        constant v : integer_3vector := (c(x), c(y), c(z));
    begin
        return wrap64(v);
    end;
    
begin

    gdata_o_mat <= map_compose(vdata_o_all);
    vdata_i_all <= map_decompose(gdata_i_mat);

    inputs : for n in i_range generate
        ivc : entity work.msg_ivc
            generic map (
                nOVCs    => nOVCs,
                my_ivcId => n)

            port map (
                clk     => clk,
                reset   => reset,
                --
                my_node => my_node,
                size3   => size3,
                --
                vdata_i => vdata_i_all(n),
                ready_i => ready_i_all(n),
                --
                vdata_o => vdata_inner_all(n),
                --
                reqs    => reqs_i_all(n),
                ack     => ack_i_all(n));
    end generate;

    outputs : for n in o_range generate
        ovc : entity work.msg_ovc
            generic map (
                nIVCs    => nIVCs,
                my_ovcId => n)

            port map (
                clk         => clk,
                reset       => reset,
                --
                has_bubble  => has_bubble_all(n),
                rxcredit    => rxcredit_all(n),
                --
                reqs        => reqs_o_all(n),
                acks        => acks_o_all(n),
                --
                vdata_i_all => vdata_inner_all,
                vdata_o     => vdata_o_all(n));
    end generate;


    ---------------------------------------------------------------------------
    -- inner control network mappings
    ack_i_all  <= or_reduce_transpose(acks_o_all);
    reqs_o_all <= transpose(reqs_i_all);

    ---------------------------------------------------------------------------

    t3dnode : if cc_t3dnode.enabled generate
        my_node <= unwrap64_n(i_rld_ctrl.wr_data) when rising_edge(clk) and my_node_we;
        size3   <= unwrap64(i_rld_ctrl.wr_data)   when rising_edge(clk) and size3_we;

        my_node_we <= match(cc_t3dnode.offset(offset(f_t3dnode), cc_t3dnode.f_myNode),
                            i_rld_ctrl);

        size3_we <= match(cc_t3dnode.offset(offset(f_t3dnode), cc_t3dnode.f_size3),
                          i_rld_ctrl);

        o_rld_ctrl <= rld_mux(
            cc_t3dnode.match_consts(offset(f_t3dnode), i_rld_ctrl)
            & match(cc_t3dnode.offset(offset(f_t3dnode), cc_t3dnode.f_myNode), i_rld_ctrl, wrap64_n(my_node))
            & match(cc_t3dnode.offset(offset(f_t3dnode), cc_t3dnode.f_size3), i_rld_ctrl, wrap64(size3)));

    end generate;
    -- else generate
    not_t3dnode : if not cc_t3dnode.enabled generate
        -- as constants
        my_node <= default_my_node;
        size3   <= (configure.xSize, configure.ySize, configure.zSize);

        my_node_we <= false;
        size3_we   <= false;

        o_rld_ctrl <=
            match(cc_t3dnetwork.offset(offset(f_t3dnetwork), cc_t3dnetwork.f_size3), i_rld_ctrl, wrap64(size3));
    end generate;

end msg_router;
