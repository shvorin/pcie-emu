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
use work.tlp_package.all;
use work.rld.all;
use work.credit.all;
use work.configure;
use work.cc_dbg_ilink;


entity core_passthru is
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
        ej_ready_all  : in  boolean_array(valid_portId_range);

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
end core_passthru;

architecture passthru of core_passthru is
    -- 0 <-> 1, 2 <-> 3, 4 <-> 5, and so on
    function opposite(p : valid_portId_range) return valid_portId_range is
    begin
        assert configure.valid_nPorts mod 2 = 0;

        if p mod 2 = 0 then
            return p + 1;
        else
            return p - 1;
        end if;
    end;

    function map_injector(p : valid_portId_range) return valid_portId_range is
    begin
        if p mod 2 = 0 then
            return p + 1;
        else
            return p - 1;
        end if;
    end;

    function map_ejector(p : valid_portId_range) return valid_portId_range is
    begin
        return p;
    end;

    ---------------------------------------------------------------------------

    type data_all is array(valid_portId_range) of data_t;
    signal raw_data_i_all, raw_data_o_all : data_all;

    subtype stdl_all is std_logic_vector(valid_portId_range);
    signal raw_dv_i_all, raw_dv_o_all, raw_ready_i_all, raw_ready_o_all : stdl_all;

    signal phy_wrreq_all, phy_wrfull_all, phy_rdempty_all, phy_rdreq_all : stdl_all;

    ---------------------------------------------------------------------------

    signal vdata_olink, vdata_ilink : vflit_vector(valid_portId_range);
    signal ready_olink              : boolean_array(valid_portId_range);

    type credit_all is array(valid_portId_range) of credit_t;
    signal credit_ilink, credit_olink : credit_all;

    signal o_rld_ilink, o_rld_ivc : o_rld_array(0 to 5);
    
begin

    passthru : for p in valid_portId_range generate
        ovc : block
            port (
                rxcredit : in  credit_t;
                --
                vdata_i  : in  vflit_t;
                ready_i  : out boolean;
                --
                vdata_o  : out vflit_t;
                ready_o  : in  boolean);

            port map (
                rxcredit => credit_ilink(opposite(p)),
                --
                vdata_i  => inj_vdata_all(map_injector(p)),
                ready_i  => inj_ready_all(map_injector(p)),
                --
                vdata_o  => vdata_olink(p),
                ready_o  => ready_olink(p));

            signal sop : boolean;

            -- NB: measured in packets, not flits!
            signal pkt_tx, pkt_size : credit_t;

            signal has_bubble : boolean;

            function pkt_space(n : integer) return integer is
            begin
                return configure.ivc_buffer_bubble_capacity - n;
            end;

            signal vdata_1 : vflit_t;

            alias dv_o : boolean is vdata_o.dv;
            alias dv_1 : boolean is vdata_1.dv;

            signal allow, ready_1 : boolean;

        begin
            counter : entity work.net_flit_counter
                port map (
                    clk     => clk,
                    reset   => reset,
                    --
                    vdata_i => vdata_i,
                    ready   => ready_1,
                    --
                    vdata_o => vdata_1,
                    --
                    sop     => sop);

            vdata_o.data <= vdata_1.data;

            dv_o    <= dv_1 and allow;
            ready_i <= ready_1;
            ready_1 <= ready_o and (allow or not dv_1);

            allow <= has_bubble or not sop;

            has_bubble <= pkt_size >= pkt_space(1);

            pkt_tx <= (others => '0') when reset = '1' else
                      pkt_tx + 1 when rising_edge(clk) and sop;  -- FIXME: also check dv and ready (?)

            pkt_size <= pkt_tx - rxcredit;
        end block;

        olink : entity work.olink_adapter
            port map (
                clk        => clk,
                reset      => reset,
                --
                vdata_i    => vdata_olink(p),
                rxcredit_i => credit_olink(p),
                ready_i    => ready_olink(p),
                --
                raw_data   => raw_data_o_all(p),
                raw_dv     => raw_dv_o_all(p),
                ready      => raw_ready_o_all(p));

        -----------------------------------------------------------------------
        
        ilink : entity work.ilink_adapter
            generic map (ID => p - configure.ports_perNode)
            port map (
                clk        => clk,
                reset      => reset,
                --
                vdata_o    => vdata_ilink(p),
                rxcredit_o => credit_ilink(p),
                --
                raw_data   => raw_data_i_all(p),
                raw_dv     => raw_dv_i_all(p),
                ready      => raw_ready_i_all(p),
                --
                i_rld_ctrl => i_rld_ctrl,
                o_rld_ctrl => o_rld_ilink(p - configure.ports_perNode));

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
                rxcredit   => credit_olink(opposite(p)),
                --
                vdata_o    => ej_vdata_all(map_ejector(p)),
                ready_o    => ej_ready_all(map_ejector(p)),
                --
                i_rld_ctrl => i_rld_ctrl,
                o_rld_ctrl => o_rld_ivc(p - configure.ports_perNode));

        -----------------------------------------------------------------------

        link_PHY : if configure.passthru_PHYs(p) generate
            phy : entity work.fifo_phy_fifo
                port map (
                    clk      => clk,
                    reset    => reset,
                    --
                    data     => raw_data_o_all(p),
                    wrreq    => phy_wrreq_all(p),
                    wrfull   => phy_wrfull_all(p),
                    --
                    q        => raw_data_i_all(p),
                    rdempty  => phy_rdempty_all(p),
                    rdreq    => phy_rdreq_all(p),
                    --
                    clkPHY   => clkPHY,
                    -- FIXME: mapping port num to the real PHY num may be needed
                    rstb     => rstb_arr(p),
                    txd      => txd_arr(p),
                    txc      => txc_arr(p),
                    tx_clk   => tx_clk_arr(p),
                    rxd      => rxd_arr(p),
                    rxc      => rxc_arr(p),
                    rxh      => rxh_arr(p),
                    rx_clk   => rx_clk_arr(p),
                    fault_tx => fault_tx_arr(p),
                    fault_rx => fault_rx_arr(p));

            phy_wrreq_all(p)   <= raw_dv_o_all(p) and not phy_wrfull_all(p);
            raw_ready_o_all(p) <= not phy_wrfull_all(p);  -- FIXME: leads to
-- GHDL's "--stop-delta"
            --
            raw_dv_i_all(p)    <= not phy_rdempty_all(p);
            phy_rdreq_all(p)   <= raw_ready_i_all(p)      -- FIXME
                                  and not phy_rdempty_all(p);
        end generate;
        -- else generate
        link_bypass : if not configure.passthru_PHYs(p) generate
            raw_data_i_all(p)  <= raw_data_o_all(p);
            raw_dv_i_all(p)    <= raw_dv_o_all(p);
            raw_ready_o_all(p) <= raw_ready_i_all(p);
        end generate;
        
    end generate;

    dbg : if configure.dbg_buffers generate
        o_rld_ctrl <= rld_mux(o_rld_ilink & o_rld_ivc);
    end generate;
    -- else generate
    not_dbg : if not configure.dbg_buffers generate
        o_rld_ctrl <= nothing;
    end generate;
    
end architecture passthru;
