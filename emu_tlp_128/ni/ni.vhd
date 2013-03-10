-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.tlp_flit;
use work.msg_flit.all;
use work.net_flit.all;
use work.vdata.all;
use work.util.all;
use work.cclasses.all;
use work.cc_meta.all;
use work.cc_base;
use work.cc_issue;
use work.cc_control;
use work.cc_channels;
use work.cc_skifch2;
use work.cc_portdesc;
use work.cc_t3dnetwork;
use work.cc_t3dnode;
use work.msg_curry.all;
use work.t3d_topology.all;
use work.credit.all;
use work.tlp_package.all;
use work.rld.all;
use work.down;
use work.up;
use work.config;
use work.configure;


entity ni_iface is
    generic (
        use_PHYs : boolean);

    port (
        -- 1. tlp_io iface
        ---------------------------------------------------------------------------
        rx_data   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        rx_dvalid : in  std_logic;
        rx_sop    : in  std_logic;
        rx_eop    : in  std_logic;
        tx_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        tx_dvalid : out std_logic;
        ej_ready  : in  std_logic;
        --
        clk       : in  std_logic;
        reset     : in  std_logic;

        -- 2. PHYs
        ---------------------------------------------------------------------------
        clkPHY : in std_logic;          -- 250 MHz

        rstb_arr   : in  std_logic_vector(0 to 5);
        txd_arr    : out phy_data_t(0 to 5);
        txc_arr    : out phy_lane_t(0 to 5);
        tx_clk_arr : out std_logic_vector(0 to 5);

        rxd_arr    : in phy_data_t(0 to 5);
        rxc_arr    : in phy_lane_t(0 to 5);
        rxh_arr    : in phy_lane_t(0 to 5);
        rx_clk_arr : in std_logic_vector(0 to 5);

        fault_tx_arr : in std_logic_vector(0 to 5);
        fault_rx_arr : in std_logic_vector(0 to 5));
end entity ni_iface;

