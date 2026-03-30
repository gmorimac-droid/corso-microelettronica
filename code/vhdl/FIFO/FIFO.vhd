library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo_sync is
    generic (
        DATA_WIDTH : integer := 8;
        DEPTH      : integer := 16;
        ADDR_WIDTH : integer := 4
    );
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        write_en : in  std_logic;
        read_en  : in  std_logic;
        data_in  : in  std_logic_vector(DATA_WIDTH-1 downto 0);

        data_out : out std_logic_vector(DATA_WIDTH-1 downto 0);
        full     : out std_logic;
        empty    : out std_logic
    );
end entity fifo_sync;

architecture rtl of fifo_sync is

    type mem_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mem : mem_t;

    signal wr_ptr   : integer range 0 to DEPTH-1;
    signal rd_ptr   : integer range 0 to DEPTH-1;
    signal count    : integer range 0 to DEPTH;
    signal data_reg : std_logic_vector(DATA_WIDTH-1 downto 0);

    signal do_write : std_logic;
    signal do_read  : std_logic;

begin

    data_out <= data_reg;

    do_write <= '1' when (write_en = '1' and count < DEPTH) else '0';
    do_read  <= '1' when (read_en  = '1' and count > 0)     else '0';

    empty <= '1' when count = 0     else '0';
    full  <= '1' when count = DEPTH else '0';

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count    <= 0;
            data_reg <= (others => '0');

        elsif rising_edge(clk) then

            -- Write
            if do_write = '1' then
                mem(wr_ptr) <= data_in;

                if wr_ptr = DEPTH - 1 then
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1;
                end if;
            end if;

            -- Read
            if do_read = '1' then
                data_reg <= mem(rd_ptr);

                if rd_ptr = DEPTH - 1 then
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1;
                end if;
            end if;

            -- Count update
            case (do_write & do_read) is
                when "10" =>
                    count <= count + 1;
                when "01" =>
                    count <= count - 1;
                when others =>
                    count <= count;
            end case;

        end if;
    end process;

end architecture rtl;