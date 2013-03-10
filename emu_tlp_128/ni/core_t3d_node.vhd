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
use work.cc_dbg_t3dnode;
use work.cc_dbg_ilink;
use work.cc_dbg_credit;


entity core_t3d_node is
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
end core_t3d_node;


architecture node of core_t3d_node is
    constant ppn : integer := configure.ports_perNode;

    -- "alld_" -- "for all dirs"
    subtype vdata_alld is vflit_vector(dirId_range);
    subtype boolean_alld is boolean_array(dirId_range);
    subtype bubble_alld is bubble_array(dirId_range);
    subtype credit_alld is credit_array(dirId_range);

    -- the following definitions are only for binding vdata <-> gdata
    signal gdata_o_mat, gdata_i_mat : stdl_matrix(dirId_range, vflit_binary'range);

    signal vdata_i_alld, vdata_o_alld : vdata_alld;
    signal ready_i_alld               : boolean_alld;
    signal has_bubble_alld            : boolean_alld;
    signal rxcredit_alld              : credit_alld;

    signal vdata_ilink  : vdata_alld;
    signal credit_olink : credit_alld;

    type data_allt3d is array (t3d_dirId_range) of data_t;
    --
    signal raw_data_i_allt3d, raw_data_o_allt3d : data_allt3d;

    subtype stdl_allt3d is stdl_vector(t3d_dirId_range);
    --
    signal raw_dv_i_allt3d, raw_dv_o_allt3d                        : stdl_allt3d;
    signal ready_i_allt3d, ready_o_allt3d                          : stdl_allt3d;
    --
    signal phy_wrfull_allt3d, phy_rdempty_allt3d, phy_rdreq_allt3d : stdl_allt3d;


    signal phy_wrreq_allt3d                     : stdl_allt3d;
    signal phy_data_i_allt3d, phy_data_o_allt3d : data_allt3d;

    function with_pe(p : valid_portId_range) return boolean is
    begin
        return p < configure.ports_perNode;
    end;

    function dir2PHY(p : t3d_dirId_range) return integer is
    begin
        return configure.map_dir2PHY(p - configure.ports_perNode);
    end;

    function with_phy(p : t3d_dirId_range) return boolean is
    begin
        return dir2PHY(p) /= -1;
    end;

    signal activity : data_array(dirId_range);

    signal o_rld_ctrl_router, o_rld_ctrl_0, o_rld_ctrl_1 : o_rld_t;
    signal o_rld_ilink, o_rld_ivc                        : o_rld_array(0 to 5);

    function extend64_all(c : credit_alld) return data_array is
        variable result : data_array(0 to nDirs - 1);
    begin
        for p in c'range loop
            result(p) := extend64(c(p));
        end loop;

        return result;
    end;
    
begin
    -- 0. instantiate a router
    -----------------------------------------------------------------------
    
    router : entity work.router_iface
        generic map (
            gdata_i_width   => vflit_binary'length,
            gdata_o_width   => vflit_binary'length,
            nIVCs           => nDirs,
            nOVCs           => nDirs,
            default_my_node => (others => '0'))

        port map (
            clk            => clk,
            reset          => reset,
            --
            gdata_i_mat    => gdata_i_mat,
            ready_i_all    => ready_i_alld,
            --
            gdata_o_mat    => gdata_o_mat,
            has_bubble_all => has_bubble_alld,
            rxcredit_all   => rxcredit_alld,
            --
            i_rld_ctrl     => i_rld_ctrl,
            o_rld_ctrl     => o_rld_ctrl_router);

    -- bind vdata <-> gdata
    vdata_o_alld <= map_decompose(gdata_o_mat);
    gdata_i_mat  <= map_compose(vdata_i_alld);

    -- 1. connect PE dirs
    -----------------------------------------------------------------------

    pe_dirs : for p in pe_dirId_range generate

        -- this PE port must be connected to the appropriate outer port
        pe_connected : if with_pe(p) generate
            vdata_i_alld(p) <= inj_vdata_all(p);

            has_bubble_alld(p) <= ej_bubble_all(p);

            ej_vdata_all(p)  <= vdata_o_alld(p);
            inj_ready_all(p) <= ready_i_alld(p);
        end generate pe_connected;
        -- else generate
        not_connected : if not with_pe(p) generate
            vdata_i_alld(p)    <= invalid_vflit;
            has_bubble_alld(p) <= true;  -- be greedy

        -- unconnected vdata_o_alld(p);
        -- unconnected ready_i_alld(p);
        end generate not_connected;

    end generate pe_dirs;

    -- 2. connect t3d dirs (also a FIFO must be instantiated)
    -----------------------------------------------------------------------

    t3d_dirs : for p in t3d_dirId_range generate
        -- connect direction "from this node to that node"

        ivc_buffer : entity work.ivc_buffer
            generic map (
                ID              => p - configure.ports_perNode,
                bubble_capacity => configure.ivc_buffer_bubble_capacity)
            port map (
                clk        => clk,
                reset      => reset,
                --
                vdata_i    => vdata_ilink(p),
                --
                rxcredit   => credit_olink(p),
                --
                vdata_o    => vdata_i_alld(p),
                ready_o    => ready_i_alld(p),
                --
                i_rld_ctrl => i_rld_ctrl,
                o_rld_ctrl => o_rld_ivc(p - configure.ports_perNode));

        ilink : entity work.ilink_adapter
            generic map (ID => p - configure.ports_perNode)
            
            port map (
                clk        => clk,
                reset      => reset,
                --
                vdata_o    => vdata_ilink(p),
                -- NB: opposite dir
                rxcredit_o => rxcredit_alld(opposite_dir(p)),
                --
                raw_data   => raw_data_i_allt3d(p),
                raw_dv     => raw_dv_i_allt3d(p),
                ready      => ready_i_allt3d(p),
                --
                i_rld_ctrl => i_rld_ctrl,
                o_rld_ctrl => o_rld_ilink(p - configure.ports_perNode));

        olink : entity work.olink_adapter
            port map (
                clk        => clk,
                reset      => reset,
                --
                vdata_i    => vdata_o_alld(p),
                -- NB: opposite dir
                rxcredit_i => credit_olink(opposite_dir(p)),
                has_bubble => has_bubble_alld(p),
                --
                raw_data   => raw_data_o_allt3d(p),
                raw_dv     => raw_dv_o_allt3d(p),
                ready      => ready_o_allt3d(p));

        phy_connected : if with_phy(p) generate
            phy : entity work.fifo_phy_fifo
                port map (
                    clk      => clk,
                    reset    => reset,
                    --
                    data     => phy_data_i_allt3d(p),
                    wrreq    => phy_wrreq_allt3d(p),
                    wrfull   => phy_wrfull_allt3d(p),
                    --
                    q        => phy_data_o_allt3d(p),
                    rdempty  => phy_rdempty_allt3d(p),
                    rdreq    => phy_rdreq_allt3d(p),
                    --
                    clkPHY   => clkPHY,
                    rstb     => rstb_arr(dir2PHY(p)),
                    txd      => txd_arr(dir2PHY(p)),
                    txc      => txc_arr(dir2PHY(p)),
                    tx_clk   => tx_clk_arr(dir2PHY(p)),
                    rxd      => rxd_arr(dir2PHY(p)),
                    rxc      => rxc_arr(dir2PHY(p)),
                    rxh      => rxh_arr(dir2PHY(p)),
                    rx_clk   => rx_clk_arr(dir2PHY(p)),
                    fault_tx => fault_tx_arr(dir2PHY(p)),
                    fault_rx => fault_rx_arr(dir2PHY(p)));

            -- fifo_phy input is from the OPPOSITE dir
            phy_data_i_allt3d(p)            <= raw_data_o_allt3d(opposite_dir(p));
            phy_wrreq_allt3d(p)             <= raw_dv_o_allt3d(opposite_dir(p));
            ready_o_allt3d(opposite_dir(p)) <= not phy_wrfull_allt3d(p) or not raw_dv_o_allt3d(p);

            --
            -- fifo_phy output is to the SAME dir
            raw_data_i_allt3d(p) <= phy_data_o_allt3d(p);
            raw_dv_i_allt3d(p)   <= not phy_rdempty_allt3d(p);
            phy_rdreq_allt3d(p)  <= ready_i_allt3d(p)  -- FIXME
                                    and not phy_rdempty_allt3d(p);

        end generate phy_connected;
        -- else generate
        not_connected : if not with_phy(p) generate
            -- disconnected...
            raw_data_i_allt3d(p)            <= (others => 'X');
            raw_dv_i_allt3d(p)              <= '0';
            ready_o_allt3d(opposite_dir(p)) <= '1';  -- be greedy

            -- just in case for easier debugging
            phy_wrreq_allt3d(p)   <= '0';
            phy_rdempty_allt3d(p) <= '1';
            phy_wrfull_allt3d(p)  <= '0';
            phy_rdreq_allt3d(p)   <= '0';
        end generate not_connected;
    end generate t3d_dirs;


    dbg : if cc_dbg_t3dnode.enabled generate
        o_rld_ctrl_0 <= rld_mux(cc_dbg_t3dnode.match_consts(offset(f_dbg_t3dnode), i_rld_ctrl)

                                & match(cc_dbg_t3dnode.offset(offset(f_dbg_t3dnode), cc_dbg_t3dnode.f_activity), i_rld_ctrl, activity)
                                & o_rld_ctrl_router);

        dbg_activity : for p in dirId_range generate
            process (clk, reset)
            begin
                if reset = '1' then
                    activity(p)(2 downto 0) <= (others => '0');
                elsif rising_edge(clk) then
                    if vdata_o_alld(p).dv then
                        activity(p)(0) <= '1';
                    end if;

                    if vdata_i_alld(p).dv then
                        activity(p)(1) <= '1';
                    end if;

                    if vdata_ilink(p).dv then
                        activity(p)(2) <= '1';
                    end if;
                end if;
            end process;

            activity(p)(63 downto 6) <= (others => '0');

        end generate;


        dbg_activity_1 : for p in t3d_dirId_range generate
            process (clk, reset)
            begin
                if reset = '1' then
                    activity(p)(5 downto 3) <= (others => '0');
                elsif rising_edge(clk) then
                    if phy_rdempty_allt3d(p) = '0' then
                        activity(p)(3) <= '1';
                    end if;

                    if phy_rdreq_allt3d(p) = '1' then
                        activity(p)(4) <= '1';
                    end if;

                    if phy_wrreq_allt3d(p) = '1' then
                        activity(p)(5) <= '1';
                    end if;
                end if;
            end process;
        end generate;

    end generate;
    -- else generate
    not_dbg : if not cc_dbg_t3dnode.enabled generate
        o_rld_ctrl_0 <= o_rld_ctrl_router;
    end generate;

    dbg_ilink : if configure.dbg_buffers generate
        o_rld_ctrl_1 <= rld_mux(o_rld_ctrl_0 & o_rld_ilink & o_rld_ivc);
    end generate;
    -- else generate
    not_dbg_ilink : if not configure.dbg_buffers generate
        o_rld_ctrl_1 <= o_rld_ctrl_0;
    end generate;

    dbg_credit : if configure.dbg_buffers generate
        o_rld_ctrl <= rld_mux(o_rld_ctrl_1
                              & cc_dbg_credit.match_consts(offset(f_dbg_credit), i_rld_ctrl)
                              & match(cc_dbg_credit.offset(offset(f_dbg_credit), cc_dbg_credit.f_credit_fresh), i_rld_ctrl, extend64_all(credit_olink))
                              & match(cc_dbg_credit.offset(offset(f_dbg_credit), cc_dbg_credit.f_credit_stale), i_rld_ctrl, extend64_all(rxcredit_alld)));
    end generate;
    -- else generate
    not_dbg_credit : if not configure.dbg_buffers generate
        o_rld_ctrl <= o_rld_ctrl_1;
    end generate;
    
end architecture node;

