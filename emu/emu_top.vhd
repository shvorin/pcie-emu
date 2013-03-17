-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

-- Toplevel module with empty interface used for emulation via GHDL.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.util.all;
use work.tlp_package.all;

entity emu_top is
end emu_top;


architecture emu_top of emu_top is
    constant period : time := 1 ns;

    subtype data_t is std_logic_vector(63 downto 0);  -- FIXME

    signal clk, reset : std_logic;

    -- rx
    signal rx_data                  : std_logic_vector(127 downto 0);
    signal rx_dvalid                : std_logic;
    signal rx_sop, rx_eop, ej_ready : std_logic;
    --
    -- tx
    signal tx_data                  : std_logic_vector(127 downto 0);
    signal tx_dvalid                : std_logic;

    -- About linking with foreign functions see
    -- http://ghdl.free.fr/ghdl/Restrictions-on-foreign-declarations.html

    procedure line_up(tx_dvalid                  : std_logic;
                      dw0, dw1, dw2, dw3 : integer;
                      ej_ready                   : std_logic)
    is
    begin
        assert false severity failure;
    end;

    attribute foreign of line_up : procedure is "VHPIDIRECT line_up";

    procedure line_down(rx_dvalid                  : out std_logic;
                        dw0, dw1, dw2, dw3 : out integer;
                        rx_sop, rx_eop             : out std_logic;
                        ej_ready                   : out std_logic)
    is
    begin
        assert false severity failure;
    end;

    attribute foreign of line_down : procedure is "VHPIDIRECT line_down";

    constant zeros64 : data_t := (others => '0');
begin
    cg : entity work.clock_gen
        generic map (period)
        port map (clk, reset);

    app : tlp_io_128
        port map (
            clk   => clk,
            reset => reset,

            -- rx
            rx_data   => rx_data,
            rx_dvalid => rx_dvalid,
            rx_sop    => rx_sop,
            rx_eop    => rx_eop,

            -- tx
            tx_data   => tx_data,
            tx_dvalid => tx_dvalid,
            ej_ready  => ej_ready);

    data_down : process (clk, reset)
        variable v_rx_data                                   : data_t;
        variable v_rx_dvalid, v_rx_sop, v_rx_eop, v_ej_ready : std_logic;
        variable v_data3, v_data2, v_data1, v_data0          : integer;
    begin
        if reset = '1' then
            rx_data   <= (others => '0');
            rx_dvalid <= '0';
            rx_sop    <= '0';
            rx_eop    <= '0';
            ej_ready  <= '0';

        elsif rising_edge(clk) then
            line_down(v_rx_dvalid, v_data0, v_data1, v_data2, v_data3, v_rx_sop, v_rx_eop, v_ej_ready);
            rx_data <= conv_std_logic_vector(v_data3, 32) &
                       conv_std_logic_vector(v_data2, 32) &
                       conv_std_logic_vector(v_data1, 32) &
                       conv_std_logic_vector(v_data0, 32);

            rx_dvalid <= v_rx_dvalid;
            rx_sop    <= v_rx_sop;
            rx_eop    <= v_rx_eop;
            ej_ready  <= v_ej_ready;
        end if;
    end process;

    data_up : process (clk)
    begin
        if rising_edge(clk) then
            -- NB: also looping back ej_ready 
            line_up(tx_dvalid,
                    conv_integer(tx_data(31 downto 0)),
                    conv_integer(tx_data(63 downto 32)),
                    conv_integer(tx_data(95 downto 64)),
                    conv_integer(tx_data(127 downto 96)),
                    ej_ready);
        end if;
    end process;
    
end emu_top;
