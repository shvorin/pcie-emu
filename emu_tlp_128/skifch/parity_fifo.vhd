-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.flit.all;
use work.vdata.all;
use work.util.all;
use work.configure;


entity parity_fifo is
    generic (
        logfcapacity : natural);

    port (
        clk, reset     : in  std_logic;  -- asynchronous reset (active high)
        --
        -- FPGA FIFO input interface (i.e. RAM iface)
        --
        addr           : in  std_logic_vector(logfcapacity - 1 downto 0);
        di             : in  data_t;
        --
        we             : in  boolean;
        --
        -- rfifo output iface
        --
        vdata_o        : out vflit_t;
        ready_o        : in  boolean;
        cell_is_filled : in  boolean;
        rx_next_cell   : in  boolean;
        rx_value       : out std_logic_vector(31 - 3 - 3 downto 0);
        --
        dbg_rx, dbg_tx : out data_t);
end parity_fifo;


architecture parity_fifo of parity_fifo is
    ---------------------------------------------------------------------------
    -- body, flits

    subtype fptr_range is integer range logfcapacity - 1 downto 0;
    subtype fptr_t is std_logic_vector(fptr_range);

    -- NB: pointer with an extra bit to be passed and kept in registers
    subtype wfptr_range is integer range fptr_range'high + 1 downto fptr_range'low;
    subtype wfptr_t is std_logic_vector(wfptr_range);
    type wfptr_vector is array (integer range <>) of wfptr_t;

    constant fcapacity : natural := 2 ** logfcapacity;
    subtype fsize_range is integer range 0 to fcapacity;

    ---------------------------------------------------------------------------
    -- cells

    constant logccapacity : positive := logfcapacity - configure.cell_logsize;
    constant ccapacity    : positive := 2 ** logccapacity;
    subtype csize_range is integer range 0 to ccapacity;

    subtype cptr_range is integer range logccapacity - 1 downto 0;
    subtype cptr_t is std_logic_vector(cptr_range);

    subtype wcptr_range is integer range cptr_range'high + 1 downto 0;
    subtype wcptr_t is std_logic_vector(wcptr_range);

    ---------------------------------------------------------------------------

    signal tx_wcell, tx_wcell_new : wcptr_t;

    alias tx_cell   : cptr_t is tx_wcell(cptr_range);
    alias tx_parity : std_logic is tx_wcell(wcptr_range'high);

    alias tx_cell_new : cptr_t is tx_wcell_new(cptr_range);

    ---------------------------------------------------------------------------

    subtype addr_hi_range is integer range cptr_range'high + configure.cell_logsize downto cptr_range'low + configure.cell_logsize;

    alias income_cell : cptr_t is addr(addr_hi_range);

    ---------------------------------------------------------------------------

    signal rd_addr, wr_addr : fsize_range;

    signal parity_di, parity_do : std_logic_vector(0 downto 0);

    ---------------------------------------------------------------------------

    -- NB: rx feedback should be represented as 32-bit integer
    signal rx_curr, rx_next, rx_real : std_logic_vector(31 - 3 downto 0);

    alias rx_curr_wcell : wcptr_t is rx_curr(wcptr_range'high + 3 downto wcptr_range'low + 3);

    signal re     : boolean;
    signal nempty : boolean;
    
begin
    ---------------------------------------------------------------------------
    -- 1. Receiving heads
    -- 1.1 RAM: the content of header cells
    
    ram : entity work.ram_sdp
        generic map (
            data_width => data_t'length,
            depth      => fcapacity)

        port map (
            clk     => clk,
            wr_addr => wr_addr,
            rd_addr => rd_addr,
            di      => di,
            do      => vdata_o.data,
            we      => to_stdl(we));

    wr_addr <= conv_integer(addr);
    rd_addr <= conv_integer(rx_real(fptr_range));

    ---------------------------------------------------------------------------
    -- 1.2 RAM: parity bits of header cells (one bit per cell)

    parity_ram : entity work.ram_sdp_reset
        generic map (
            data_width => 1,
            depth      => ccapacity)

        port map (
            clk     => clk,
            reset   => reset,
            wr_addr => conv_integer(income_cell),
            rd_addr => conv_integer(tx_cell_new),
            di      => parity_di,
            do      => parity_do,
            we      => to_stdl(cell_is_filled));

    parity_di(0) <= tx_parity xor to_stdl(income_cell >= tx_cell);

    ---------------------------------------------------------------------------

    -- dff
    tx_wcell <= (others => '0') when reset = '1' else tx_wcell_new when rising_edge(clk);

    tx_wcell_new <= tx_wcell + 1 when not parity_do(0) = tx_parity else tx_wcell;

    ---------------------------------------------------------------------------
    -- rx

    nempty <= tx_wcell /= rx_curr_wcell;  -- FIFO not empty
    re     <= nempty and ready_o;

    rx_curr <= (others => '0') when reset = '1' else
               rx_next when rising_edge(clk) and (re or rx_next_cell);

    rx_next <= align8_down(rx_curr) + 8 when rx_next_cell else
               rx_curr + 1;
    
    rx_real <= rx_next when re else rx_curr;

    ---------------------------------------------------------------------------
    vdata_o.dv <= nempty;

    rx_value <= rx_curr(rx_curr'high downto rx_curr'low + 3);
    
    ---------------------------------------------------------------------------
    -- debug stuff

    dbg_rx <= extend64(rx_curr_wcell);
    dbg_tx <= extend64(tx_wcell);
    
end parity_fifo;
