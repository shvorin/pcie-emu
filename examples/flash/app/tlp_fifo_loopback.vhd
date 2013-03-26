-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.tlp_package.all;
use work.util.all;

entity tlp_fifo_loopback is
    generic (
        DATA_WIDTH : natural := 128;

        -- application index is the client's number of TLP-switch
        APP_INDEX : natural := 0);
    port (
        rx_data   : in std_logic_vector(DATA_WIDTH - 1 downto 0);
        rx_dvalid : in std_logic;

        rx_sop : in std_logic;
        rx_eop : in std_logic;

        tx_data   : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        tx_dvalid : out std_logic;
        ej_ready  : in  std_logic;

        clk   : in std_logic;
        reset : in std_logic);
end entity tlp_fifo_loopback;

architecture fifo_loopback of tlp_fifo_loopback is
    signal fifo_empty              : std_logic;
    signal fifo_full, wrreq, rdreq : std_logic;

    signal qdata   : qqword;
    signal rdreq_1 : std_logic;

begin
    fifo_inst : entity work.sync_fifo
        generic map (
            capacity   => 8,
            data_width => 128)
        port map (
            clk   => clk,
            reset => reset,
            --
            re    => rdreq,
            we    => wrreq,
            empty => fifo_empty,
            full  => fifo_full,
            di    => rx_data,
            do    => qdata);

    rx : block
        signal income_info : tlp_info;
    begin
        income_info <= header_info(rx_data);

        -- incoming headers are dropped when FIFO is full
        wrreq <= rx_dvalid and rx_sop and to_stdl(income_info.kind = kind_MRd32) and not fifo_full;
    end block rx;

    tx : block
        type State is (stWait, stHead, stData);
        type FullState is record
            s             : State;
            reply         : qqword;
            incoming_addr : tlp_address;
            payload_cnt   : integer;
            clk_cnt       : std_logic_vector(31 downto 0);
        end record;

        type NextStateResult is record
            fstate           : FullState;
            rdreq, tx_dvalid : std_logic;
            tx_data          : qqword;
        end record;

        function nextState(fstate     : FullState;
                           qdata      : qqword;
                           fifo_empty : std_logic;
                           ej_ready   : std_logic)
            return NextStateResult
        is
            type     job_t is (CplD, MWr32, MRd32);
            constant job : job_t := CplD;  -- what to do in this test


            function mk_reply return qqword is
                constant incoming_info : tlp_info    := header_info(qdata);
                constant incoming_addr : tlp_address := parse(qdata(127 downto 64), is_4dw => incoming_info.is_4dw);
                constant new_addr      : tlp_address := x"00000000" & x"10000" & qdata(11 downto 0);

                -- FIXME: taken from the current PCI ID on sandbox
                --                                                    bus   & dev     & func
                constant my_pci_id : std_logic_vector(15 downto 0) := x"03" & "00000" & "000";
            begin
                case job is
                    when CplD =>        -- read completion
                        return mk_cpl_packet(qdata, my_pci_id);
                    when MWr32 =>       -- alt1: write
                        return mk_rw_packet(
                            kind   => kind_MWr32,
                            len    => conv_std_logic_vector(4, 10),
                            addr   => new_addr,
                            req_id => my_pci_id,
                            tag    => x"1a");
                    when MRd32 =>       -- alt2: repeat read
                        return mk_rw_packet(
                            kind   => kind_MRd32,
                            len    => conv_std_logic_vector(4, 10),
                            addr   => new_addr,
                            req_id => my_pci_id,
                            tag    => x"1b");
                end case;
            end;

            constant reply_info : tlp_info := header_info(fstate.reply);

            variable result : NextStateResult;

            procedure start_new is
            begin
                if fifo_empty = '0' then
                    result.fstate.s             := stHead;
                    result.fstate.reply         := mk_reply;
                    result.fstate.incoming_addr := parse(qdata(127 downto 64), is_4dw => false);
                    result.rdreq                := '1';
                else
                    result.fstate.s := stWait;
                end if;
            end;
        begin
            result.fstate := fstate;

            result.rdreq     := '0';
            result.tx_dvalid := '0';

            case fstate.s is
                when stWait =>
                    start_new;

                when stHead =>
                    result.tx_dvalid := '1';
                    result.tx_data   := fstate.reply;

                    -- break
                    if ej_ready = '0' then
                        return result;
                    end if;

                    if reply_info.is_payloaded then
                        result.fstate.s           := stData;
                        result.fstate.payload_cnt := reply_info.payload_len - 1;
                    else
                        start_new;
                    end if;
                    
                when stData =>
                    result.tx_dvalid := '1';
                    result.tx_data   := x"cafebabe" & fstate.clk_cnt & x"00fff"
                                        & conv_std_logic_vector(APP_INDEX, 4)
                                        & conv_std_logic_vector(fstate.payload_cnt, 8)
                                        & fstate.incoming_addr(31 downto 0);

                    -- break
                    if ej_ready = '0' then
                        return result;
                    end if;

                    if result.fstate.payload_cnt = 0 then
                        start_new;
                    else
                        result.fstate.payload_cnt := fstate.payload_cnt - 1;
                    end if;
            end case;

            result.fstate.clk_cnt := fstate.clk_cnt + 1;

            return result;
        end;

        signal fstate, fstate_r        : FullState;
        signal tx_dvalid0, tx_dvalid_r : std_logic;
        signal tx_data0, tx_data_r     : std_logic_vector(DATA_WIDTH - 1 downto 0);

    begin
        (fstate, rdreq, tx_dvalid0, tx_data0) <= nextState(fstate_r, qdata, fifo_empty, ej_ready);

        --tx_dvalid <= tx_dvalid_r;
        --tx_data   <= tx_data_r;
        tx_dvalid <= tx_dvalid0;
        tx_data   <= tx_data0;

        process(clk, reset)
        begin
            if reset = '1' then
                fstate_r.s       <= stWait;
                fstate_r.clk_cnt <= (others => '0');
                tx_dvalid_r      <= '0';
            elsif rising_edge(clk) then
                tx_dvalid_r <= tx_dvalid0;
                tx_data_r   <= tx_data0;
                fstate_r    <= fstate;
            end if;
        end process;
    end block tx;
end architecture fifo_loopback;
