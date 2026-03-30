library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fifo_sync is
end entity tb_fifo_sync;

architecture tb of tb_fifo_sync is

    constant DATA_WIDTH : integer := 8;
    constant DEPTH      : integer := 8;
    constant ADDR_WIDTH : integer := 3;

    signal clk      : std_logic := '0';
    signal rst_n    : std_logic := '0';
    signal write_en : std_logic := '0';
    signal read_en  : std_logic := '0';
    signal data_in  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    signal data_out : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal full     : std_logic;
    signal empty    : std_logic;

begin

    dut: entity work.fifo_sync
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            DEPTH      => DEPTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            clk      => clk,
            rst_n    => rst_n,
            write_en => write_en,
            read_en  => read_en,
            data_in  => data_in,
            data_out => data_out,
            full     => full,
            empty    => empty
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
        write_en <= '0';
        read_en <= '0';
        data_in <= (others => '0');

        wait for 12 ns;
        rst_n <= '1';

        -- Write 4 values
        wait until rising_edge(clk);
        write_en <= '1';
        data_in  <= x"11";

        wait until rising_edge(clk);
        data_in <= x"22";

        wait until rising_edge(clk);
        data_in <= x"33";

        wait until rising_edge(clk);
        data_in <= x"44";

        wait until rising_edge(clk);
        write_en <= '0';

        -- Read 2 values
        wait until rising_edge(clk);
        read_en <= '1';

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        read_en <= '0';

        -- Fill FIFO
        wait until rising_edge(clk);
        write_en <= '1';
        data_in  <= x"55";

        wait until rising_edge(clk);
        data_in <= x"66";

        wait until rising_edge(clk);
        data_in <= x"77";

        wait until rising_edge(clk);
        data_in <= x"88";

        wait until rising_edge(clk);
        data_in <= x"99";

        wait until rising_edge(clk);
        data_in <= x"AA";

        wait until rising_edge(clk);
        write_en <= '0';

        -- Overflow attempt
        wait until rising_edge(clk);
        write_en <= '1';
        data_in  <= x"FF";

        wait until rising_edge(clk);
        write_en <= '0';

        -- Read everything
        wait until rising_edge(clk);
        read_en <= '1';

        for i in 0 to 9 loop
            wait until rising_edge(clk);
        end loop;

        read_en <= '0';

        -- Underflow attempt
        wait until rising_edge(clk);
        read_en <= '1';

        wait until rising_edge(clk);
        read_en <= '0';

        wait for 20 ns;
        wait;
    end process;

end architecture tb;