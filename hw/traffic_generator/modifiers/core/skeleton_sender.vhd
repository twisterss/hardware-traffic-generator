-- Receives and stores the packets skeleton during configuration
-- Sends the skeleton a configured number of timers once
-- a SEND word has been received

-- EMPTY FILE because students are working on it for a project.
-- Contact us if you need this file before mid-march 2013. 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity skeleton_sender is
    generic (
        ID              : in std_logic_vector(7 downto 0) := X"01";
        START_ID        : in std_logic_vector(7 downto 0) := X"00"
    );
    port (
        CLK             : in std_logic;
        RESET           : in std_logic;

        RX_SOF_N        : in std_logic;
        RX_SOP_N        : in std_logic;
        RX_EOF_N        : in std_logic;
        RX_EOP_N        : in std_logic;
        RX_SRC_RDY_N    : in std_logic;
        RX_REM          : in std_logic_vector(2 downto 0);
        RX_DATA         : in std_logic_vector(63 downto 0);
        RX_DST_RDY_N    : out std_logic;
        
        TX_SOF_N        : out std_logic;
        TX_SOP_N        : out std_logic;
        TX_EOF_N        : out std_logic;
        TX_EOP_N        : out std_logic;
        TX_SRC_RDY_N    : out std_logic;
        TX_REM          : out std_logic_vector(2 downto 0);
        TX_DATA         : out std_logic_vector(63 downto 0);
        TX_DST_RDY_N    : in std_logic;

        RECONF          : in std_logic
    );
end skeleton_sender;

architecture Behavioral of skeleton_sender is

begin

    TX_SOF_N        <= RX_SOF_N;
    TX_SOP_N        <= RX_SOP_N;
    TX_EOF_N        <= RX_EOF_N;
    TX_EOP_N        <= RX_EOP_N;
    TX_SRC_RDY_N    <= RX_SRC_RDY_N;
    TX_REM          <= RX_REM;
    TX_DATA         <= RX_DATA;
    RX_DST_RDY_N    <= TX_DST_RDY_N;

end Behavioral;
