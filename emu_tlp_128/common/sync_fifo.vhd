-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.util.all;


entity sync_fifo is
    generic (
        capacity   : positive := 15;    -- queue capacity
        data_width : positive := 8);

    port (
        clk, reset  : in  std_logic;    -- asynchronous reset (active high)
        --
        re, we      : in  std_logic;
        full, empty : out std_logic;
        di          : in  std_logic_vector(data_width-1 downto 0);
        do          : out std_logic_vector(data_width-1 downto 0);
        --
        size        : out std_logic_vector(ceil_log2(capacity+1)-1 downto 0));
end sync_fifo;

architecture sync_fifo of sync_fifo is
    constant ptr_width : positive := ceil_log2(capacity);

    signal rd_addr : std_logic_vector(ptr_width-1 downto 0);
    signal wr_addr : std_logic_vector(ptr_width-1 downto 0);

    signal req_write : std_logic;

    signal do_ff, do_ram : std_logic_vector(data_width-1 downto 0);

    signal empty_i, empty_s, we_s : std_logic;
    signal size0                  : std_logic_vector(ceil_log2(capacity+1)-1 downto 0);
    
begin
    process(clk)
    begin
        if clk = '1' and clk'event then
            if we = '1' then
                do_ff <= di;
            end if;

            we_s    <= we;
            empty_s <= empty_i;
        end if;
    end process;

    control0 : entity work.control
        generic map (capacity => capacity)
        
        port map (
            reset    => reset,
            clk      => clk,
            fifo_wr  => we,
            fifo_rd  => re,
            rd_ptr   => rd_addr,
            wr_ptr   => wr_addr,
            valid_rd => open,
            valid_wr => req_write,
            empty    => empty_i,
            full     => full,
            size     => size0
            );

    memory0 : entity work.ram_dp
        generic map (
            data_width   => data_width,
            bit_capacity => capacity*data_width)

        port map (
            clk     => clk,
            wr_addr => wr_addr,
            rd_addr => rd_addr,
            di      => di,
            do      => do_ram,
            we      => req_write
            );

    do    <= do_ff when we_s = '1' and conv_integer(size0) = 1 else do_ram;
    empty <= empty_i;
    size  <= size0;
    
end sync_fifo;
