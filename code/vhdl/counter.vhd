library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter is
  Port (
    clk   : in  STD_LOGIC;
    reset : in  STD_LOGIC;
    q     : out STD_LOGIC_VECTOR(3 downto 0)
  );
end counter;

architecture rtl of counter is
  signal count : unsigned(3 downto 0) := (others => '0');
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        count <= (others => '0');
      else
        count <= count + 1;
      end if;
    end if;
  end process;

  q <= std_logic_vector(count);
end rtl;
