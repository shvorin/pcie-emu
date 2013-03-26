-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.tlp_package.all;
use work.config.all;

entity tlp_rx_128 is
    port (
        clk_in : in std_logic;
        rsts   : in std_logic;

        rx_stream_data0_0 : in  std_logic_vector(81 downto 0);
        rx_stream_data0_1 : in  std_logic_vector(81 downto 0);
        rx_stream_valid0  : in  std_logic;
        rx_stream_ready0  : out std_logic;
        rx_stream_mask0   : out std_logic;

        rx_data   : out std_logic_vector(127 downto 0);
        rx_dvalid : out std_logic;
        rx_sop    : out std_logic;
        rx_eop    : out std_logic);
end entity tlp_rx_128;

architecture tlp_rx of tlp_rx_128 is
    function decoded_bar(rx_st_bardec : std_logic_vector(7 downto 0))
        return std_logic_vector
    is
        variable result : std_logic_vector(2 downto 0);
    begin
        result := (others => '0');

        for i in rx_st_bardec'range loop
            if rx_st_bardec(i) = '1' then
                result := conv_std_logic_vector(i, 3);
            end if;
        end loop;

        return result;
    end;

    ---------------------------------------------------------------------------

    type parsed_rx_stream is record
        be     : std_logic_vector(15 downto 0);
        sop    : std_logic;
        eop    : std_logic;
        empty  : std_logic;
        bardec : std_logic_vector(7 downto 0);
        data   : std_logic_vector(127 downto 0);
    end record;

    function parse(rx_stream_data0_0, rx_stream_data0_1 : std_logic_vector(81 downto 0))
        return parsed_rx_stream
    is
    begin
        return (
            be     => rx_stream_data0_0(81 downto 74) & rx_stream_data0_1(81 downto 74),
            sop    => rx_stream_data0_0(73),
            eop    => rx_stream_data0_1(72),
            empty  => rx_stream_data0_0(72),
            bardec => rx_stream_data0_0(71 downto 64),
            data   => rx_stream_data0_1(63 downto 0) & rx_stream_data0_0(63 downto 0));
    end;

    ---------------------------------------------------------------------------

    type State is (stWait, stSkip, stData);

    type FullState is record
        s                                  : State;
        count                              : integer range 0 to 2**8-1;  -- FIXME
        accepted_counter, rejected_counter : integer range 0 to 2**16-1;
    end record;

    -- imitate coarity
    type NextStateResult is record
        fstate                    : FullState;
        rx_sop, rx_eop, rx_dvalid : std_logic;
    end record;

    function nextState(fstate : FullState;
                       rx_st  : parsed_rx_stream)
        return NextStateResult
    is
        constant info : tlp_info := header_info(rx_st.data);

        variable result : NextStateResult := (fstate, '0', '0', '0');

        function skip return NextStateResult is
        begin
            if info.payload_len /= 0 then
                result.fstate.s := stSkip;
            end if;
            return result;
        end;

    begin
        case fstate.s is
            when stWait =>
                if rx_st.sop = '0' then
                    return result;
                end if;

                result.fstate.count := info.payload_len;

                case info.kind is
                    when kind_MWr32 | kind_MWr64 | kind_MRd32 | kind_CplD =>
                        if not info.is_qwaligned then
                            result.fstate.rejected_counter := fstate.rejected_counter + 1;
                            return skip;
                        end if;

                        -- TODO: implement kind_CplD (read completion) here
                    when others =>      -- unknown TLP packet kind
                        return skip;
                end case;

                result.rx_sop                  := '1';
                result.rx_dvalid               := '1';
                result.fstate.accepted_counter := fstate.accepted_counter + 1;

                if info.payload_len = 0 then
                    result.rx_eop   := '1';
                    result.fstate.s := stWait;
                else
                    result.fstate.s := stData;
                end if;

            when stSkip =>
                -- FIXME: using count may be more reliable
                if rx_st.eop = '1' then
                    result.fstate.s := stWait;
                end if;
                
            when stData =>
                result.rx_dvalid := '1';

                if fstate.count = 1 then
                    result.rx_eop       := '1';
                    result.fstate.s     := stWait;
                    result.fstate.count := 0;
                else
                    result.fstate.count := fstate.count - 1;
                end if;
        end case;

        return result;
    end;

    signal fstate, fstate_r : FullState;
    signal rx_st            : parsed_rx_stream;
begin
    rx_stream_ready0 <= '1';
    rx_stream_mask0  <= '0';
    --
    --
    rx_data          <= rx_st.data;

    rx_sop    <= rx_st.sop;
    rx_eop    <= rx_st.eop;
    rx_dvalid <= rx_stream_valid0;

    --(fstate, rx_sop, rx_eop, rx_dvalid) <= nextState(fstate_r, rx_st);
    rx_st <= parse(rx_stream_data0_0, rx_stream_data0_1);

    --process (clk_in, rsts)
    --begin
    --    if rsts = '1' then
    --        fstate_r <= (stWait, 0, 0, 0);
    --    elsif rising_edge(clk_in) then
    --        fstate_r <= fstate;
    --    end if;
    --end process;

end architecture tlp_rx;
