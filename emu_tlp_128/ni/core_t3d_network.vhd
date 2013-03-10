-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.net_flit.all;
use work.vdata.all;
use work.stdl_matrix.all;
use work.msg_curry.all;
use work.t3d_topology.all;
use work.util.all;
use work.credit.all;
use work.configure;
use work.tlp_package.all;
use work.rld.all;
use work.cclasses.all;
use work.cc_meta.all;
use work.cc_dbg_ilink;
use work.cc_dbg_credit;


entity core_t3d_network is
    generic (
        use_PHYs : boolean);

    port (
        -- 1. inner network
        -----------------------------------------------------------------------
        clk, reset    : in  std_logic;  -- asynchronous reset (active high)
        --
        inj_vdata_all : in  vflit_vector(valid_portId_range);
        inj_ready_all : out boolean_array(valid_portId_range);
        --
        ej_vdata_all  : out vflit_vector(valid_portId_range);
        ej_bubble_all : in  boolean_array(valid_portId_range);

        -- 2. PHYs
        -----------------------------------------------------------------------
        clkPHY : in std_logic;          -- 250 MHz

        rstb_arr   : in  std_logic_vector(0 to 5);
        txd_arr    : out phy_data_t(0 to 5);
        txc_arr    : out phy_lane_t(0 to 5);
        tx_clk_arr : out std_logic_vector(0 to 5);

        rxd_arr    : in phy_data_t(0 to 5);
        rxc_arr    : in phy_lane_t(0 to 5);
        rxh_arr    : in phy_lane_t(0 to 5);
        rx_clk_arr : in std_logic_vector(0 to 5);

        fault_tx_arr : in  std_logic_vector(0 to 5);
        fault_rx_arr : in  std_logic_vector(0 to 5);
        --
        -- RAM-like device iface for control
        --
        i_rld_ctrl   : in  i_rld_t;
        o_rld_ctrl   : out o_rld_t);
end core_t3d_network;


