-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

-- Toplevel module with empty interface used for emulation via GHDL.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;

use work.util.all;
use work.tlp_package.all;
use work.tlp256;

entity emu_top is
end emu_top;


architecture emu_top of emu_top is
    constant period : time := 1 ns;

    signal clk, reset : std_logic;

    -- rx
    signal rx_data                  : tlp256.data_t;
    signal rx_dvalid                : std_logic;
    signal rx_sop, rx_eop, ej_ready : std_logic;
    --
    -- tx
    signal tx_data                  : tlp256.data_t;
    signal tx_dvalid                : std_logic;

    -- data representation for foreing calls
    type foreign_tlp256_data_t is array (integer range 0 to 7) of integer;

    function wrap(data : tlp256.data_t) return foreign_tlp256_data_t is
        variable result : foreign_tlp256_data_t;
    begin
        for i in result'range loop
            result(i) := conv_integer(data(32*(i+1) - 1 downto 32*i));
        end loop;

        return result;
    end;

    function unwrap(a : foreign_tlp256_data_t) return tlp256.data_t is
        variable result : tlp256.data_t;
    begin
        for i in a'range loop
            result(32*(i+1) - 1 downto 32*i) := conv_std_logic_vector(a(i), 32);
        end loop;

        return result;
    end;

    -- About linking with foreign functions see
    -- http://ghdl.free.fr/ghdl/Restrictions-on-foreign-declarations.html

    procedure line_up(tx_dvalid          : std_logic;
                      dw0, dw1, dw2, dw3 : integer;
                      ej_ready           : std_logic;
                      arr                : foreign_tlp256_data_t)
    is
    begin
        assert false severity failure;
    end;

    attribute foreign of line_up : procedure is "VHPIDIRECT line_up";

    -- NB: corresponding C prototype is: void line_down(struct scalar_params *, uint32_t arr[8])
    procedure line_down(
        -- scalar parameters
        rx_dvalid          : out std_logic;
        dw0, dw1, dw2, dw3 : out integer;
        rx_sop, rx_eop     : out std_logic;
        ej_ready           : out std_logic;
        -- composite parameter(s)
        arr                : out foreign_tlp256_data_t)
    is
    begin
        assert false severity failure;
    end;

    attribute foreign of line_down : procedure is "VHPIDIRECT line_down";

    constant zeros64 : std_logic_vector(63 downto 0) := (others => '0');

begin
    cg : entity work.clock_gen
        generic map (period)
        port map (clk, reset);

    app : tlp256.io
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
        variable v_data3, v_data2, v_data1, v_data0          : integer;
        variable arr                                         : foreign_tlp256_data_t;
        variable x, y                                        : integer;
        variable l                                           : line;
    begin
        if reset = '1' then
            rx_data   <= (others => '0');
            rx_dvalid <= '0';
            rx_sop    <= '0';
            rx_eop    <= '0';
            ej_ready  <= '0';

        elsif rising_edge(clk) then
            line_down(v_rx_dvalid, v_data0, v_data1, v_data2, v_data3, v_rx_sop, v_rx_eop, v_ej_ready, arr);
            rx_data <= conv_std_logic_vector(v_data3, 32) &
                       conv_std_logic_vector(v_data2, 32) &
                       conv_std_logic_vector(v_data1, 32) &
                       conv_std_logic_vector(v_data0, 32) & zeros64 & zeros64;  --
            -- FIXME
            --line_test(x, arr, y);
            write(l, arr(0));
            write(l, ' ');
            write(l, arr(7));
            writeline(output, l);

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
                    ej_ready,
                    wrap(tx_data));
            null;
        end if;
    end process;
    
end emu_top;
