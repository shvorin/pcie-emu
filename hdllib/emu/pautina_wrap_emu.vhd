-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use work.types.all;
use work.ast256.all;
use work.avmm.all;
use work.pautina_package.all;
use work.qsfp_package.all;

-- emulation version of pautina_wrap
entity pautina_wrap_emu is
    port (
        clk   : in std_logic;
        reset : in std_logic;

        -- Avalon-ST
        ast_rx       : in  ast_t;
        ast_tx       : out ast_t;
        ast_tx_bp    : in  ast_bp_t;
        rx_st_bardec : in  std_logic_vector(7 downto 0));
end entity;

architecture pautina_wrap_emu of pautina_wrap_emu is
begin
    -- NB: configuration should reside in examples/EXAMPLE_NAME/
    pautina : configuration work.pautina_io_cfg
        port map (
            clk   => clk,
            reset => reset,

            ast_rx       => ast_rx,
            ast_tx       => ast_tx,
            ast_tx_bp    => ast_tx_bp,
            rx_st_bardec => rx_st_bardec,

            -- flash
            flash_address => open,
            nflash_ce0    => open,
            nflash_ce1    => open,
            nflash_we     => open,
            nflash_oe     => open,
            flash_data    => open,
            nflash_reset  => open,
            flash_clk     => open,
            flash_wait0   => 'X',
            flash_wait1   => 'X',
            nflash_adv    => open,

            -- QSFP: significant signals
            qsfp_refclk => (others => 'X'),
            qsfp_tx_p   => open,
            qsfp_rx_p   => (others => (others => 'X')),

            -- QSFP: misc signals
            qsfp_mod_seln   => open,
            qsfp_rstn       => open,
            qsfp_scl        => open,
            qsfp_sda        => open,
            qsfp_interruptn => (others => 'X'),
            qsfp_mod_prsn   => (others => 'X'),
            qsfp_lp_mode    => open,

            -- LEDs
            user_led_g => open,
            user_led_r => open);
end architecture;
