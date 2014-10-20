-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

use work.types.all;
use work.util.all;

-- ast stands for Avalon-ST
package ast256 is
    type ast256half_t is record
        data     : qqword;
        sop, eop : std_logic;
        empty    : std_logic;
    end record;

    type half_idx is (lo, hi);
    type ast256half_array is array (half_idx) of ast256half_t;

    type ast256mp_t is record
        half  : ast256half_array;
        valid : std_logic;
    end record;

    function nothing return ast256mp_t;

    subtype ast_t is ast256mp_t;

    type ast_bp_t is record
        ready : std_logic;
    end record;

    type ast_array is array (integer range <>) of ast_t;
    type ast_bp_array is array (integer range <>) of ast_bp_t;

    ---------------------------------------------------------------------------

    constant ast_raw_width : natural := 256 + 6;
    subtype ast_raw_t is std_logic_vector(ast_raw_width - 1 downto 0);

    function combine(a : ast_t) return ast_raw_t;
    function parse(r   : ast_raw_t; valid : std_logic) return ast_t;

    ---------------------------------------------------------------------------

    component ast_io
        port (
            ast_rx       : in  ast_t;
            ast_tx       : out ast_t;
            ast_tx_bp    : in  ast_bp_t;
            rx_st_bardec : in  std_logic_vector(7 downto 0);
            --
            clk          : in  std_logic;
            reset        : in  std_logic);
    end component;
end ast256;

package body ast256 is
    function nothing return ast256half_t is
    begin
        return (data   => (others => 'X'),
                others => '0');
    end;

    function nothing return ast256mp_t is
    begin
        return ((nothing, nothing), '0');
    end;

    subtype asthalf_raw_t is std_logic_vector(128 + 3 - 1 downto 0);

    function combine(h : ast256half_t) return asthalf_raw_t is
    begin
        return h.data & h.sop& h.eop & h.empty;
    end;

    function parse(r : asthalf_raw_t) return ast256half_t is
    begin
        return (data => r(128 + 3 - 1 downto 3),
                sop  => r(2), eop => r(1), empty => r(0));
    end;

    function refine(h : ast256half_t; valid : std_logic) return ast256half_t is
    begin
        return (
            data  => h.data,
            sop   => h.sop and valid,
            eop   => h.eop and valid,
            empty => h.empty);
    end;

    function combine(a : ast_t) return ast_raw_t is
    begin
        return combine(a.half(lo)) & combine(a.half(hi));
    end;

    function parse(r : ast_raw_t; valid : std_logic) return ast_t is
    begin
        return (
            half  => (refine(parse(r(ast_raw_width - 1 downto ast_raw_width/2)), valid),
                      refine(parse(r(ast_raw_width/2 - 1 downto 0)), valid)),
            valid => valid);
    end;
end ast256;
