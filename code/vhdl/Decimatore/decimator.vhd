library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity decimatore is
    generic (
        N : positive := 4  -- fattore di decimazione
    );
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        din       : in  std_logic_vector(15 downto 0);
        din_valid : in  std_logic;
        dout      : out std_logic_vector(15 downto 0);
        dout_valid: out std_logic
    );
end entity decimatore;

architecture rtl of decimatore is
    signal sample_count : integer range 0 to N-1 := 0;
    signal dout_reg     : std_logic_vector(15 downto 0) := (others => '0');
    signal valid_reg    : std_logic := '0';
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                sample_count <= 0;
                dout_reg      <= (others => '0');
                valid_reg     <= '0';
            else
                valid_reg <= '0';

                if din_valid = '1' then
                    if sample_count = N-1 then
                        dout_reg      <= din;
                        valid_reg     <= '1';
                        sample_count  <= 0;
                    else
                        sample_count <= sample_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    dout       <= dout_reg;
    dout_valid <= valid_reg;

end architecture rtl;