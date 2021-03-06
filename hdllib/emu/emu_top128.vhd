-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

-- Toplevel module with empty interface used for emulation via GHDL.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.util.all;
use work.tlp_package.all;
use work.tlp128;

entity emu_top128 is
end emu_top128;


architecture emu_top128 of emu_top128 is
    constant period : time := 1 ns;

    signal clk, reset : std_logic;

    -- rx
    signal rx_data                  : tlp128.data_t;
    signal rx_dvalid                : std_logic;
    signal rx_sop, rx_eop, ej_ready : std_logic;
    --
    -- tx
    signal tx_data                  : tlp128.data_t;
    signal tx_dvalid                : std_logic;

    -- data representation for foreing calls
    type foreign_tlp128_data_t is array (integer range 0 to 3) of integer;

    function wrap(data : tlp128.data_t) return foreign_tlp128_data_t is
        variable result : foreign_tlp128_data_t;
    begin
        for i in result'range loop
            result(i) := conv_integer(data(32*(i+1) - 1 downto 32*i));
        end loop;

        return result;
    end;

    function unwrap(a : foreign_tlp128_data_t) return tlp128.data_t is
        variable result : tlp128.data_t;
    begin
        for i in a'range loop
            result(32*(i+1) - 1 downto 32*i) := conv_std_logic_vector(a(i), 32);
        end loop;

        return result;
    end;

    -- About linking with foreign functions see
    -- http://ghdl.free.fr/ghdl/Restrictions-on-foreign-declarations.html

    procedure line128_up(tx_dvalid       : std_logic;
                         ej_ready        : std_logic;
                         foreign_tx_data : foreign_tlp128_data_t)
    is
    begin
        assert false severity failure;
    end;

    attribute foreign of line128_up : procedure is "VHPIDIRECT line128_up";

    -- NB: corresponding C prototype is: void line128_down(struct scalar_params *, uint32_t arr[8])
    procedure line128_down(
        -- scalar parameters
        rx_dvalid       : out std_logic;
        rx_sop, rx_eop  : out std_logic;
        ej_ready        : out std_logic;
        -- composite parameter(s)
        foreign_rx_data : out foreign_tlp128_data_t)
    is
    begin
        assert false severity failure;
    end;

    attribute foreign of line128_down : procedure is "VHPIDIRECT line128_down";

begin
    cg : entity work.clock_gen
        generic map (period)
        port map (clk, reset);

    app : tlp128.io
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
        variable v_rx_dvalid, v_rx_sop, v_rx_eop, v_ej_ready : std_logic;
        variable foreign_rx_data                             : foreign_tlp128_data_t;
    begin
        if reset = '1' then
            rx_data   <= (others => '0');
            rx_dvalid <= '0';
            rx_sop    <= '0';
            rx_eop    <= '0';
            ej_ready  <= '0';

        elsif rising_edge(clk) then
            line128_down(v_rx_dvalid, v_rx_sop, v_rx_eop, v_ej_ready, foreign_rx_data);
            rx_data   <= unwrap(foreign_rx_data);
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
            line128_up(tx_dvalid, ej_ready, wrap(tx_data));
        end if;
    end process;
    
end emu_top128;
