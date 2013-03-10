-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.vdata.all;
use work.credit.all;
use work.link_data.all;
use work.util.all;
use work.configure;


entity olink_adapter is
    port(
        clk, reset : in  std_logic;     -- asynchronous reset (active high)
        --
        vdata_i    : in  vflit_t;
        rxcredit_i : in  credit_t;      -- assumed to be always valid
        --
        has_bubble : out boolean;
        ready_i    : out boolean;
        --
        -- output link iface (FIFO)
        raw_data   : out data_t;
        raw_dv     : out std_logic;
        ready      : in  std_logic);
end olink_adapter;


architecture olink_adapter of olink_adapter is
    constant rfifo_capacity : integer := configure.max_pktlen * 5;

    signal rfifo_size     : integer range 0 to rfifo_capacity;
    signal rfifo_ready    : boolean;
    signal lpack_len, cnt : lpack_len_t;
    signal atHead         : boolean;

    signal lheader : lheader_t;

    signal vdata_1 : vflit_t;

    signal flowcount : std_logic_vector(31 downto 0);

begin
    lheader   <= (rxcredit_i, lpack_len, flowcount);
    lpack_len <= rfifo_size when rfifo_size <= lpack_len_t'high else lpack_len_t'high;
    atHead    <= cnt = 0;

    process (clk, reset)
    begin
        if reset = '1' then
            cnt <= 0;

        elsif rising_edge(clk) and ready = '1' and vdata_1.dv then
            if atHead then
                cnt <= lpack_len;
            else
                cnt <= cnt - 1;
            end if;
        end if;
    end process;

    rfifo : entity work.rfifo
        generic map (capacity    => rfifo_capacity,
                     data_width  => data_t'length,
                     bubble_size => configure.max_pktlen)

        port map (
            clk          => clk,
            reset        => reset,
            --
            data_i       => vdata_i.data,
            dv_i         => vdata_i.dv,
            ready_i      => ready_i,
            ready_bubble => has_bubble,
            size         => rfifo_size,
            --
            data_o       => vdata_1.data,
            dv_o         => vdata_1.dv,
            ready_o      => rfifo_ready);

    rfifo_ready <= ready = '1' and not atHead;

    raw_data <= compose(lheader) when atHead else vdata_1.data;
    raw_dv   <= to_stdl(vdata_1.dv or atHead);

    flowcount <= (others => '0') when reset = '1'
                 else flowcount + 1 when rising_edge(clk) and cnt = 1 and ready = '1' and vdata_1.dv;
    
end olink_adapter;
