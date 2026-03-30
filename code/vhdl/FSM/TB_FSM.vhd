library ieee;
use ieee.std_logic_1164.all;

entity tb_traffic_light_fsm is
end entity tb_traffic_light_fsm;

architecture tb of tb_traffic_light_fsm is

    signal clk          : std_logic := '0';
    signal rst_n        : std_logic := '0';

    signal roadA_red    : std_logic;
    signal roadA_yellow : std_logic;
    signal roadA_green  : std_logic;

    signal roadB_red    : std_logic;
    signal roadB_yellow : std_logic;
    signal roadB_green  : std_logic;

begin

    dut: entity work.traffic_light_fsm
        port map (
            clk          => clk,
            rst_n        => rst_n,
            roadA_red    => roadA_red,
            roadA_yellow => roadA_yellow,
            roadA_green  => roadA_green,
            roadB_red    => roadB_red,
            roadB_yellow => roadB_yellow,
            roadB_green  => roadB_green
        );

    -- Clock generation
    clk_process: process
    begin
        while true loop
            clk <= '0';
            wait for 5 ns;
            clk <= '1';
            wait for 5 ns;
        end loop;
    end process;

    -- Stimulus
    stim_proc: process
    begin
        rst_n <= '0';
        wait for 12 ns;
        rst_n <= '1';

        wait for 80 ns;
        wait;
    end process;

end architecture tb;