architecture network of core_t3d_network is
    constant size3 : integer_3vector := (configure.xSize, configure.ySize, configure.zSize);

    constant ppn : positive := configure.ports_perNode;

    function stubbed(n : nodeId_range;
                     p : valid_portId_range) return boolean is
    begin
        return ext_portId(n, p) >= configure.valid_nPorts;
    end;

    -- "alld_" -- "for all dirs"
    subtype vdata_alld is vflit_vector(dirId_range);
    subtype boolean_alld is boolean_array(dirId_range);
    subtype bubble_alld is bubble_array(dirId_range);
    subtype credit_alld is credit_array(dirId_range);

    -- "alln_" -- "for all nodes"
    type vdata_alld_alln is array (nodeId_range) of vdata_alld;
    type boolean_alld_alln is array (nodeId_range) of boolean_alld;
    type bubble_alld_alln is array (nodeId_range) of bubble_alld;
    type credit_alld_alln is array (nodeId_range) of credit_alld;

    signal has_bubble_alld_alln                 : boolean_alld_alln;
    signal rxcredit_alld_alln                   : credit_alld_alln;
    signal ready_i_alld_alln                    : boolean_alld_alln;
    signal vdata_i_alld_alln, vdata_o_alld_alln : vdata_alld_alln;

    signal credit_olink : credit_alld_alln;
    signal vdata_ilink  : vdata_alld_alln;

    type data_alllinks is array (nodeId_range, t3d_dirId_range) of data_t;
    signal raw_data_alllinks_i, raw_data_alllinks_o : data_alllinks;
    signal raw_dv_alllinks_i, raw_dv_alllinks_o     : stdl_matrix(nodeId_range, t3d_dirId_range);
    signal ready_alllinks_i, ready_alllinks_o       : stdl_matrix(nodeId_range, t3d_dirId_range);

    -- the following definitions are only for binding vdata <-> gdata
    type gdata_mat_alln is array (nodeId_range) of stdl_matrix(dirId_range, vflit_binary'range);
    signal gdata_o_mat_alln, gdata_i_mat_alln : gdata_mat_alln;

    type stdl_serial is array (-1 to dirId_range'high) of std_logic;

    signal rdempty, wrfull, rdreq           : stdl_serial;
    signal raw_dv_serial_i, raw_dv_serial_o : stdl_serial;
    signal ready_serial_i, ready_serial_o   : stdl_serial;

    type data_serial is array (-1 to dirId_range'high) of data_t;
    signal raw_data_serial_i, raw_data_serial_o : data_serial;


    function nodedir2PHY_i(n : nodeId_range; p : t3d_dirId_range) return integer is
    begin
        return configure.map_nodedir2PHY_i(neighbour(size3, n, p), p - configure.ports_perNode);
    end;

    -- NB: "outputs" are assumed to belong to neighbour node
    function nodedir2PHY_o(n : nodeId_range; p : t3d_dirId_range) return integer is
    begin
        return configure.map_nodedir2PHY_o(n, p - configure.ports_perNode);
    end;

    function with_PHY(n : nodeId_range; p : t3d_dirId_range) return boolean is
    begin
        assert (nodedir2PHY_i(n, p) = -1) = (nodedir2PHY_o(n, p) = -1);
        return nodedir2PHY_i(n, p) /= -1;
    end;


    function mk_valid_PHYs return boolean_alld is
        variable result : boolean_alld := (others => false);
        variable phy    : integer;
    begin
        for n in nodeId_range loop
            for d in t3d_dirId_range loop
                phy := nodedir2PHY_i(n, d);

                if phy /= -1 then
                    result(phy) := true;
                end if;
            end loop;
        end loop;

        return result;
    end;

    constant valid_PHYs : boolean_alld := mk_valid_PHYs;

    signal o_rld_ctrl_router      : o_rld_array(nodeId_range);
    signal o_rld_ilink, o_rld_ivc : o_rld_array(0 to 6 * configure.nNodes - 1);
    signal o_rld_ctrl_0           : o_rld_t;

    function extend64_all(c : credit_alld_alln) return data_array is
        variable result : data_array(0 to nDirs * configure.nNodes - 1);
    begin
        for n in c'range loop
            for p in c(c'low)'range loop
                result(n * nDirs + p) := extend64(c(n)(p));
            end loop;
        end loop;

        return result;
    end;
    
begin
    nodes : for n in nodeId_range generate
        -- 0. instantiate a router
        -----------------------------------------------------------------------
        
        router : entity work.router_iface
            generic map (
                gdata_i_width   => vflit_binary'length,
                gdata_o_width   => vflit_binary'length,
                nIVCs           => nDirs,
                nOVCs           => nDirs,
                default_my_node => compose(deserial(size3, n)))

            port map (
                clk            => clk,
                reset          => reset,
                --
                gdata_i_mat    => gdata_i_mat_alln(n),
                ready_i_all    => ready_i_alld_alln(n),
                --
                gdata_o_mat    => gdata_o_mat_alln(n),
                has_bubble_all => has_bubble_alld_alln(n),
                rxcredit_all   => rxcredit_alld_alln(n),
                --
                i_rld_ctrl     => i_rld_ctrl,
                o_rld_ctrl     => o_rld_ctrl_router(n));

        -- bind vdata <-> gdata
        vdata_o_alld_alln(n) <= map_decompose(gdata_o_mat_alln(n));
        gdata_i_mat_alln(n)  <= map_compose(vdata_i_alld_alln(n));

        -- 1. connect PE dirs
        -----------------------------------------------------------------------

        pe_dirs : for p in pe_dirId_range generate

            -- this PE port must be connected to the appropriate outer port
            efficient : if not stubbed(n, p) generate
                vdata_i_alld_alln(n)(p) <= inj_vdata_all(ext_portId(n, p));

                has_bubble_alld_alln(n)(p) <= ej_bubble_all(ext_portId(n, p));

                ej_vdata_all(ext_portId(n, p))  <= vdata_o_alld_alln(n)(p);
                inj_ready_all(ext_portId(n, p)) <= ready_i_alld_alln(n)(p);
            end generate;

            -- otherwise this PE port must be stubbed
            stub : if stubbed(n, p) generate
                vdata_i_alld_alln(n)(p)    <= invalid_vflit;
                has_bubble_alld_alln(n)(p) <= true;  -- be greedy

            -- unconnected vdata_o_alld_alln(n)(p);
            -- unconnected ready_i_alld_alln(n)(p);
            end generate;

        end generate pe_dirs;

        -- 2. connect t3d dirs (also a FIFO must be instantiated)
        -----------------------------------------------------------------------

        t3d_dirs : for p in t3d_dirId_range generate
            -- connect direction "from this node to that node"

            ivc_buffer : entity work.ivc_buffer
                generic map (
                    ID              => (p - configure.ports_perNode) + n * 6,
                    bubble_capacity => configure.ivc_buffer_bubble_capacity)
                port map (
                    clk        => clk,
                    reset      => reset,
                    --
                    vdata_i    => vdata_ilink(n)(p),
                    --
                    rxcredit   => credit_olink(n)(p),
                    --
                    vdata_o    => vdata_i_alld_alln(n)(p),
                    ready_o    => ready_i_alld_alln(n)(p),
                    --
                    i_rld_ctrl => i_rld_ctrl,
                    o_rld_ctrl => o_rld_ivc((p - configure.ports_perNode) + n * 6));

            ilink : entity work.ilink_adapter
                generic map (ID => (p - configure.ports_perNode) + n * 6)
                
                port map (
                    clk        => clk,
                    reset      => reset,
                    --
                    vdata_o    => vdata_ilink(n)(p),
                    -- NB: opposite dir
                    rxcredit_o => rxcredit_alld_alln(n)(opposite_dir(p)),
                    --
                    raw_data   => raw_data_alllinks_i(n, p),
                    raw_dv     => raw_dv_alllinks_i(n, p),
                    ready      => ready_alllinks_i(n, p),
                    --
                    i_rld_ctrl => i_rld_ctrl,
                    o_rld_ctrl => o_rld_ilink((p - configure.ports_perNode) + n * 6));

            olink : entity work.olink_adapter
                port map (
                    clk        => clk,
                    reset      => reset,
                    --
                    vdata_i    => vdata_o_alld_alln(n)(p),
                    -- NB: opposite dir
                    rxcredit_i => credit_olink(n)(opposite_dir(p)),
                    has_bubble => has_bubble_alld_alln(n)(p),
                    --
                    raw_data   => raw_data_alllinks_o(n, p),
                    raw_dv     => raw_dv_alllinks_o(n, p),
                    ready      => ready_alllinks_o(n, p));


            phy : if with_phy(n, p) generate
                raw_data_alllinks_i(neighbour(size3, n, p), p) <= raw_data_serial_i(nodedir2PHY_i(n, p));
                raw_data_serial_o(nodedir2PHY_o(n, p))         <= raw_data_alllinks_o(n, p);
                --
                raw_dv_alllinks_i(neighbour(size3, n, p), p)   <= raw_dv_serial_i(nodedir2PHY_i(n, p));
                raw_dv_serial_o(nodedir2PHY_o(n, p))           <= raw_dv_alllinks_o(n, p);
                --
                ready_alllinks_o(n, p)                         <= ready_serial_o(nodedir2PHY_o(n, p));
                ready_serial_i(nodedir2PHY_i(n, p))            <= ready_alllinks_i(neighbour(size3, n, p), p);
            end generate;

            -- else generate
            shortcut : if not with_phy(n, p) generate
                raw_data_alllinks_i(neighbour(size3, n, p), p) <= raw_data_alllinks_o(n, p);
                raw_dv_alllinks_i(neighbour(size3, n, p), p)   <= raw_dv_alllinks_o(n, p);
                ready_alllinks_o(n, p)                         <= ready_alllinks_i(neighbour(size3, n, p), p);
            end generate shortcut;
        end generate t3d_dirs;
    end generate nodes;

    phys : for x in dirId_range generate
        valid_PHY : if valid_PHYs(x) generate
            phy : entity work.fifo_phy_fifo
                port map (
                    clk      => clk,
                    reset    => reset,
                    --
                    data     => raw_data_serial_o(x),
                    wrreq    => raw_dv_serial_o(x),
                    wrfull   => wrfull(x),
                    --
                    q        => raw_data_serial_i(x),
                    rdempty  => rdempty(x),
                    rdreq    => rdreq(x),
                    --
                    clkPHY   => clkPHY,
                    rstb     => rstb_arr(x),
                    txd      => txd_arr(x),
                    txc      => txc_arr(x),
                    tx_clk   => tx_clk_arr(x),
                    rxd      => rxd_arr(x),
                    rxc      => rxc_arr(x),
                    rxh      => rxh_arr(x),
                    rx_clk   => rx_clk_arr(x),
                    fault_tx => fault_tx_arr(x),
                    fault_rx => fault_rx_arr(x)
                    );

            ready_serial_o(x)  <= not wrfull(x) or not raw_dv_serial_o(x);
            rdreq(x)           <= ready_serial_i(x) and raw_dv_serial_i(x);
            --
            raw_dv_serial_i(x) <= not rdempty(x);

        end generate valid_PHY;
    end generate phys;

    dbg_ilink : if configure.dbg_buffers generate
        o_rld_ctrl_0 <= rld_mux(o_rld_ctrl_router & o_rld_ilink & o_rld_ivc);
    end generate;
    -- else generate
    not_dbg_ilink : if not configure.dbg_buffers generate
        o_rld_ctrl_0 <= rld_mux(o_rld_ctrl_router);
    end generate;

    dbg_credit : if cc_dbg_credit.enabled generate
        o_rld_ctrl <= rld_mux(o_rld_ctrl_0
                              & cc_dbg_credit.match_consts(offset(f_dbg_credit), i_rld_ctrl)
                              & match(cc_dbg_credit.offset(offset(f_dbg_credit), cc_dbg_credit.f_credit_fresh), i_rld_ctrl, extend64_all(credit_olink))
                              & match(cc_dbg_credit.offset(offset(f_dbg_credit), cc_dbg_credit.f_credit_stale), i_rld_ctrl, extend64_all(rxcredit_alld_alln)));
    end generate;
    -- else generate
    not_dbg_credit : if not cc_dbg_credit.enabled generate
        o_rld_ctrl <= o_rld_ctrl_0;
    end generate;
    
end architecture network;

