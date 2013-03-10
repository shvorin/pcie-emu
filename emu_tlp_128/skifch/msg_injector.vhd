-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.msg_flit.all;
use work.net_flit.all;
use work.vdata.all;
use work.util.all;
use work.down.all;
use work.rld.all;
use work.cclasses.all;
use work.tlp_flit;
use work.configure;


entity msg_injector is
    generic (
        portId   : portId_range;
        dbg_base : integer);

    port (
        clk, reset       : in  std_logic;  -- asynchronous reset (active high)
        --
        -- FPGA FIFO input interface (i.e. RAM iface)
        --
        -- common write addr and di for both cell queue and data queue
        foffset          : in  foffset_t;  -- treated as address
        di               : in  data_t;
        --
        -- selectors for cell queue and data queue
        head_we, body_we : in  boolean;
        --
        -- rfifo output iface
        --
        vdata_o          : out vflit_t;
        ready_o          : in  boolean;
        --
        -- outgoing rx
        --
        vdata_fpga_rx    : out vflit_t;
        req_fpga_rx      : out std_logic;
        ack_fpga_rx      : in  std_logic;
        --
        -- RLD iface for debug
        --
        i_rld_ctrl       : in  i_rld_t;
        o_rld_ctrl       : out o_rld_t);
end msg_injector;


architecture msg_injector of msg_injector is

    -- rx staff for head queue
    signal rx_head_wcell_sent : head_wcptr_t;
    signal rx_head_value      : std_logic_vector(31 - 3 - 3 downto 0);
    alias rx_head_wcell_curr  : head_wcptr_t is rx_head_value(head_wcptr_range);

    -- rx staff for body queue
    signal rx_body_wcell_sent : body_wcptr_t;
    signal rx_body_value      : std_logic_vector(31 - 3 - 3 downto 0);
    alias rx_body_wcell_curr  : body_wcptr_t is rx_body_value(body_wcptr_range);

    signal rx_cond : boolean;


    signal vdata_head, vdata_body : vflit_t;
    signal vdata_2                : vflit_t;
    signal sop, rx_next_cell      : boolean;
    signal net_head               : net_head_t;

    ---------------------------------------------------------------------------
    -- Sending FSM

    type state_t is (Idle, Send_rx0, Send_rx1);

    type next_state_t is record
        state    : state_t;
        sop, eop : boolean;
    end record;

    signal state_curr, state_next : state_t;

    function next_state(state          : state_t;
                        ena            : boolean;
                        arbiter_allows : boolean)
        return next_state_t is
    begin
        case state is
            when Idle =>
                if ena then
                    return (Send_rx0, true, false);
                else
                    return (state, false, false);
                end if;
                
            when Send_rx0 =>
                if arbiter_allows then
                    return (Send_rx1, false, false);
                else
                    return (state, true, false);
                end if;

            when Send_rx1 =>
                return (Idle, false, true);
        end case;
    end;

    signal sop_fpga_rx, eop_fpga_rx, arbiter_allows : boolean;

    constant tx_addr : tx_tlpaddr_t := (kind    => Rx,
                                        portId  => portId,
                                        foffset => (others => 'X'));

    constant tx_tlp : tlp_flit.tlp_head_t := (len      => 1,
                                              read_req => false,
                                              addr     => compose_addr(tx_addr));

    signal head_addr : head_fptr_t;

    subtype addr_low_range is integer range configure.cell_logsize - 1 downto 0;
    subtype head_addr_high_range is integer range head_addr'high downto configure.cell_logsize;

    signal head_cell_is_filled, body_cell_is_filled : boolean;
    signal re_head, re_body                         : boolean;

    ---------------------------------------------------------------------------
    -- debug stuff
    signal dbg_head_rx, dbg_head_tx : data_t;
    signal rd_data                  : data_t;
    
