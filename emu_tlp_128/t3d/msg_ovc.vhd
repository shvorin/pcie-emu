-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.tlp_flit.all;
use work.msg_flit.all;
use work.net_flit.all;
use work.vdata.all;
use work.util.all;
use work.credit.all;
use work.configure;


entity msg_ovc is
    generic (
        nIVCs    : integer;
        my_ovcId : integer);

    port (
        clk, reset  : in  std_logic;    -- asynchronous reset (active high)
        --
        has_bubble  : in  boolean;
        rxcredit    : in  credit_t;
        --
        reqs        : in  std_logic_vector(0 to nIVCs - 1);
        acks        : out std_logic_vector(0 to nIVCs - 1);
        --
        vdata_i_all : in  vflit_vector(0 to nIVCs - 1);
        vdata_o     : out vflit_t);
end msg_ovc;


architecture msg_ovc of msg_ovc is
    subtype i_range is integer range 0 to nIVCs - 1;
    subtype stdl_i_vector is std_logic_vector(i_range);

    function fmux(sel    : std_logic_vector(i_range);
                  inputs : vflit_vector) return vflit_t
    is
        variable result : vflit_t := ((others => '0'), false);
    begin
        for i in sel'range loop
            if sel(i) = '1' then
                result := inputs(i);
            end if;
        end loop;

        return result;
    end;

    signal acks0      : stdl_i_vector;
    signal isSelected : boolean;
    signal sop        : boolean;

    -- NB: measured in packets, not flits!
    signal pkt_tx, pkt_size : credit_t;

    signal bubble_space : bubble_space_t;

    -- whether this OVC is connecter to other router not PE
    constant useDirect : boolean := my_ovcId >= configure.ports_perNode;

    function pkt_space(n : integer) return integer is
    begin
        return configure.ivc_buffer_bubble_capacity - n;
    end;
    
begin
    arbiter_dir : entity work.arbiter_dir
        generic map (
            nCompetitors => nIVCs,
            useDirect    => useDirect,
            direct       => my_ovcID)

        port map (
            clk          => clk,
            reset        => reset,
            --
            bubble_space => bubble_space,
            sop          => sop,
            --
            req          => reqs(i_range),
            ack          => acks0(i_range));

    -- result
    acks    <= acks0;
    vdata_o <= fmux(acks0(i_range), vdata_i_all(i_range));

    pkt_tx <= (others => '0') when reset = '1' else
              pkt_tx + 1 when rising_edge(clk) and sop; -- FIXME: also check dv and ready (?)

    pkt_size <= pkt_tx - rxcredit;

    toPE : if not useDirect generate
        bubble_space <= none when not has_bubble else one;
    end generate;

    toRouter : if useDirect generate
        bubble_space <=
            none when not has_bubble or pkt_size >= pkt_space(1) else
            one  when pkt_size >= pkt_space(2) else
            many;
    end generate;
end msg_ovc;
