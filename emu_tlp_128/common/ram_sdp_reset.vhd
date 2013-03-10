-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- Simple dual port _resettable_ syncronous RAM: one port for reading, one for
-- writing.
-- NB: actually may be synthesable of register, not BRAM's.
entity ram_sdp_reset is
    generic (
        data_width : integer;
        depth      : integer
        );                                                             

    port (
        clk, reset : in  std_logic;
        --
        rd_addr    : in  integer range 0 to depth-1;
        do         : out std_logic_vector (data_width-1 downto 0);
        --
        wr_addr    : in  integer range 0 to depth-1;
        we         : in  std_logic;
        di         : in  std_logic_vector (data_width-1 downto 0)
        );
end ram_sdp_reset;


architecture ram_sdp_reset of ram_sdp_reset is
    type ram_type is array(depth-1 downto 0) of std_logic_vector(data_width-1 downto 0);

    signal ram : ram_type;

begin
    process (clk, reset)
    begin
        if reset = '1' then
            ram <= (others => (others => '0'));
            do  <= (others => '0');
            
        elsif rising_edge(clk) then
            do <= ram(rd_addr);

            if we = '1' then
                ram(wr_addr) <= di;
            end if;
        end if;
    end process;
end ram_sdp_reset;
