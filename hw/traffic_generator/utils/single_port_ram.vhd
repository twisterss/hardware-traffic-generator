------------------------------------------------------
-- Single-port synchronous ram
------------------------------------------------------
-- Data width and number of addresses are parameters
-- When writing, you can only read the previous value
-- at the written address.
-- To read:
--      * Put an address in ADDR
--      * data will be in DOUT at next clock cycle
-- To write:
--      * Put an address in ADDR
--      * Put data in DIN
--      * Put 1 in WE
--      * data will be saved at next clock cycle
------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity single_port_ram is
    generic(
        DATA_WIDTH  : integer := 8;
        ADDR_WIDTH  : integer := 6
    );
    port(
        CLK         : in std_logic;
        DIN         : in std_logic_vector(DATA_WIDTH-1 downto 0);
        ADDR        : in std_logic_vector(ADDR_WIDTH-1 downto 0);
        EN          : in std_logic := '1';
        WE          : in std_logic := '1';
        DOUT        : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
    
end entity;

architecture Behavioral of single_port_ram is

    -- Build a 2-D array type for the ram
    subtype word_t is std_logic_vector(DATA_WIDTH-1 downto 0);
    type memory_t is array(2**ADDR_WIDTH-1 downto 0) of word_t;
    
    -- Declare the ram
    signal ram          : memory_t;
    
    -- Register to hold the address
    signal addr_reg     : std_logic_vector(ADDR_WIDTH-1 downto 0);

begin

    process(CLK)
    begin
        if(rising_edge(CLK)) then
            -- Write
            if(we = '1') then
                ram(conv_integer(ADDR)) <= DIN;
            end if;
            
            -- Register the address for reading
            if (EN = '1') then
                addr_reg <= ADDR;
            end if;
        end if;
    end process;
    
    -- Read
    DOUT <= ram(conv_integer(addr_reg));
    
end Behavioral;
