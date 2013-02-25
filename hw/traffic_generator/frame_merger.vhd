----------------------------------------------------------------------------------
-- Transform different frames into different parts of the same frame.
-- Each frame should have 2 parts:
-- 1 header of 8 bytes with bit 0 set to 1 if this frame reprensets the last part
--   of a frame.
-- 1 content part, that will be appended as a part to current frame, or sent as
--   the first part of a frame if a frame has already been sent.
-- This is to circumvent the fact that frames sent from software
-- cannot have more than 2 parts.
-- It induces a drop in data rate (a header of one word pre part is used).
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity frame_merger is
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
        TX_DST_RDY_N    : in std_logic
    );
end frame_merger;

architecture Behavioral of frame_merger is

    -- Are we in the last part of the frame?
    signal last_part            : std_logic;
    -- Should we send a new frame?
    signal new_frame            : std_logic;

begin

    -- State manager
    check_header:process (CLK, RESET) begin
        if (RESET = '1') then
            last_part <= '0';
            new_frame <= '1';
        elsif (rising_edge(CLK)) then
            if (RX_SRC_RDY_N = '0' and TX_DST_RDY_N = '0' and RX_SOF_N = '0') then
                last_part <= RX_DATA(0);
            end if;
            if (RX_SRC_RDY_N = '0' and TX_DST_RDY_N = '0' and RX_EOF_N = '0') then
                new_frame <= last_part;
            end if;
        end if;
    end process;

    -- FrameLink management
    TX_DATA <= RX_DATA;
    TX_REM <= RX_REM;
    TX_SOF_N <= RX_SOP_N or not new_frame;
    TX_EOF_N <= RX_EOF_N or not last_part;
    TX_SOP_N <= RX_SOP_N;
    TX_EOP_N <= RX_EOP_N;
    TX_SRC_RDY_N <= RX_SRC_RDY_N or not RX_SOF_N;
    RX_DST_RDY_N <= TX_DST_RDY_N;

end Behavioral;
