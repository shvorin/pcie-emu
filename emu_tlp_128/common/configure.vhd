-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- The place to configure everything, including selection of network
-- implementation.

use work.util;


package configure is
    ---------------------------------------------------------------------------
    -- 0. Data parameters
    ---------------------------------------------------------------------------

    -- Flit width; this not actually configurable value. ;)
    constant flitWidth : positive := 64;

    -- ACTUAL maximum value of a packet length (restricted by FIFOs
    -- capacities). Compare with net_flit.pktlen_width (POTENTIAL maximum).
    -- NB: 'pktlen' is the number of all flits of a packet INCLUDING header.
    constant max_pktlen : positive := 128;  -- i.e 1kB

    ---------------------------------------------------------------------------
    -- 1. Network parameters
    ---------------------------------------------------------------------------

    -- ACTUAL number of valid ports. Compare with net_flit.portId_width .
    constant valid_nPorts : positive := 2;

    -- Some nodes have exactly this numbers of injectors and ejectors, other node
    -- have none. See also topology description.
    constant ports_perNode : positive := 2;

    -- A number of implemented networks with common interface.
    type network_architectures_t is (shortcut, passthru, t3d_network, t3d_node);

    -- Select a sertain network type among implemented networks.
    constant network_selected : network_architectures_t := t3d_node;

    -- FIXME: a workaround of VHDL compilers bug
    function eq(a, b : network_architectures_t) return boolean;

    -- an auxillary function
    function eval_nNodes return positive;

    -- Number of nodes in the selected network.
    constant nNodes : positive :=
        -- FIXME: workaround of a GHDL bug
        2
        -- eval_nNodes
;

    ---------------------------------------------------------------------------
    -- 1.1. Bypass network configuration. Those valuse used when bypass network
    -- is selected, otherwise ignored.
    ---------------------------------------------------------------------------
    constant nNodes_bypass : positive := 10;

    ---------------------------------------------------------------------------
    -- 1.2. 3d torus network configuration. Those valuse used when t3d network
    -- is selected, otherwise ignored.
    ---------------------------------------------------------------------------
    constant xSize : positive := 2;
    constant ySize : positive := 1;
    constant zSize : positive := 1;

    ---------------------------------------------------------------------------
    -- 2. Buffers
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    -- 2.1. Interface buffers used to be read/written by CPU (all measured in
    -- flits) 
    ---------------------------------------------------------------------------

    constant down_seg_logfsize : natural := 11 + 1;
    constant up_seg_logfsize   : natural := 19 + 1;

    constant down_head_logfcapacity : natural := 10;  -- 8kB
    constant down_body_logfcapacity : natural := 11;  -- 16kB

    constant up_head_logfcapacity : natural := 16;
    constant up_body_logfcapacity : natural := 17;  -- FIXME: ad hoc

    -- defines cell size (measured in flits) for efficient data passing method
    constant cell_logsize : positive := 3;

    -- FIXME: this should be declared somewhere else
    constant cell_size : positive := 2 ** cell_logsize;

    ---------------------------------------------------------------------------
    -- 2.2. Internal network buffers
    ---------------------------------------------------------------------------

    constant ivc_buffer_bubble_capacity : integer := 10;

    ---------------------------------------------------------------------------
    -- 3. Misc
    ---------------------------------------------------------------------------

    -- the width of credit increments
    constant creditWidth : positive := 8;

    -- maximum TLP packet length used in ejector
    constant max_tlplen : positive := 8;

    constant dbg_t3dnode : boolean := true;
    constant dbg_buffers : boolean := true;
    constant dbg_credit  : boolean := false;  -- FIXME: seems to be broken; don't use

    -- makes sense for t3d_node mode only
    -- value of -1 means disabled PHY
    constant map_dir2PHY : util.integer_array(0 to 5) := (
        0      => 1,                    -- +X
        3      => 0,                    -- -X
        1      => 3,                    -- +Y
        4      => 2,                    -- -Y
        others => -1);

    -- for pass-thru mode: which ports are to be connected to PHYs
    constant passthru_PHYs : util.boolean_array(0 to configure.valid_nPorts - 1) := (
--        0      => true,
        others => false);

    -- for t3d_network mode: which ports are to be connected to PHYs
    constant map_nodedir2PHY_o : util.integer_array2(0 to nNodes - 1, 0 to 5) :=
        (  --0      => (0 => 0, 3 => 1, others => -1),
            others => (others => -1));

    constant map_nodedir2PHY_i : util.integer_array2(0 to nNodes - 1, 0 to 5) :=
        (  --1      => (0 => 1, 3 => 0, others => -1),
            others => (others => -1));


end configure;


package body configure is
    function eval_nNodes return positive is
    begin
        assert false report "eval_nNodes implementation is broken";

        return 0;
--        case network_selected is
--            when passthru_network =>
--                return nNodes_bypass;
--            when t3d_network =>
--                return xSize * ySize * zSize;
--        end case;
    end;

    -- constant nNodes : positive := eval_nNodes;

    function eq(a, b : network_architectures_t) return boolean is
    begin
        return a = b;
    end;

end configure;
