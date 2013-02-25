------------------------------------------------------
-- Dual-port synchronous ram
------------------------------------------------------
-- Data width and number of address width are parameters
------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity dual_port_ram is
    generic(
        DATA_WIDTH  : integer := 8;
        ADDR_WIDTH  : integer := 6
    );
    port(
        CLK         : in std_logic;
        -- Read
        RD_ADDR     : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        RD_EN       : in std_logic := '1';
        RD_DATA     : out std_logic_vector(DATA_WIDTH-1 downto 0);
        -- Write
        WR_ADDR     : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        WR_DATA     : in std_logic_vector(DATA_WIDTH-1 downto 0);
        WR_EN       : in std_logic := '1'
    );
    
end entity;

architecture Behavioral of dual_port_ram is

    -- Build a 2-D array type for the ram
    subtype word_t is std_logic_vector(DATA_WIDTH-1 downto 0);
    type memory_t is array(2**ADDR_WIDTH-1 downto 0) of word_t;
    
    -- Declare the ram
    signal ram : memory_t;
    
    -- Register to hold the address
    signal addr_reg : std_logic_vector(ADDR_WIDTH-1 downto 0);

begin

    process(CLK)
    begin
        if(rising_edge(CLK)) then
            -- Write
            if (WR_EN = '1') then
                ram(conv_integer(WR_ADDR)) <= WR_DATA;
            end if;
            -- Register the address for reading
            if (RD_EN = '1') then
                addr_reg <= RD_ADDR;
            end if;
        end if;
    end process;
    
    -- Read
    RD_DATA <= ram(conv_integer(addr_reg));
        
end Behavioral;
