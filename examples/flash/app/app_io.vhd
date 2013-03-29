-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library altera_mf;
use altera_mf.altera_mf_components.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.tlp_package.all;
use work.fm_pkg.all;

-------------------------------------------------------------------------------
-- Parameters
--
-- AVALON_WADDR    : Width of the address port of the on chip Avalon memory 
-- MAX_NUMTAG      : Indicates the maximum number of PCIe tags
-- TXCRED_WIDTH    : Width of the PCIe tx_cred back bus
-- TL_SELECTION    : Interface type                         
--                    0 : Descriptor data interface (in use with ICM)
--                    6 : Avalon-ST interface                  
-- MAX_PAYLOAD_SIZE_BYTE : Indicates the Maxpayload parameter specified in the
--                         PCIe MegaWizzard  
--
entity app_io is
    generic (
        AVALON_WADDR          : integer := 12;
        MAX_NUMTAG            : integer := 64;
        MAX_PAYLOAD_SIZE_BYTE : integer := 512;
        TL_SELECTION          : integer := 6;
        ECRC_FORWARD_CHECK    : integer := 1;
        ECRC_FORWARD_GENER    : integer := 1;
        CHECK_RX_BUFFER_CPL   : integer := 0;
        CLK_250_APP           : natural := 0;
        TXCRED_WIDTH          : integer := 22;
        DATA_WIDTH            : natural := 128
        );
    port (
        tx_stream_ready0      : in  std_logic;
        tx_stream_data0_0     : out std_logic_vector(74 downto 0);
        tx_stream_data0_1     : out std_logic_vector(74 downto 0);
        tx_stream_valid0      : out std_logic;
        tx_stream_fifo_empty0 : in  std_logic;
        tx_stream_mask0       : in  std_logic;
        tx_stream_cred0       : in  std_logic_vector(TXCRED_WIDTH - 1 downto 0);
        --
        rx_stream_data0_0     : in  std_logic_vector(81 downto 0);
        rx_stream_data0_1     : in  std_logic_vector(81 downto 0);
        rx_stream_valid0      : in  std_logic;
        rx_stream_ready0      : out std_logic;
        rx_stream_mask0       : out std_logic;
        --
        msi_stream_ready0     : in  std_logic;
        msi_stream_data0      : out std_logic_vector(7 downto 0);
        msi_stream_valid0     : out std_logic;
        aer_msi_num           : out std_logic_vector(4 downto 0);
        pex_msi_num           : out std_logic_vector(4 downto 0);
        app_msi_req           : out std_logic;
        app_msi_ack           : in  std_logic;
        app_msi_tc            : out std_logic_vector(2 downto 0);
        app_msi_num           : out std_logic_vector(4 downto 0);
        app_int_sts           : out std_logic;
        app_int_ack           : in  std_logic;
        cfg_busdev            : in  std_logic_vector(12 downto 0);
        cfg_devcsr            : in  std_logic_vector(31 downto 0);
        cfg_tcvcmap           : in  std_logic_vector(23 downto 0);
        cfg_linkcsr           : in  std_logic_vector(31 downto 0);
        cfg_prmcsr            : in  std_logic_vector(31 downto 0);
        cfg_msicsr            : in  std_logic_vector(15 downto 0);
        cpl_pending           : out std_logic;
        cpl_err               : out std_logic_vector(6 downto 0);
        err_desc              : out std_logic_vector(127 downto 0);
        ko_cpl_spc_vc0        : in  std_logic_vector(19 downto 0);
        pm_data               : out std_logic_vector(9 downto 0);
        test_sim              : in  std_logic;
        clk_in                : in  std_logic;
        rstn                  : in  std_logic;

        -- flash interface
        flash_address : out   std_logic_vector (ADDR_SZ - 1 downto 0);
        nflash_ce0    : out   std_logic;
        nflash_ce1    : out   std_logic;
        nflash_we     : out   std_logic;
        nflash_oe     : out   std_logic;
        flash_data    : inout std_logic_vector (31 downto 0);
        nflash_reset  : out   std_logic;
        flash_clk     : out   std_logic;
        flash_wait0   : in    std_logic;
        flash_wait1   : in    std_logic;
        nflash_adv    : out   std_logic);
