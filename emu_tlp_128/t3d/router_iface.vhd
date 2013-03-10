-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- An abstract generic router inteface.

library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.stdl_matrix.all;
use work.util.all;
use work.credit.all;
use work.net_flit.node_t;
use work.rld.all;


entity router_iface is
    generic (
        gdata_i_width   : integer;
        gdata_o_width   : integer;
        nIVCs           : integer;
        nOVCs           : integer;
        default_my_node : node_t);

    port (
        clk, reset     : in  std_logic;  -- asynchronous reset (active high)
        --
        -- input iface
        --
        gdata_i_mat    : in  stdl_matrix(0 to nIVCs - 1, gdata_i_width - 1 downto 0);
        ready_i_all    : out boolean_array(0 to nIVCs - 1);
        --
        -- output iface
        --
        gdata_o_mat    : out stdl_matrix(0 to nOVCs - 1, gdata_o_width - 1 downto 0);
        has_bubble_all : in  boolean_array(0 to nOVCs - 1);
        rxcredit_all   : in  credit_array(0 to nOVCs - 1);
        --
        -- RAM-like device iface for control
        --
        i_rld_ctrl     : in  i_rld_t;
        o_rld_ctrl     : out o_rld_t);

end router_iface;
