-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.tlp_package.all;
use work.util.all;

-- markup tlp_tx stream with sop, eop and auxillary metainformation about packet
entity tlp_markup is
    port (
        tx_data   : in  std_logic_vector(127 downto 0);
        tx_dvalid : in  std_logic;
        ej_ready  : in  std_logic;
        --
        sop, eop  : out std_logic;
        info      : out tlp_info;
        --
        clk       : in  std_logic;
        reset     : in  std_logic);
end entity tlp_markup;

architecture tlp_markup of tlp_markup is
    type State is (idle, wait_rdy, head, data);

    type FullState is record
        s     : State;
        count : integer range 0 to 2**8-1;  -- FIXME
        info  : tlp_info;
    end record;

    function NextState(fstate  : FullState;
                       tx_data : std_logic_vector(127 downto 0);
                       d, e    : boolean)
        return FullState
    is
        constant info   : tlp_info  := header_info(tx_data);
        variable result : FullState := fstate;

        procedure new_packet is
        begin
            if d then
                result.count := info.payload_len;
                result.info  := info;
                if e then
                    result.s := head;
                else
                    result.s := wait_rdy;
                end if;
            else
                result.s := idle;
            end if;
        end;

        procedure cont_packet is
        begin
            if d and e then
                result.count := fstate.count - 1;
                result.s     := data;
            end if;
        end;
    begin
        case fstate.s is
            when idle =>
                new_packet;

            when wait_rdy =>
                if d and e then
                    result.s := head;
                end if;

            when head =>
                if fstate.count = 0 then
                    new_packet;
                else
                    cont_packet;
                end if;

            when data =>
                if fstate.count = 0 then
                    new_packet;
                else
                    cont_packet;
                end if;
        end case;

        return result;
    end;
    signal fstate, fstate_r : FullState;
begin
    fstate <= NextState(fstate_r, tx_data, tx_dvalid = '1', ej_ready = '1');
    info   <= fstate.info;

    sop <= to_stdl(fstate.s = head or fstate.s = wait_rdy);
    eop <= to_stdl((fstate.s = head or fstate.s = data) and fstate.count = 0);

    process (clk, reset)
    begin
        if reset = '1' then
            fstate_r.s <= idle;
        elsif rising_edge(clk) then
            fstate_r <= fstate;
        end if;
    end process;
end architecture tlp_markup;