architecture ni of ni_iface is
    signal i_tlp_root : i_tlp_t;
    signal o_tlp_root : o_tlp_t;
    signal i_tlp_chld : i_tlp_array(0 to 2);
    signal o_tlp_chld : o_tlp_array(0 to 2);

    signal reset1 : std_logic;

    signal ready_ej_data       : boolean;
    signal arbiter_fpga_rx_ena : std_logic;
    signal ej_ready_bool       : boolean;

    signal fpga_re          : std_logic;
    signal head_we, body_we : boolean;
    signal dram_rx_we       : boolean;

    ---------------------------------------------------------------------------
    -- multichannel

    subtype boolean_bus is boolean_array(valid_portId_range);

    signal head_we_dmx, body_we_dmx : boolean_bus;

    signal vdata_dram_rx_dmx : vflit_vector(valid_portId_range);

    signal reqs_fpga_rx, acks_fpga_rx : std_logic_vector(valid_portId_range);
    signal dv_fpga_rx                 : boolean;
    signal sending_rx, sending_rx_ff  : boolean;

    signal pre_net_eop_mux      : boolean_bus;
    signal pre_net_eop, net_eop : boolean;

    ---------------------------------------------------------------------------
    subtype double_vpi_range is integer range 0 to 2 * configure.valid_nPorts - 1;
    subtype ej_vpi_range is valid_portId_range;
    subtype inj_vpi_range is integer range ej_vpi_range'high + 1 to double_vpi_range'high;
    --
    signal pre_tx_vdata_mux    : vflit_vector(double_vpi_range);
    signal reqs, acks          : std_logic_vector(double_vpi_range);
    --
    alias reqs_ej              : std_logic_vector(valid_portId_range) is reqs(ej_vpi_range);
    alias acks_ej              : std_logic_vector(valid_portId_range) is acks(ej_vpi_range);
    alias pre_tx_vdata_mux_ej  : vflit_vector(valid_portId_range) is pre_tx_vdata_mux(ej_vpi_range);
    --
    alias reqs_inj             : std_logic_vector(valid_portId_range) is reqs(inj_vpi_range);
    alias acks_inj             : std_logic_vector(valid_portId_range) is acks(inj_vpi_range);
    alias pre_tx_vdata_mux_inj : vflit_vector(valid_portId_range) is pre_tx_vdata_mux(inj_vpi_range);

    signal tx_tlp_eop, tx_isIdle : boolean;

    signal rx_dv : boolean;

    ---------------------------------------------------------------------------
    -- mux
    
    function fmux(sel    : std_logic_vector;
                  inputs : vflit_vector) return vflit_t
    is
        variable result : vflit_t := ((others => 'X'), false);
    begin
        for i in sel'range loop
            if sel(i) = '1' then
                result := inputs(i);
            end if;
        end loop;

        return result;
    end;

    function fmux(sel    : std_logic_vector;
                  inputs : boolean_bus) return boolean
    is
        variable result : boolean := false;
    begin
        for i in sel'range loop
            if sel(i) = '1' then
                result := inputs(i);
            end if;
        end loop;

        return result;
    end;

    signal rfifo_nempty : boolean;
    signal rfifo_ena    : boolean;
    signal tx_vdata     : vflit_t;
    signal pre_tx_vdata : vflit_t;

    signal sufficient_bubble : boolean;

    ---------------------------------------------------------------------------
    -- inner network

    signal inj_vdata_all, ej_vdata_all : vflit_vector(valid_portId_range);
    signal inj_ready_all               : boolean_bus;
    signal ej_bubble_all               : boolean_array(valid_portId_range);
    signal ej_ready_all                : boolean_bus;

    ---------------------------------------------------------------------------
    -- ???

    type switch_state_t is (Run, WaitTxEop, DoReset);

    function next_sstate(sstate     : switch_state_t;
                         reset_cmd,
                         tx_isIdle,
                         tx_tlp_eop : boolean) return switch_state_t
    is
    begin
        case sstate is
            when Run =>
                if reset_cmd then
                    if tx_isIdle or tx_tlp_eop then
                        return DoReset;
                    else
                        return WaitTxEop;
                    end if;
                end if;

                if tx_isIdle or tx_tlp_eop then
                    return Run;
                end if;
                
            when WaitTxEop =>
                if tx_isIdle or tx_tlp_eop then
                    return DoReset;
                end if;

            when DoReset =>
                return Run;
                
        end case;

        return sstate;
    end;

    signal sstate, sstate_ff : switch_state_t;

    ---------------------------------------------------------------------------
    -- tlp2rld stuff

    signal wreq_rx_dv      : boolean;
    signal wreq_rx_tlpaddr : rx_tlpaddr_t;

    signal i_rld_main : i_rld_t;
    signal o_rld_main : o_rld_t;

    signal i_rld_ctrl : i_rld_t;
    signal o_rld_ctrl : o_rld_t;

    constant ctrl_bar_logsize : integer := config.bar_size_mask(2);

    signal o_rld_ctrl_ej, o_rld_ctrl_inj : o_rld_array(valid_portId_range);
    signal o_rld_ctrl_mode               : o_rld_t;
    signal o_rld_ctrl_t3dnetwork         : o_rld_t;

    ---------------------------------------------------------------------------

    signal conv_sstate : data_t;

    -- TODO: use only one access_sstate
    signal access_sstate, access_sstate0 : boolean;

    function conv(state : switch_state_t) return data_t is
    begin
        return conv_std_logic_vector(switch_state_t'pos(state), 64);
    end;

begin  -- architecture tlp_io_msg

    -- 0. user's reset
    ---------------------------------------------------------------------------

    sstate_ff <= Run when reset = '1' else sstate when rising_edge(clk);
    sstate <= next_sstate(sstate_ff,
                          access_sstate or access_sstate0,
                          tx_isIdle, tx_tlp_eop);

    
    reset1 <= reset or to_stdl(sstate_ff = DoReset);

    -- 1. receiving
    ---------------------------------------------------------------------------

    dram_rx_we <= wreq_rx_tlpaddr.kind = Rx and wreq_rx_dv;
    head_we    <= wreq_rx_tlpaddr.kind = CHead and wreq_rx_dv;
    body_we    <= wreq_rx_tlpaddr.kind = CBody and wreq_rx_dv;

    rx_dv <= i_tlp_chld(0).rx_dvalid = '1';

    -- injection queues
    injectors : for n in valid_portId_range generate
        head_we_dmx(n) <= head_we and wreq_rx_tlpaddr.portId = n;
        body_we_dmx(n) <= body_we and wreq_rx_tlpaddr.portId = n;

        msg_injector : entity work.msg_injector
            generic map (
                portId   => n,
                dbg_base => 1000 + 10*n)

            port map (
                clk           => clk,
                reset         => reset1,
                --
                di            => i_tlp_chld(0).rx_data,
                foffset       => wreq_rx_tlpaddr.foffset,
                head_we       => head_we_dmx(n),
                body_we       => body_we_dmx(n),
                --
                vdata_o       => inj_vdata_all(n),
                ready_o       => inj_ready_all(n),
                --
                vdata_fpga_rx => pre_tx_vdata_mux_inj(n),
                req_fpga_rx   => reqs_inj(n),
                ack_fpga_rx   => acks_inj(n),
                --
                i_rld_ctrl    => i_rld_ctrl,
                o_rld_ctrl    => o_rld_ctrl_inj(n));
    end generate;

    -- 1.5. inner network
    ---------------------------------------------------------------------------

    shortcut : if configure.eq(configure.network_selected, configure.shortcut) generate
        -- i-th port directed to (i+1)-th modulo valid_nPorts
        shortcut : for i in valid_portId_range generate
            ej_vdata_all((i+1) mod configure.valid_nPorts) <= inj_vdata_all(i);

            inj_ready_all(i) <= ej_ready_all((i+1) mod configure.valid_nPorts);
        end generate;
    end generate;
    -- else if generate
    passthru : if configure.eq(configure.network_selected, configure.passthru) generate
        passthru : entity work.core_passthru
            generic map (use_PHYs)
            
            port map (
                clk           => clk,
                reset         => reset1,
                --
                inj_vdata_all => inj_vdata_all,
                inj_ready_all => inj_ready_all,
                --
                ej_vdata_all  => ej_vdata_all,
                ej_ready_all  => ej_ready_all,

                ------------------------------------------

                clkPHY => clkPHY,

                rstb_arr => rstb_arr,

                txd_arr    => txd_arr,
                txc_arr    => txc_arr,
                tx_clk_arr => tx_clk_arr,

                rxd_arr    => rxd_arr,
                rxc_arr    => rxc_arr,
                rxh_arr    => rxh_arr,
                rx_clk_arr => rx_clk_arr,

                fault_tx_arr => fault_tx_arr,
                fault_rx_arr => fault_rx_arr,

                ---------------------------------------------------------------

                i_rld_ctrl => i_rld_ctrl,
                o_rld_ctrl => o_rld_ctrl_mode);
    end generate;
    -- else if generate
    t3d_network : if configure.eq(configure.network_selected, configure.t3d_network) generate
        network : entity work.core_t3d_network
            generic map (use_PHYs)
            
            port map (
                clk           => clk,
                reset         => reset1,
                --
                inj_vdata_all => inj_vdata_all,
                inj_ready_all => inj_ready_all,
                --
                ej_vdata_all  => ej_vdata_all,
                ej_bubble_all => ej_bubble_all,

                ------------------------------------------

                clkPHY => clkPHY,

                rstb_arr => rstb_arr,

                txd_arr    => txd_arr,
                txc_arr    => txc_arr,
                tx_clk_arr => tx_clk_arr,

                rxd_arr    => rxd_arr,
                rxc_arr    => rxc_arr,
                rxh_arr    => rxh_arr,
                rx_clk_arr => rx_clk_arr,

                fault_tx_arr => fault_tx_arr,
                fault_rx_arr => fault_rx_arr,

                ---------------------------------------------------------------

                i_rld_ctrl => i_rld_ctrl,
                o_rld_ctrl => o_rld_ctrl_mode);
    end generate;
    -- else if generate
    t3d_node : if configure.eq(configure.network_selected, configure.t3d_node) generate
        node : entity work.core_t3d_node
            generic map (use_PHYs)
            
            port map (
                clk           => clk,
                reset         => reset1,
                --
                inj_vdata_all => inj_vdata_all,
                inj_ready_all => inj_ready_all,
                --
                ej_vdata_all  => ej_vdata_all,
                ej_bubble_all => ej_bubble_all,

                ------------------------------------------

                clkPHY => clkPHY,

                rstb_arr => rstb_arr,

                txd_arr    => txd_arr,
                txc_arr    => txc_arr,
                tx_clk_arr => tx_clk_arr,

                rxd_arr    => rxd_arr,
                rxc_arr    => rxc_arr,
                rxh_arr    => rxh_arr,
                rx_clk_arr => rx_clk_arr,

                fault_tx_arr => fault_tx_arr,
                fault_rx_arr => fault_rx_arr,

                ---------------------------------------------------------------

                i_rld_ctrl => i_rld_ctrl,
                o_rld_ctrl => o_rld_ctrl_mode);
    end generate;
    -- 2. output queues
    ---------------------------------------------------------------------------

    ejectors : for n in valid_portId_range generate
        vdata_dram_rx_dmx(n) <= (i_tlp_chld(0).rx_data, dram_rx_we and wreq_rx_tlpaddr.portId = n);

        msg_ejector : entity work.msg_ejector
            generic map (
                portId   => n,
                dbg_base => 2000 + 10*n)

            port map (
                clk           => clk,
                reset         => reset1,
                --
                vdata_i       => ej_vdata_all(n),
                has_bubble    => ej_bubble_all(n),
                ready_i       => ej_ready_all(n),
                --
                vdata_o       => pre_tx_vdata_mux_ej(n),
                --
                vdata_dram_rx => vdata_dram_rx_dmx(n),
                --
                req           => reqs_ej(n),
                ack           => acks_ej(n),
                --
                i_rld_ctrl    => i_rld_ctrl,
                o_rld_ctrl    => o_rld_ctrl_ej(n));
    end generate;

    -- 3. sending
    ---------------------------------------------------------------------------

    arbiter : entity work.arbiter
        generic map (
            NCOMPETITORS => 2 * configure.valid_nPorts)

        port map (
            clk   => clk,
            reset => reset,
            --
            ena   => to_stdl(rfifo_ena),
            --
            req   => reqs,
            ack   => acks);

    rfifo : entity work.rfifo
        generic map (capacity    => configure.max_pktlen * 4,
                     data_width  => data_t'length,
                     bubble_size => configure.max_pktlen
                                        -- NB: the bubble size must include TLP headers and dram_tx packet
                     + (configure.max_pktlen/configure.max_tlplen) + 1 + 2)

        port map (
            clk          => clk,
            reset        => reset1,
            --
            data_i       => pre_tx_vdata.data,
            dv_i         => pre_tx_vdata.dv,
            ready_i      => open,
            ready_bubble => sufficient_bubble,
            --
            data_o       => tx_vdata.data,
            dv_o         => rfifo_nempty,
            ready_o      => ej_ready_bool);

    rfifo_ena <= sufficient_bubble and sstate_ff = Run;

    tx_vdata.dv   <= rfifo_nempty;
    ej_ready_bool <= i_tlp_chld(0).ej_ready = '1';

    pre_tx_vdata <= fmux(acks, pre_tx_vdata_mux);

    o_tlp_chld(0).tx_data   <= tx_vdata.data;
    o_tlp_chld(0).tx_dvalid <= to_stdl(tx_vdata.dv);

    tx_tlp_counter : block
        port (
            clk, reset  : in  std_logic;
            vdata       : in  vflit_t;
            ready       : in  boolean;
            eop, isIdle : out boolean);

        port map (clk, reset, tx_vdata, ej_ready_bool, tx_tlp_eop, tx_isIdle);

        type state_t is (Idle, Run);

        type fstate_t is record
            state : state_t;
            count : tlp_flit.len_range;  -- countdown
        end record;

        constant idle_fstate : fstate_t := (Idle, 0);
        
        function next_state(fstate : fstate_t;
                            dv     : boolean;
                            len    : tlp_flit.len_range) return fstate_t
        is
            constant new_packet : fstate_t := (Run, len);
        begin
            if fstate.state = Idle or fstate.count = 0 then
                if dv then
                    return new_packet;
                else
                    return idle_fstate;
                end if;
            else
                if dv then
                    return (Run, fstate.count - 1);
                else
                    return fstate;
                end if;
            end if;
        end;

        signal ena                      : boolean;
        signal fstate_curr, fstate_next : fstate_t;
    begin
        ena <= vdata.dv and ready;

        fstate_next <= next_state(fstate_curr, ena, tlp_flit.decompose(vdata.data).len);
        fstate_curr <= idle_fstate when reset = '1' else
                       fstate_next when rising_edge(clk);

        eop    <= fstate_next.count = 0 and fstate_next.state /= Idle and ena;
        isIdle <= fstate_next.state = Idle;
    end block;

    -- forks into 3 entities: 2 for main BAR and 1 for ctrl BAR
    ---------------------------------------------------------------------------

    tlp_switch : entity work.tlp_switch
        generic map (
            CHANNEL_NUM => 3)

        port map (
            clk        => clk,
            reset      => reset,
            --
            i_tlp_root => i_tlp_root,
            o_tlp_root => o_tlp_root,
            --
            i_tlp_chld => i_tlp_chld,
            o_tlp_chld => o_tlp_chld);

    (tx_data, tx_dvalid) <= o_tlp_root;
    i_tlp_root           <= (rx_data, rx_dvalid, rx_sop, rx_eop, ej_ready);

    -- main BAR as RAM-like device
    ---------------------------------------------------------------------------

    tlp2rld_main : entity work.tlp2rld
        generic map (
            BAR_NUM => 0)

        port map (
            clk   => clk,
            reset => reset,
            --
            i_tlp => i_tlp_chld(1),
            o_tlp => o_tlp_chld(1),
            --
            i_rld => i_rld_main,
            o_rld => o_rld_main);

    wreq_rx_tlpaddr <= decompose_addr(i_rld_main.wr_addr);
    wreq_rx_dv      <= i_rld_main.we = '1';

    -- reading from main BAR is meaningless
    o_rld_main <= (x"DEADBEEF00000000", true);

    -- ctrl BAR as RAM-like device
    ---------------------------------------------------------------------------

    tlp2rld_ctrl : entity work.tlp2rld
        generic map (
            BAR_NUM    => 2,
            READ_DELAY => 0)

        port map (
            clk   => clk,
            reset => reset,
            --
            i_tlp => i_tlp_chld(2),
            o_tlp => o_tlp_chld(2),
            --
            i_rld => i_rld_ctrl,
            o_rld => o_rld_ctrl);

    ---------------------------------------------------------------------------
    -- cc_base

--    o_rld_ctrl <= cc_base.match_consts(offset(f_base), i_rld_ctrl);

    ---------------------------------------------------------------------------
    -- cc_issue, cc_channels, cc_skifch2

--    o_rld_ctrl <= cc_issue.match_consts(offset(f_issue), i_rld_ctrl);
--    o_rld_ctrl <= cc_channels.match_consts(offset(f_channels), i_rld_ctrl);
--    o_rld_ctrl <= cc_skifch2.match_consts(offset(f_skifch2), i_rld_ctrl);

    ---------------------------------------------------------------------------
    -- cc_control
--    o_rld_ctrl <= cc_control.match_consts(offset(f_control), i_rld_ctrl);
--    o_rld_ctrl <= match(cc_control.offset(offset(f_control), cc_control.f_state),
--                        i_rld_ctrl, conv_sstate);

    access_sstate0 <= match(cc_control.offset(offset(f_control),
                                              cc_control.f_state),
                            i_rld_ctrl);

    ---------------------------------------------------------------------------
    -- cc_portdesc
--    o_rld_ctrl <= cc_portdesc.match_consts(offset(f_portdesc),
--    i_rld_ctrl);

    -- TODO: handle *-soft parameters

    ---------------------------------------------------------------------------
    -- cc_t3dnetwork
    t3dnetwork : if cc_t3dnetwork.enabled generate
        o_rld_ctrl_t3dnetwork <= cc_t3dnetwork.match_consts(offset(f_t3dnetwork),
                                                            i_rld_ctrl);
    end generate;
    -- else generate
    not_t3dnetwork : if not cc_t3dnetwork.enabled generate
        o_rld_ctrl_t3dnetwork <= nothing;
    end generate;

    ---------------------------------------------------------------------------
    -- end of class stream marker
--    o_rld_ctrl <= match(length, i_rld_ctrl, zero0);

    o_rld_ctrl <= rld_mux(o_rld_ctrl_ej
                          & o_rld_ctrl_inj
                          & cc_base.match_consts(offset(f_base), i_rld_ctrl)
                          & cc_issue.match_consts(offset(f_issue), i_rld_ctrl)
                          & cc_channels.match_consts(offset(f_channels), i_rld_ctrl)
                          & cc_skifch2.match_consts(offset(f_skifch2), i_rld_ctrl)
                          & cc_control.match_consts(offset(f_control), i_rld_ctrl)
                          & match(cc_control.offset(offset(f_control), cc_control.f_state), i_rld_ctrl, conv_sstate)
                          & cc_portdesc.match_consts(offset(f_portdesc), i_rld_ctrl)
                          & o_rld_ctrl_mode
                          & o_rld_ctrl_t3dnetwork
                          & match(length, i_rld_ctrl, zero0)
                          );


end architecture ni;
