-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.tlp_package.all;

entity tlp_tx_mux is
    generic (ARITY : positive);
    port (
        root    : out tlp_tx;
        root_bp : in  tlp_tx_backpressure;
        --
        subs    : in  tlp_tx_array(0 to ARITY - 1);
        subs_bp : out tlp_tx_backpressure_array(0 to ARITY - 1);
        --
        clk     : in  std_logic;
        reset   : in  std_logic);
end entity tlp_tx_mux;

architecture tlp_tx_mux of tlp_tx_mux is
    subtype competitors_range is integer range 0 to ARITY-1;
    subtype competitors_t is std_logic_vector(competitors_range);

    type boolean_array is array (integer range <>) of boolean;
    
    function fmux(sel    : competitors_t;
                  inputs : tlp_tx_array(competitors_range)) return tlp_tx
    is
        variable result : tlp_tx := ((others => 'X'), '0');
    begin
        for i in sel'range loop
            if sel(i) = '1' then
                result := inputs(i);
            end if;
        end loop;

        return result;
    end;

    signal sel        : competitors_t;
    signal reqs, acks : competitors_t;
    signal sops, eops : competitors_t;
    signal ej_ready   : competitors_t;

    signal subs_r : tlp_tx_array(competitors_range);
begin
    g : for i in competitors_range generate
        client : entity work.msg_arbiter_client
            port map(
                clk   => clk,
                reset => reset,
                --
                sop   => sops(i),
                eop   => eops(i),
                --
                req   => reqs(i),
                ack   => acks(i),
                allow => sel(i));

        ej_ready(i)         <= sel(i) and root_bp.ej_ready;
        -- FIXME: stub
        -- subs_bp(i).ej_ready <= ej_ready(i);

        markup : entity work.tlp_markup
            port map (
                tx_data   => subs(i).data,
                tx_dvalid => subs(i).dvalid,
                ej_ready  => ej_ready(i),
                --
                sop       => sops(i),
                eop       => eops(i),
                info      => open,
                --
                clk       => clk,
                reset     => reset);
    end generate;

    arbiter : entity work.arbiter
        generic map (NCOMPETITORS => ARITY)
        port map(
            clk   => clk,
            reset => reset,
            --
            ena   => root_bp.ej_ready,
            req   => reqs,
            ack   => acks);

    ---------------------------------------------------------------------------

    process (clk, reset)
    begin
        if reset = '1' then
            subs_r <= (others => ((others => 'X'), '0'));
        elsif rising_edge(clk) then
            subs_r <= subs;
        end if;
    end process;

    -- FIXME: stub
    --root <= fmux(sel, subs);
    root <= subs(0);
    subs_bp <= (0 => (ej_ready => '1'), others => (ej_ready => '1'));
end architecture tlp_tx_mux;
