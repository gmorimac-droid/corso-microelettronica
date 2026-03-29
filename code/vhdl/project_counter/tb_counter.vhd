library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_counter is
end tb_counter;

architecture sim of tb_counter is

  signal clk    : STD_LOGIC := '0';
  signal reset  : STD_LOGIC := '0';
  signal enable : STD_LOGIC := '0';
  signal q      : STD_LOGIC_VECTOR(3 downto 0);

begin

  dut: entity work.counter
    port map (
      clk    => clk,
      reset  => reset,
      enable => enable,
      q      => q
    );

  -- Clock generator: periodo 10 ns
  clk_process : process
  begin
    while now < 200 ns loop
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    end loop;
    wait;
  end process;

  -- Stimoli
  stim_proc : process
  begin
    -- reset iniziale
    reset  <= '1';
    enable <= '0';
    wait for 12 ns;

    -- conta
    reset  <= '0';
    enable <= '1';
    wait for 80 ns;

    -- pausa
    enable <= '0';
    wait for 20 ns;

    -- riprende a contare
    enable <= '1';
    wait for 40 ns;

    -- nuovo reset
    reset <= '1';
    wait for 10 ns;
    reset <= '0';

    wait for 30 ns;
    wait;
  end process;

end sim;