end entity app_io;

architecture app of app_io is

    signal reset : std_logic;

    signal tx_st_data  : std_logic_vector(127 downto 0);
    signal tx_st_err   : std_logic;
    signal tx_st_empty : std_logic;
    signal tx_st_sop   : std_logic;
    signal tx_st_eop   : std_logic;
    signal tx_hdr0     : std_logic_vector(31 - 9 - 1 downto 0);
    signal tx_hdr1     : std_logic_vector(31 downto 0);
    signal tx_cpl_hdr0 : std_logic_vector(31 - 9 - 1 downto 0);
    signal tx_cpl_hdr1 : std_logic_vector(31 - 9 - 3 downto 0);

    type States is (stWait, stAddr, stData);

    signal ej_st : States;

    signal tx_count         : natural range 0 to 2**9 - 1;
    signal tx_count_is_zero : std_logic;

    signal tx_stream_ready0_r : std_logic;

    signal read_req : std_logic;
    signal align8B  : std_logic;

    signal read_hdr : std_logic_vector(63 downto 0);

    signal read_cpl_tc     : std_logic_vector(2 downto 0);
    signal read_cpl_attr   : std_logic_vector(1 downto 0);
    signal read_cpl_req_id : std_logic_vector(15 downto 0);
    signal read_cpl_tag    : std_logic_vector(7 downto 0);

    signal tx_read_cpl : std_logic;

    signal tx_addr : std_logic_vector(31 downto 0);

    signal valid_len : std_logic;

    signal jam_counter      : natural                      := 0;
    signal filtered_counter : natural                      := 0;
    signal inj_counter      : natural range 0 to 2**16 - 1 := 0;
    signal ej_counter       : natural range 0 to 2**16 - 1 := 0;

    signal int_req        : std_logic;
    signal my_app_int_sts : std_logic;

    ---------------------------------------------------------------------------

    signal rx_data   : std_logic_vector(127 downto 0);
    signal rx_dvalid : std_logic;
    signal rx_sop    : std_logic;
    signal rx_eop    : std_logic;
    --
    signal tx_data   : std_logic_vector(127 downto 0);
    signal tx_dvalid : std_logic;
    signal ej_ready  : std_logic;

    ---------------------------------------------------------------------------

    constant ARITY : positive := 1;
    subtype  competitors_range is integer range 0 to ARITY-1;

    signal rx_root    : tlp_rx;
    signal rx_subs    : tlp_rx_array(competitors_range);
    --
    signal tx_root    : tlp_tx;
    signal tx_root_bp : tlp_tx_backpressure;
    signal tx_subs    : tlp_tx_array(competitors_range);
    signal tx_subs_bp : tlp_tx_backpressure_array(competitors_range);
