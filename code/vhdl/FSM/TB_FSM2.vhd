library ieee;
use ieee.std_logic_1164.all;

entity tb_traffic_light_fsm_timed is
end entity tb_traffic_light_fsm_timed;

architecture tb of tb_traffic_light_fsm_timed is

    constant GREEN_TIME  : positive := 4;
    constant YELLOW_TIME : positive := 2;

    signal clk          : std_logic := '0';
    signal rst_n        : std_logic := '0';

    signal roadA_red    : std_logic;
    signal roadA_yellow : std_logic;
    signal roadA_green  : std_logic;

    signal roadB_red    : std_logic;
    signal roadB_yellow : std_logic;
    signal roadB_green  : std_logic;

begin

    dut: entity work.traffic_light_fsm_timed
        generic map (
            GREEN_TIME  => GREEN_TIME,
            YELLOW_TIME => YELLOW_TIME
        )
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

        wait for 250 ns;
        wait;
    end process;

    -- Basic checks
    check_proc: process
    begin
        wait until rst_n = '1';
        wait until rising_edge(clk);

        while true loop
            wait until rising_edge(clk);

            -- Mai due verdi contemporaneamente
            assert not (roadA_green = '1' and roadB_green = '1')
                report "ERROR: both roads green at the same time"
                severity error;

            -- Ogni strada deve avere una sola luce attiva
            assert not ((roadA_red = '1' and roadA_yellow = '1') or
                        (roadA_red = '1' and roadA_green  = '1') or
                        (roadA_yellow = '1' and roadA_green = '1'))
                report "ERROR: invalid Road A light combination"
                severity error;

            assert not ((roadB_red = '1' and roadB_yellow = '1') or
                        (roadB_red = '1' and roadB_green  = '1') or
                        (roadB_yellow = '1' and roadB_green = '1'))
                report "ERROR: invalid Road B light combination"
                severity error;
        end loop;
    end process;

end architecture tb;