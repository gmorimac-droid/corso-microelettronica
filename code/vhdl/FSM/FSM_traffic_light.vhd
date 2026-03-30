library ieee;
use ieee.std_logic_1164.all;

entity traffic_light_fsm is
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
end entity traffic_light_fsm;

architecture rtl of traffic_light_fsm is

    type state_t is (A_GREEN, A_YELLOW, B_GREEN, B_YELLOW);
    signal current_state, next_state : state_t;

begin

    -- State register
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            current_state <= A_GREEN;
        elsif rising_edge(clk) then
            current_state <= next_state;
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
        -- Default values
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