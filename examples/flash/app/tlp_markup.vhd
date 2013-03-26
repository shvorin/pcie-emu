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
    type State is record
        sop, eop, active : std_logic;
    end record;

    type FullState is record
        s     : State;
        count : integer range 0 to 2**8-1;  -- FIXME
        info  : tlp_info;
    end record;

    function NextState(fstate              : FullState;
                       tx_data             : std_logic_vector(127 downto 0);
                       tx_dvalid, ej_ready : std_logic)
        return FullState
    is
        constant info : tlp_info := header_info(tx_data);

        variable result : FullState := fstate;

    begin
        if fstate.s.active = '1' and fstate.s.eop = '0' then
            -- continue current packet
            if tx_dvalid = '1' then
                if fstate.count = 1 then
                    result.s := ('0', '1', '1');
                else
                    result.count := fstate.count - 1;
                    result.s     := ('0', '0', '1');
                end if;
            else
                result.s := (others => '0');
            end if;
        else
            -- start new packet
            if tx_dvalid = '1' then
                result.info  := info;
                result.count := info.payload_len;
                result.s := (sop    => '1',
                             eop    => to_stdl(not info.is_payloaded),
                             active => '1');
            else
                result.s := (others => '0');
            end if;
        end if;

        return result;
    end;

    signal fstate, fstate_r : FullState;
begin
    fstate <= NextState(fstate_r, tx_data, tx_dvalid, ej_ready);
    sop    <= fstate.s.sop;
    eop    <= fstate.s.eop;
    info   <= fstate.info;

    process (clk, reset)
    begin
        if reset = '1' then
            fstate_r.s <= (others => '0');
        elsif rising_edge(clk) then
            if ej_ready = '1' then
                fstate_r <= fstate;
            end if;
        end if;
    end process;
end architecture tlp_markup;
