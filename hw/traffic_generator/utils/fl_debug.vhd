----------------------------------------------------------------------------------
-- Make framelink data available for debug
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fl_debug is
    Port (
        CLK             : in std_logic;
        RESET           : in std_logic;
        -- Checked framelink
        RX_DATA         : in std_logic_vector(63 downto 0);
        RX_REM          : in std_logic_vector(2 downto 0);
        RX_SOF_N        : in std_logic;
        RX_EOF_N        : in std_logic;
        RX_SOP_N        : in std_logic;
        RX_EOP_N        : in std_logic;
        RX_SRC_RDY_N    : in std_logic;
        RX_DST_RDY_N    : in std_logic;
        -- Output data
        COUNTER         : out std_logic_vector(7 downto 0);
        DATA            : out std_logic_vector(63 downto 0);
        DREM            : out std_logic_vector(2 downto 0);
        SOF_N           : out std_logic;
        EOF_N           : out std_logic;
        SOP_N           : out std_logic;
        EOP_N           : out std_logic;
        OUT_CLK         : in std_logic
    );
end fl_debug;

architecture Behavioral of fl_debug is

    signal wr_addr          : unsigned(7 downto 0);
    signal rd_addr          : unsigned(7 downto 0);
    signal wr_en            : std_logic;
    signal rd_nxt           : std_logic;
    signal out_clk_reg      : std_logic;
    signal out_clk_reg_reg  : std_logic;

begin

    COUNTER <= std_logic_vector(rd_addr);

    -- RAM mapping
    memory : entity work.dual_port_ram
    generic map(
        DATA_WIDTH => 71,
        ADDR_WIDTH => 8
    )
    port map(
        CLK                  => CLK,
        WR_DATA(70 downto 7) => RX_DATA,
        WR_DATA(6 downto 4)  => RX_REM,
        WR_DATA(3)           => RX_SOF_N,
        WR_DATA(2)           => RX_EOF_N,
        WR_DATA(1)           => RX_SOP_N,
        WR_DATA(0)           => RX_EOP_N,
        WR_ADDR              => std_logic_vector(wr_addr),
        WR_EN                => wr_en,
        RD_ADDR              => std_logic_vector(rd_addr),
        RD_DATA(70 downto 7) => DATA,
        RD_DATA(6 downto 4)  => DREM,
        RD_DATA(3)           => SOF_N,
        RD_DATA(2)           => EOF_N,
        RD_DATA(1)           => SOP_N,
        RD_DATA(0)           => EOP_N
    );

    -- New read detection
    rd_nxt <= out_clk_reg and not out_clk_reg_reg;
    process(CLK) begin
        if (rising_edge(CLK)) then
            out_clk_reg <= OUT_CLK;
            out_clk_reg_reg <= out_clk_reg;
        end if;
    end process;

    -- Address management
    wr_en <= (not  RX_SRC_RDY_N) and (not RX_DST_RDY_N);
    process (CLK, RESET) begin
        if (RESET = '1') then
            wr_addr <= (others => '0');
            rd_addr <= (others => '0');
        elsif (rising_edge(CLK)) then
            if (wr_en = '1') then
                wr_addr <= wr_addr + 1;
            end if;
            if (rd_nxt = '1' and (not (wr_addr = rd_addr)) and (not (wr_addr = (rd_addr + 1)))) then
                rd_addr <= rd_addr + 1;
            end if;
        end if;
    end process;

end Behavioral;
