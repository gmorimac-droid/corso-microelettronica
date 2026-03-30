library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity traffic_light_fsm_timed is
    generic (
        GREEN_TIME  : positive := 5;
        YELLOW_TIME : positive := 2
    );
    port (
        clk          : in  std_logic;
        rst_n        : in  std_logic;

        roadA_red    : out std_logic;
        roadA_yellow : out std_logic;
        roadA_green  : out std_logic;

        roadB_red    : out std_logic;
        roadB_yellow : out std_logic;
        roadB_green  : out std_logic
    );
end entity traffic_light_fsm_timed;

architecture rtl of traffic_light_fsm_timed is

    type state_t is (A_GREEN, A_YELLOW, B_GREEN, B_YELLOW);
    signal current_state, next_state : state_t;

    signal timer_cnt : natural := 0;
    signal timer_max : natural := 0;

begin

    -- Timer target depends on state
    process(current_state)
    begin
        case current_state is
            when A_GREEN | B_GREEN =>
                timer_max <= GREEN_TIME - 1;

            when A_YELLOW | B_YELLOW =>
                timer_max <= YELLOW_TIME - 1;
        end case;
    end process;

    -- State register + timer
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            current_state <= A_GREEN;
            timer_cnt     <= 0;
        elsif rising_edge(clk) then
            if timer_cnt = timer_max then
                current_state <= next_state;
                timer_cnt     <= 0;
            else
                timer_cnt     <= timer_cnt + 1;
            end if;
        end if;
    end process;

    -- Next-state logic
    process(current_state)
    begin
        case current_state is
            when A_GREEN =>
                next_state <= A_YELLOW;

            when A_YELLOW =>
                next_state <= B_GREEN;

            when B_GREEN =>
                next_state <= B_YELLOW;

            when B_YELLOW =>
                next_state <= A_GREEN;
        end case;
    end process;

    -- Output logic (Moore FSM)
    process(current_state)
    begin
        roadA_red    <= '0';
        roadA_yellow <= '0';
        roadA_green  <= '0';
        roadB_red    <= '0';
        roadB_yellow <= '0';
        roadB_green  <= '0';

        case current_state is
            when A_GREEN =>
                roadA_green <= '1';
                roadB_red   <= '1';

            when A_YELLOW =>
                roadA_yellow <= '1';
                roadB_red    <= '1';

            when B_GREEN =>
                roadA_red   <= '1';
                roadB_green <= '1';

            when B_YELLOW =>
                roadA_red    <= '1';
                roadB_yellow <= '1';
        end case;
    end process;

end architecture rtl;