begin
    head_parity_fifo : entity work.parity_fifo
        generic map (
            logfcapacity => configure.down_head_logfcapacity)

        port map (
            clk            => clk,
            reset          => reset,
            --
            addr           => head_addr,
            di             => di,
            --
            we             => head_we,
            --
            -- rfifo output iface
            --
            vdata_o        => vdata_head,
            ready_o        => re_head,
            rx_next_cell   => rx_next_cell,
            cell_is_filled => head_cell_is_filled,
            rx_value       => rx_head_value,
            dbg_rx         => dbg_head_rx,
            dbg_tx         => dbg_head_tx);

    -- refine address: the header flit is the last in a cell
    head_addr <= foffset(head_addr_high_range) & (foffset(addr_low_range) + 1);

    head_cell_is_filled <= head_we and and_reduce(foffset(addr_low_range)) = '1';

    ---------------------------------------------------------------------------

    body_parity_fifo : entity work.parity_fifo
        generic map (
            logfcapacity => configure.down_body_logfcapacity)

        port map (
            clk            => clk,
            reset          => reset,
            --
            addr           => foffset(body_fptr_range),
            di             => di,
            --
            we             => body_we,
            --
            -- rfifo output iface
            --
            vdata_o        => vdata_body,
            ready_o        => re_body,
            rx_next_cell   => false,
            cell_is_filled => body_cell_is_filled,
            rx_value       => rx_body_value);

    body_cell_is_filled <= body_we and and_reduce(foffset(addr_low_range)) = '1';

    ---------------------------------------------------------------------------
    -- 3. other staff

    ---------------------------------------------------------------------------

    flit_counter : entity work.msg_flit_counter_dual
        port map (
            clk          => clk,
            reset        => reset,
            --
            vdata_head   => vdata_head,
            vdata_body   => vdata_body,
            vdata_o      => vdata_2,
            re_head      => re_head,
            re_body      => re_body,
            ready        => ready_o,
            --
            sop          => sop,
            rx_next_cell => rx_next_cell,
            head         => net_head);

    -- convert data format from 'msg' to 'net'
    vdata_o.data <= compose(net_head) when sop else vdata_2.data;
    vdata_o.dv   <= vdata_2.dv;

    ---------------------------------------------------------------------------

    arbiter_client : entity work.msg_arbiter_client
        port map (
            clk   => clk,
            reset => reset,
            --
            sop   => sop_fpga_rx,
            eop   => eop_fpga_rx,
            --
            req   => req_fpga_rx,
            ack   => ack_fpga_rx,
            --
            allow => arbiter_allows);

    (state_next, sop_fpga_rx, eop_fpga_rx) <=
        -- FIXME: use more smart condition for rising request
        next_state(state_curr, rx_cond, arbiter_allows);

    state_curr <= Idle when reset = '1' else state_next when rising_edge(clk);

    vdata_fpga_rx.dv   <= state_curr /= Idle;
    vdata_fpga_rx.data <= tlp_flit.compose(tx_tlp) when state_curr = Send_rx0 else
                          rx_body_value & "000000" & rx_head_value & "000000";

    rx_cond <= (rx_head_wcell_curr - rx_head_wcell_sent) >= head_ccapacity/4 or
               (rx_body_wcell_curr - rx_body_wcell_sent) >= body_ccapacity/4;

    rx_head_wcell_sent <= (others => '0') when reset = '1' else
                          rx_head_wcell_curr when rising_edge(clk) and arbiter_allows;

    rx_body_wcell_sent <= (others => '0') when reset = '1' else
                          rx_body_wcell_curr when rising_edge(clk) and arbiter_allows;

    ---------------------------------------------------------------------------
    -- debug stuff
--    rd_data            <= match(dbg_base, i_rld_ctrl, dbg_head_rx);
--    rd_data            <= match(dbg_base + 1, i_rld_ctrl, dbg_head_tx);
    o_rld_ctrl <= nothing;
    
end msg_injector;
