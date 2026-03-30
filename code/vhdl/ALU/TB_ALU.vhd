library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_alu is
end entity tb_alu;

architecture tb of tb_alu is

    constant DATA_WIDTH : integer := 8;

    signal a        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal b        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal op       : std_logic_vector(2 downto 0);

    signal result   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal carry    : std_logic;
    signal overflow : std_logic;
    signal zero     : std_logic;

    procedure check_result(
        constant exp_result   : in std_logic_vector(DATA_WIDTH-1 downto 0);
        constant exp_carry    : in std_logic;
        constant exp_overflow : in std_logic;
        constant exp_zero     : in std_logic
    ) is
    begin
        wait for 1 ns;
        assert result = exp_result
            report "ERROR: result mismatch"
            severity error;
        assert carry = exp_carry
            report "ERROR: carry mismatch"
            severity error;
        assert overflow = exp_overflow
            report "ERROR: overflow mismatch"
            severity error;
        assert zero = exp_zero
            report "ERROR: zero mismatch"
            severity error;
    end procedure;

begin

    dut: entity work.alu
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            a        => a,
            b        => b,
            op       => op,
            result   => result,
            carry    => carry,
            overflow => overflow,
            zero     => zero
        );

    stim_proc: process
    begin
        -- ADD
        a <= x"05"; b <= x"03"; op <= "000";
        check_result(x"08", '0', '0', '0');

        -- ADD with carry
        a <= x"FF"; b <= x"01"; op <= "000";
        check_result(x"00", '1', '0', '1');

        -- ADD with signed overflow
        a <= x"7F"; b <= x"01"; op <= "000";
        check_result(x"80", '0', '1', '0');

        -- SUB
        a <= x"09"; b <= x"04"; op <= "001";
        check_result(x"05", '0', '0', '0');

        -- AND
        a <= x"A5"; b <= x"3C"; op <= "010";
        check_result(x"24", '0', '0', '0');

        -- OR
        a <= x"A5"; b <= x"3C"; op <= "011";
        check_result(x"BD", '0', '0', '0');

        -- XOR
        a <= x"A5"; b <= x"3C"; op <= "100";
        check_result(x"99", '0', '0', '0');

        -- NOT
        a <= x"0F"; b <= x"00"; op <= "101";
        check_result(x"F0", '0', '0', '0');

        -- SHL
        a <= x"81"; b <= x"00"; op <= "110";
        check_result(x"02", '1', '0', '0');

        -- SHR
        a <= x"81"; b <= x"00"; op <= "111";
        check_result(x"40", '1', '0', '0');

        -- ZERO
        a <= x"55"; b <= x"55"; op <= "100";
        check_result(x"00", '0', '0', '1');

        report "TEST PASSED" severity note;
        wait;
    end process;

end architecture tb;