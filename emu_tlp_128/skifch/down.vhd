-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


-- Downstream address space representation.

library ieee;

use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.tlp_flit.all;
use work.net_flit.all;
use work.util.all;
use work.configure;


package down is
    -- "foffset" is offset measured in flits
    subtype foffset_range is integer range 10 downto 0;  -- 11
    subtype foffset_t is std_logic_vector(foffset_range);

    ---------------------------------------------------------------------------
    -- Mnemo:
    --
    -- ptr: a pointer to FIFO's RAM-based array;
    --
    -- head/body: applicable to a queue of either packet headers or bodies;
    --
    -- f/c: indicates the units being counted, either flits or cells;
    --
    -- w* ("wide"): an extra bit in a pointer to be passed and kept in
    -- registers, this bit is dropped while addressing RAM-based array.
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    -- head, flits

    subtype head_fptr_range is integer range configure.down_head_logfcapacity - 1 downto 0;
    subtype head_fptr_t is std_logic_vector(head_fptr_range);

    -- NB: pointer with an extra bit to be passed and kept in registers
    subtype head_wfptr_range is integer range head_fptr_range'high + 1 downto head_fptr_range'low;
    subtype head_wfptr_t is std_logic_vector(head_wfptr_range);
    type head_wfptr_vector is array (integer range <>) of head_wfptr_t;

    constant head_fcapacity : natural := 2 ** configure.down_head_logfcapacity;
    subtype head_fsize_range is integer range 0 to head_fcapacity;

    ---------------------------------------------------------------------------
    -- head, cells

    constant head_logccapacity : positive := configure.down_head_logfcapacity - configure.cell_logsize;
    constant head_ccapacity    : positive := 2 ** head_logccapacity;
    subtype head_csize_range is integer range 0 to head_ccapacity;

    subtype head_cptr_range is integer range head_logccapacity - 1 downto 0;
    subtype head_cptr_t is std_logic_vector(head_cptr_range);

    subtype head_wcptr_range is integer range head_cptr_range'high + 1 downto 0;
    subtype head_wcptr_t is std_logic_vector(head_wcptr_range);

    ---------------------------------------------------------------------------
    -- body, flits

    subtype body_fptr_range is integer range configure.down_body_logfcapacity - 1 downto 0;
    subtype body_fptr_t is std_logic_vector(body_fptr_range);

    -- NB: pointer with an extra bit to be passed and kept in registers
    subtype body_wfptr_range is integer range body_fptr_range'high + 1 downto body_fptr_range'low;
    subtype body_wfptr_t is std_logic_vector(body_wfptr_range);
    type body_wfptr_vector is array (integer range <>) of body_wfptr_t;

    constant body_fcapacity : natural := 2 ** configure.down_body_logfcapacity;
    subtype body_fsize_range is integer range 0 to body_fcapacity;

    ---------------------------------------------------------------------------
    -- body, cells

    constant body_logccapacity : positive := configure.down_body_logfcapacity - configure.cell_logsize;
    constant body_ccapacity    : positive := 2 ** body_logccapacity;
    subtype body_csize_range is integer range 0 to body_ccapacity;

    subtype body_cptr_range is integer range body_logccapacity - 1 downto 0;
    subtype body_cptr_t is std_logic_vector(body_cptr_range);

    subtype body_wcptr_range is integer range body_cptr_range'high + 1 downto 0;
    subtype body_wcptr_t is std_logic_vector(body_wcptr_range);

end down;
