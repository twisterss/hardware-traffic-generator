----------------------------------------------------------------------------------
-- Configuration remover
-- Removes the first frame (configuration) and the NetCOPE header in each frame
-- Does not transmit target ready while in configuration or header.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity config_remover is
    Port (
        CLK             : in std_logic;
        RESET           : in std_logic;
        -- Input FrameLink
        RX_DATA         : in std_logic_vector(63 downto 0);
        RX_REM          : in std_logic_vector(2 downto 0);
        RX_SOF_N        : in std_logic;
        RX_EOF_N        : in std_logic;
        RX_SOP_N        : in std_logic;
        RX_EOP_N        : in std_logic;
        RX_SRC_RDY_N    : in std_logic;
        RX_DST_RDY_N    : out std_logic;
        -- Output FrameLink
        TX_DATA         : out std_logic_vector(63 downto 0);
        TX_REM          : out std_logic_vector(2 downto 0);
        TX_SOF_N        : out std_logic;
        TX_EOF_N        : out std_logic;
        TX_SOP_N        : out std_logic;
        TX_EOP_N        : out std_logic;
        TX_SRC_RDY_N    : out std_logic;
        TX_DST_RDY_N    : in std_logic;
        -- Reconfiguration
        RECONF          : in std_logic
    );
end config_remover;

architecture Behavioral of config_remover is

    -- Current state
    signal in_config        : std_logic;
    signal in_header        : std_logic;
    signal receive_ok_n     : std_logic;

begin

    -- Check the current state
    state_check: process (RESET, CLK) begin
        if (RESET = '1') then
            in_config <= '1';
        elsif (rising_edge(CLK)) then
            if (RECONF = '1') then
                -- Reconfiguration
                in_config <= '1';
            elsif (RX_SRC_RDY_N = '0' and receive_ok_n = '0') then
                -- Data is being transmitted
                if (RX_EOF_N = '0') then
                    in_config <= '0';
                    in_header <= '1';
                elsif (RX_EOP_N = '0') then
                    in_header <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Transmit data, modifying only SOF and SRC_RDY
    TX_DATA <= RX_DATA;
    TX_REM <= RX_REM;
    TX_SOF_N <= RX_SOP_N;
    TX_EOF_N <= RX_EOF_N;
    TX_SOP_N <= RX_SOP_N;
    TX_EOP_N <= RX_EOP_N;
    TX_SRC_RDY_N <= RX_SRC_RDY_N or in_config or in_header;
    receive_ok_n <= TX_DST_RDY_N and not (in_config or in_header);
    RX_DST_RDY_N <= receive_ok_n;

end Behavioral;
