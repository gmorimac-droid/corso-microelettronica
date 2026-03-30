library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    generic (
        DATA_WIDTH : integer := 8
    );
    port (
        a        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        b        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        op       : in  std_logic_vector(2 downto 0);

        result   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        carry    : out std_logic;
        overflow : out std_logic;
        zero     : out std_logic
    );
end entity alu;

architecture rtl of alu is
begin

    process(a, b, op)
        variable temp_ext : unsigned(DATA_WIDTH downto 0);
        variable a_u      : unsigned(DATA_WIDTH-1 downto 0);
        variable b_u      : unsigned(DATA_WIDTH-1 downto 0);
        variable res_v    : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable carry_v  : std_logic;
        variable ovf_v    : std_logic;
    begin
        a_u := unsigned(a);
        b_u := unsigned(b);

        res_v   := (others => '0');
        carry_v := '0';
        ovf_v   := '0';
        temp_ext := (others => '0');

        case op is
            when "000" =>  -- ADD
                temp_ext := ('0' & a_u) + ('0' & b_u);
                res_v    := std_logic_vector(temp_ext(DATA_WIDTH-1 downto 0));
                carry_v  := temp_ext(DATA_WIDTH);

                if (a(DATA_WIDTH-1) = b(DATA_WIDTH-1)) and
                   (a(DATA_WIDTH-1) /= res_v(DATA_WIDTH-1)) then
                    ovf_v := '1';
                else
                    ovf_v := '0';
                end if;

            when "001" =>  -- SUB
                temp_ext := ('0' & a_u) - ('0' & b_u);
                res_v    := std_logic_vector(temp_ext(DATA_WIDTH-1 downto 0));
                carry_v  := temp_ext(DATA_WIDTH);

                if (a(DATA_WIDTH-1) /= b(DATA_WIDTH-1)) and
                   (a(DATA_WIDTH-1) /= res_v(DATA_WIDTH-1)) then
                    ovf_v := '1';
                else
                    ovf_v := '0';
                end if;

            when "010" =>  -- AND
                res_v := a and b;

            when "011" =>  -- OR
                res_v := a or b;

            when "100" =>  -- XOR
                res_v := a xor b;

            when "101" =>  -- NOT A
                res_v := not a;

            when "110" =>  -- SHL A
                res_v := std_logic_vector(shift_left(unsigned(a), 1));
                carry_v := a(DATA_WIDTH-1);

            when "111" =>  -- SHR A
                res_v := std_logic_vector(shift_right(unsigned(a), 1));
                carry_v := a(0);

            when others =>
                res_v   := (others => '0');
                carry_v := '0';
                ovf_v   := '0';
        end case;

        result   <= res_v;
        carry    <= carry_v;
        overflow <= ovf_v;

        if res_v = std_logic_vector(to_unsigned(0, DATA_WIDTH)) then
            zero <= '1';
        else
            zero <= '0';
        end if;
    end process;

end architecture rtl;