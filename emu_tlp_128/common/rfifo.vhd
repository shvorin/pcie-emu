-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.util.all;


entity rfifo is
    generic (
        capacity    : positive;         -- queue capacity
        data_width  : positive;
        bubble_size : positive := 1);

    port (
        clk, reset   : in  std_logic;   -- asynchronous reset (active high)
        --
        -- rfifo input iface
        data_i       : in  std_logic_vector(data_width-1 downto 0);
        dv_i         : in  boolean;
        ready_i      : out boolean;
        --
        ready_bubble : out boolean;
        size         : out integer range 0 to capacity;
        --
        -- rfifo output iface
        data_o       : out std_logic_vector(data_width-1 downto 0);
        dv_o         : out boolean;
        ready_o      : in  boolean);
end rfifo;


architecture rfifo of rfifo is
    signal we, re, empty, full : std_logic;
    signal bsize               : std_logic_vector(ceil_log2(capacity+1)-1 downto 0);
    signal ready_i_x           : boolean;
    
begin
    fifo : entity work.sync_fifo
        generic map (capacity   => capacity,
                     data_width => data_width)

        port map (
            clk   => clk,
            reset => reset,
            di    => data_i,
            we    => we,
            do    => data_o,
            empty => empty,
            full  => full,
            size  => bsize,
            re    => re);

    we        <= to_stdl(ready_i_x and dv_i);
    re        <= not empty and to_stdl(ready_o);
    ready_i_x <= full = '0';

    dv_o         <= empty = '0';
    ready_i      <= ready_i_x;
    ready_bubble <= capacity - bubble_size >= bsize;  -- FIXME: check integer comparation
    size         <= conv_integer(bsize);

end rfifo;
