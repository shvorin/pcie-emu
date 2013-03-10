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
use work.t3d_topology.all;
use work.configure;


entity msg_ivc is
    generic (
        nOVCs    : integer;
        my_ivcId : integer);

    port (
        clk, reset : in  std_logic;        -- asynchronous reset (active high)
        --
        size3      : in  integer_3vector;  -- FIXME: type
        my_node    : in  node_t;
        --
        -- FIFO input iface
        vdata_i    : in  vflit_t;
        ready_i    : out boolean;
        --
        -- output iface
        vdata_o    : out vflit_t;
        --
        reqs       : out std_logic_vector(0 to nOVCs - 1);
        ack        : in  std_logic);
end msg_ivc;


architecture msg_ivc of msg_ivc is
--    constant size3 : integer_3vector := (configure.xSize, configure.ySize, configure.zSize);

    subtype o_range is integer range 0 to nOVCs - 1;
    subtype stdl_o_vector is std_logic_vector(o_range);

    signal sop, eop, allow, eop_ff, ready : boolean;
    signal req                            : std_logic;

    signal vdata_1  : vflit_t;
    signal net_head : net_head_t;

    function mkreqs(size3 : integer_3vector; my_node : node_t;
                    dst   : portAddr_t) return std_logic_vector is
        constant dirbits : dirbits_t := mk_dirbits(size3, decompose(my_node), decompose(dst.node));

        subtype ports_range is integer range 0 to configure.ports_perNode - 1;

        variable pe_ports : std_logic_vector(ports_range);

        -- TODO: move this somewhere to util
        function decode(portId : o_range) return std_logic_vector is
            variable result : std_logic_vector(ports_range);
            
        begin
            -- FIXME: this may consume too much...
            for i in ports_range loop
                result(i) := to_stdl(portId = i);
            end loop;

            -- TODO: somehow treat invalid portId

            return result;
        end;

    begin
        if or_reduce(dirbits) then
            pe_ports := (others => '0');
        else
            pe_ports := decode(dst.portId);
        end if;

        return pe_ports & unary_log(dirbits);
    end;
    
begin
    arbiter_client : entity work.msg_arbiter_client
        port map (
            clk   => clk,
            reset => reset,
            --
            sop   => sop,
            eop   => eop,
            --
            req   => req,
            ack   => ack,
            --
            allow => allow);

    flit_counter : entity work.net_flit_counter
        port map (
            clk     => clk,
            reset   => reset,
            --
            vdata_i => vdata_i,
            vdata_o => vdata_1,
            ready   => ready,

            sop  => sop,
            eop  => eop,
            head => net_head);        

    ready <= allow or not vdata_1.dv;

    eop_ff <= false when reset = '1' else eop when rising_edge(clk) and vdata_1.dv;

    -- outputs
    reqs         <= mkreqs(size3, my_node, net_head.dst) and req;
    ready_i      <= ready;
    vdata_o.data <= vdata_1.data;
    vdata_o.dv   <= vdata_1.dv
                    -- FIXME: this is workaround...
                    and not eop_ff;
    
end msg_ivc;
