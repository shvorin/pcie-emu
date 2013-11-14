-- Copyright (c) 2011-2014, Ailamazyan Program Systems Institute (Russian             
-- Academy of Science). See COPYING in top-level directory.

-- Toplevel module with empty interface used for emulation via GHDL.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.util.all;
use work.tlp_package.all;
use work.tlp256;
use work.ast256.all;

entity emu_top256 is
end emu_top256;


architecture emu_top256 of emu_top256 is
    constant period : time := 1 ns;

    signal clk, reset : std_logic;

    signal ast_rx, ast_tx : ast_t;
    signal ast_tx_bp      : ast_bp_t;
    signal rx_st_bardec   : std_logic_vector(7 downto 0);

    -- data representation for foreing calls
    type foreign_tlp256_data_t is array (integer range 0 to 7) of integer;

    type foreign_ast is record
        data  : foreign_tlp256_data_t;
        valid : std_logic;
        sop   : std_logic;
        eop   : std_logic;
        empty : std_logic_vector(1 downto 0);
    end record;

    function wrap(data : tlp256.data_t) return foreign_tlp256_data_t is
        variable result : foreign_tlp256_data_t;
    begin
        for i in result'range loop
            result(i) := conv_integer(data(32*(i+1) - 1 downto 32*i));
        end loop;

        return result;
    end;

    function unwrap(a : foreign_tlp256_data_t) return tlp256.data_t is
        variable result : tlp256.data_t;
    begin
        for i in a'range loop
            result(32*(i+1) - 1 downto 32*i) := conv_std_logic_vector(a(i), 32);
        end loop;

        return result;
    end;

    function wrap(a : ast_t) return foreign_ast is
    begin
        return (wrap(a.data), a.valid, a.sop, a.eop, a.empty);
    end;

    function unwrap(f : foreign_ast) return ast_t is
    begin
        return (unwrap(f.data), f.valid, f.sop, f.eop, f.empty);
    end;

    -- About linking with foreign functions see
    -- http://ghdl.free.fr/ghdl/Restrictions-on-foreign-declarations.html

    procedure line256_up(foreign_ast_tx : foreign_ast)
    is
    begin
        assert false severity failure;
    end;

    attribute foreign of line256_up : procedure is "VHPIDIRECT line256_up";

    -- NB: corresponding C prototype is:
    -- void line256_down(struct scalar_params *, ast256_t *ast_t, ast_bp_t *ast_bp_t)
    procedure line256_down(bar_num        : out integer;
                           foreign_ast_rx : out foreign_ast;
                           ast_tx_bp      : out ast_bp_t)
    is
    begin
        assert false severity failure;
    end;

    attribute foreign of line256_down : procedure is "VHPIDIRECT line256_down";

begin
    cg : entity work.clock_gen
        generic map (period)
        port map (clk, reset);

    app : ast_ext_io
        port map (
            clk   => clk,
            reset => reset,

            rx           => ast_rx,
            tx           => ast_tx,
            tx_bp        => ast_tx_bp,
            rx_st_bardec => rx_st_bardec);

    data_down : process (clk, reset)
        variable v_bar_num      : integer;
        variable foreign_ast_rx : foreign_ast;
        variable v_ast_tx_bp    : ast_bp_t;

        function decode(bar_num : integer) return std_logic_vector is
            variable result: std_logic_vector(7 downto 0) := (others => '0');
        begin
            for i in result'range loop
                if bar_num = i then
                    result(i) := '1';
                end if;
            end loop;

            return result;
        end;
    begin
        if reset = '1' then
            ast_rx    <= nothing;
            ast_tx_bp <= (ready => '0');
        elsif rising_edge(clk) then
            line256_down(v_bar_num, foreign_ast_rx, v_ast_tx_bp);

            ast_rx       <= unwrap(foreign_ast_rx);
            ast_tx_bp    <= v_ast_tx_bp;
            rx_st_bardec <= decode(v_bar_num);
        end if;
    end process;

    data_up : process (clk)
    begin
        if rising_edge(clk) then
            line256_up(wrap(ast_tx));
        end if;
    end process;
    
end emu_top256;
