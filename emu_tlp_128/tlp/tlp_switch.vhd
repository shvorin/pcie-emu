-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

LIBRARY ieee;
   USE ieee.std_logic_1164.all;
   USE ieee.std_logic_arith.all;
   USE ieee.std_logic_unsigned.all;
   USE ieee.std_logic_misc.all;
   USE work.tlp_package.all;
   
entity tlp_switch is
generic (
	CHANNEL_NUM : natural := 1
);
port (
	clk         : in std_logic;
	reset       : in std_logic;

    i_tlp_root : in i_tlp_t;
    o_tlp_root : out o_tlp_t;

    ---------------------------------------------------------------------------
    
    i_tlp_chld : out i_tlp_array(0 to CHANNEL_NUM - 1);
    o_tlp_chld : in o_tlp_array(0 to CHANNEL_NUM - 1));
end entity tlp_switch;

architecture switch of tlp_switch is

	signal ej_ready_1 : std_logic;
	signal tx_count : natural range 0 to 2**9 - 1;

	signal current_ch, current_ch_1 : natural range 0 to CHANNEL_NUM - 1 := 0;
	signal old_ch : natural range 0 to CHANNEL_NUM := 0;

	function next_ch (old_ch : natural range 0 to CHANNEL_NUM - 1;
                      o_tlp_chld : o_tlp_array(0 to CHANNEL_NUM - 1)) return natural is
		variable i, n : natural range 0 to CHANNEL_NUM - 1;
	begin
		if old_ch = CHANNEL_NUM - 1 then
			i := 0;
		else
			i := old_ch + 1;
		end if;
		n := 0;
		while n < CHANNEL_NUM - 1 and o_tlp_chld(i).tx_dvalid = '0' loop
			if i = CHANNEL_NUM - 1 then
				i := 0;
			else
				i := i + 1;
			end if;
			n := n + 1;
		end loop;
		return i;
	end function;

begin

	process (clk, reset)
	begin
		if reset = '1' then
			ej_ready_1 <= '0';
--			current_ch_1 <= 0;
			current_ch <= 0;
			tx_count <= 0;
--			old_ch <= 0;
		elsif rising_edge(clk) then
			ej_ready_1 <= i_tlp_root.ej_ready;
--			current_ch_1 <= current_ch;
--			if ej_ready_1 = '1' then
			if i_tlp_root.ej_ready = '1' then
				if tx_count = 0 then
					if o_tlp_chld(current_ch).tx_dvalid = '1' then
						tx_count <= conv_integer(o_tlp_chld(current_ch).tx_data(8 downto 0));
						if or_reduce(o_tlp_chld(current_ch).tx_data(8 downto 0)) = '0' then
--							old_ch <= current_ch;
							current_ch <= next_ch(current_ch, o_tlp_chld);
						else
--							old_ch <= CHANNEL_NUM;
						end if;
					else
						current_ch <= next_ch(current_ch, o_tlp_chld);
					end if;
				elsif tx_count = 1 then
					tx_count <= 0;
--					old_ch <= current_ch;
					current_ch <= next_ch(current_ch, o_tlp_chld);
				else
					tx_count <= tx_count - 1;
				end if;
			end if;
		end if;
	end process;

	o_tlp_root.tx_data <= o_tlp_chld(current_ch).tx_data; 
	o_tlp_root.tx_dvalid <= o_tlp_chld(current_ch).tx_dvalid;

--	current_ch <= current_ch_1 when old_ch = CHANNEL_NUM else next_ch(old_ch, ch_tx_dvalid);
--	current_ch <= 0;

	ch_gen: for i in 0 to CHANNEL_NUM - 1 generate
	   i_tlp_chld(i).rx_data <= i_tlp_root.rx_data;
	   i_tlp_chld(i).rx_dvalid <= i_tlp_root.rx_dvalid;
	   i_tlp_chld(i).rx_sop <= i_tlp_root.rx_sop;
	   i_tlp_chld(i).rx_eop <= i_tlp_root.rx_eop;
	   i_tlp_chld(i).ej_ready <= i_tlp_root.ej_ready when i = current_ch else '0';
--	   ch_clk(i) <= clk;
--	   ch_reset(i) <= reset;
	end generate ch_gen;

end architecture switch;