begin

    -- Some sensible values for the unused outputs
    msi_stream_data0  <= (others => '0');
    msi_stream_valid0 <= '0';
    aer_msi_num       <= (others => '0');
    pex_msi_num       <= (others => '0');
    app_msi_tc        <= (others => '0');
    app_msi_num       <= (others => '0');
    cpl_pending       <= '0';
    cpl_err           <= (others => '0');
    err_desc          <= (others => '0');
    pm_data           <= (others => '0');

    -- TLP application
    ---------------------------------------------------------------------------

    (tx_data, tx_dvalid) <= tx_root;
    rx_root              <= (rx_data, rx_dvalid, rx_sop, rx_eop);
    tx_root_bp.ej_ready  <= ej_ready;

    -- applications are the clients of TLP-switch
    apps : block
    begin
        -- client #0
        flash_manager : entity work.flash_manager
            port map (
                clk           => clk_in,
                reset         => reset,
                --
                rx_data       => rx_subs(0).data,
                rx_dvalid     => rx_subs(0).dvalid,
                rx_sop        => rx_subs(0).sop,
                rx_eop        => rx_subs(0).eop,
                tx_data       => tx_subs(0).data,
                tx_dvalid     => tx_subs(0).dvalid,
                ej_ready      => tx_subs_bp(0).ej_ready,
                --
                flash_address => flash_address,
                nflash_ce0    => nflash_ce0,
                nflash_ce1    => nflash_ce1,
                nflash_we     => nflash_we,
                nflash_oe     => nflash_oe,
                flash_data    => flash_data,
                nflash_reset  => nflash_reset,
                flash_clk     => flash_clk,
                flash_wait0   => flash_wait0,
                flash_wait1   => flash_wait1,
                nflash_adv    => nflash_adv);

        -- client #1
        --loopback : entity work.tlp_fifo_loopback
        --    generic map (DATA_WIDTH => 128,
        --                 APP_INDEX  => 1)
        --    port map (rx_data   => rx_subs(1).data,
        --              rx_dvalid => rx_subs(1).dvalid,
        --              rx_sop    => rx_subs(1).sop,
        --              rx_eop    => rx_subs(1).eop,
        --              tx_data   => tx_subs(1).data,
        --              tx_dvalid => tx_subs(1).dvalid,
        --              ej_ready  => tx_subs_bp(1).ej_ready,
        --              clk       => clk_in,
        --              reset     => reset);
    end block apps;

    --rx_subs(0)    <= rx_root;
    --tx_root       <= tx_subs(0);
    --tx_subs_bp(0) <= tx_root_bp;

    -- DMX part of TLP-switch
    dmx : entity work.tlp_rx_dmx
        generic map (ARITY => ARITY)
        port map (root  => rx_root,
                  subs  => rx_subs,
                  --
                  clk   => clk_in,
                  reset => reset);

    -- MUX part of TLP-switch
    mux : entity work.tlp_tx_mux
        generic map (ARITY => ARITY)
        port map (root    => tx_root,
                  root_bp => tx_root_bp,
                  subs    => tx_subs,
                  subs_bp => tx_subs_bp,
                  --
                  clk     => clk_in,
                  reset   => reset);

    -- Injection: receive from PCI-E
    tlp_rx_128 : work.tlp_rx_128
        port map (
            clk_in            => clk_in,
            rsts              => reset,
            --
            rx_stream_data0_0 => rx_stream_data0_0,
            rx_stream_data0_1 => rx_stream_data0_1,
            rx_stream_valid0  => rx_stream_valid0,
            rx_stream_ready0  => rx_stream_ready0,
            rx_stream_mask0   => rx_stream_mask0,
            --
            rx_data           => rx_data,
            rx_dvalid         => rx_dvalid,
            rx_sop            => rx_sop,
            rx_eop            => rx_eop);

    -- Ejection: send to PCI-E
    tlp_tx_128 : work.tlp_tx_128
        port map (
            clk_in                => clk_in,
            rsts                  => reset,
            --
            tx_stream_data0_0     => tx_stream_data0_0,
            tx_stream_data0_1     => tx_stream_data0_1,
            tx_stream_valid0      => tx_stream_valid0,
            tx_stream_ready0      => tx_stream_ready0,
            tx_stream_mask0       => tx_stream_mask0,
            tx_stream_fifo_empty0 => tx_stream_fifo_empty0,
            tx_stream_cred0       => tx_stream_cred0,
            --
            tx_data               => tx_data,
            tx_dvalid             => tx_dvalid,
            ej_ready              => ej_ready);

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------

    int_req <= '0';

    process (clk_in, reset)
    begin
        if reset = '1' then
            my_app_int_sts <= '0';
        elsif rising_edge(clk_in) then
            if my_app_int_sts = '1' and app_msi_ack = '1' then
                my_app_int_sts <= '0';
            elsif int_req = '1' then
                my_app_int_sts <= '1';
            end if;
        end if;
    end process;

    app_int_sts <= '0';
    app_msi_req <= my_app_int_sts;

    reset <= not rstn;

end architecture app;
