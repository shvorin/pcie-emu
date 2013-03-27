-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.tlp_package.all;

entity tlp_rx_dmx is
    generic (ARITY : positive);
    port (
        root  : in  tlp_rx;
        subs  : out tlp_rx_array(0 to ARITY - 1);
        --
        clk   : in  std_logic;
        reset : in  std_logic);
end entity tlp_rx_dmx;

architecture tlp_rx_dmx of tlp_rx_dmx is
    subtype competitors_range is integer range 0 to ARITY-1;
    subtype competitors_t is std_logic_vector(competitors_range);

    function foo(header : qqword) return competitors_t is
        constant info : tlp_info    := header_info(header);
        constant addr : tlp_address := parse(header(127 downto 64), info.is_4dw);

        variable result : competitors_t := (others => '0');
    begin
        -- NB: flash is the only app
        --case info.kind is
        --    when kind_MRd32 | kind_MRd64 | kind_MWr32 | kind_MWr64 =>
        --        for i in competitors_t'range loop
        --            -- ad hoc target choice
        --            if conv_integer(addr(11 downto 8)) = i then
        --                result(i) := '1';
        --                return result;
        --            end if;
        --        end loop;
                
        --    when others => null;
        --end case;

        return (0 => '1', others => '0');  -- default target is 0-th
    end;

    signal active_r : competitors_t;
    signal root_r   : tlp_rx;

begin
    process(clk, reset)
    begin
        if reset = '1' then
            active_r      <= (others => '0');
            root_r.dvalid <= '0';
        elsif rising_edge(clk) then
            root_r <= root;

            if root.sop = '1' and root.dvalid = '1' then
                active_r <= foo(root.data);
            end if;
        end if;
    end process;

    g : for i in competitors_t'range generate
        subs(i) <= (root_r.data,
                    dvalid => root_r.dvalid and active_r(i),
                    sop    => root_r.sop and active_r(i),
                    eop    => root_r.eop and active_r(i));
    end generate;

end architecture tlp_rx_dmx;
