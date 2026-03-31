library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_decimatore is
end entity;

architecture sim of tb_decimatore is
    constant CLK_PERIOD : time := 10 ns;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal din        : std_logic_vector(15 downto 0) := (others => '0');
    signal din_valid  : std_logic := '0';
    signal dout       : std_logic_vector(15 downto 0);
    signal dout_valid : std_logic;

begin

    clk <= not clk after CLK_PERIOD/2;

    uut: entity work.decimatore
        generic map (
            N => 4
        )
        port map (
            clk        => clk,
            rst        => rst,
            din        => din,
            din_valid  => din_valid,
            dout       => dout,
            dout_valid => dout_valid
        );

    stim_proc: process
    begin
        rst <= '1';
        din_valid <= '0';
        wait for 30 ns;
        rst <= '0';
        din_valid <= '1';

        for i in 0 to 15 loop
            din <= std_logic_vector(to_unsigned(i, 16));
            wait for CLK_PERIOD;
        end loop;

        din_valid <= '0';
        wait;
    end process;

end architecture sim;