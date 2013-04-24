----------------------------------------------------------------------------------
-- Limits the rate of a flow, depending on the configuration. 
-- Supports only a fixed delay between packets for now.
--
-- Configuration: 
-- - First (and only) word:
--      - id: 8 bits
--      - minimum average inter-frame gap (in bytes, min. 12): 32 bits
--      - padding
--
-- Notes : 
-- - if the inter-frame gap is not a multiple of 8 bytes, each actual inter-frame
-- gap may be up to 7 bytes bigger or smaller, but the average gap will be good.
-- - if other modifiers augment an inter-frame gap over the limit set here, 
-- this modifier will have no effect on this gap.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rate is
    generic (
        -- Configuration identifier
        ID : std_logic_vector(7 downto 0) := x"05"
    );
    port(
        CLK             : in std_logic;
        RESET           : in std_logic;
        RECONF          : in std_logic;

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
        TX_DST_RDY_N    : in std_logic
    );
end rate;

architecture Behavioral of rate is

    -- FSM state
    type fsm_state is (WaitingConf, StoringConf, Transparent, WaitingEndFrame, Pausing);
    signal state                : fsm_state;
    signal state_nxt            : fsm_state;

    -- Configuration data
    signal store_conf           : std_logic;
    signal min_gap              : unsigned(31 downto 0); -- minimum inter-frame gap
    signal min_words            : unsigned(28 downto 0); -- number of words to wait for each time
    signal remaining_bytes      : unsigned(2 downto 0); -- bytes forgotten by the previous number of words

    -- Pause control
    signal wait_cycles          : unsigned(28 downto 0);
    signal wait_bytes           : unsigned(3 downto 0);
    signal new_frame            : std_logic;

    -- Flow control
    signal receiving_data       : std_logic;
    signal pause_input          : std_logic;

begin

    -- FSM state management
    process (CLK, RESET) begin
        if RESET = '1' then
            state <= WaitingConf;
        elsif rising_edge(CLK) then
            if RECONF = '1' then
                state <= WaitingConf;
            else
                state <= state_nxt;
            end if;
        end if;
    end process;

    -- FSM logic
    process (state, receiving_data, RX_SOP_N, RX_EOF_N, RX_DATA, wait_cycles) begin
        state_nxt   <= state;
        store_conf  <= '0';
        pause_input <= '0';
        new_frame <= '0';

        case state is
            -- Waiting for configuration data
            when WaitingConf =>
                -- FIFO is kept empty to avoid hiding busy modifiers after this one
                if (receiving_data = '1') then
                    if (RX_SOP_N = '0' and RX_DATA(63 downto 56) = ID) then
                        -- Configuration word
                        store_conf <= '1';
                        state_nxt <= StoringConf;
                    elsif (RX_EOF_N = '0') then
                        state_nxt <= Transparent;
                    end if;
                end if;
            -- Not configured: forward data
            when Transparent =>
            -- Leave one clock cycle for the first "new_frame" after configuration
            when StoringConf => 
                pause_input <= '1';
                new_frame <= '1';
                state_nxt <= WaitingEndFrame;
            -- Waiting for the first frame end
            when WaitingEndFrame =>
                if (receiving_data = '1' and RX_EOF_N = '0') then
                    if (wait_cycles > 0) then
                        state_nxt <= Pausing;
                    else
                        new_frame <= '1';
                    end if;
                end if;
            -- Forcing a pause of the proper length before the next frame
            when Pausing =>
                pause_input <= '1';
                if (wait_cycles = 1) then
                    state_nxt <= WaitingEndFrame;
                    new_frame <= '1';
                end if;
            when others =>
        end case;
    end process;

    -- Configuration saving process
    -- The -1 is due to the difference between the number of bytes added for Ethernet
    -- and the number of bytes added by the NetCOPE header.
    min_words <= min_gap(31 downto 3) - 1;
    remaining_bytes <= min_gap(2 downto 0);
    process(CLK) begin
        if (rising_edge(CLK)) then
            if (store_conf = '1') then
                min_gap <= unsigned(RX_DATA(55 downto 24));
            end if;
        end if;
    end process;

    -- Pause control
    process(CLK) begin
        if rising_edge(CLK) then
            if (store_conf = '1') then
                -- Reset when a new configuration is received
                wait_bytes <= (others => '0');
            elsif (new_frame = '1') then 
                -- New waiting frame
                if (wait_bytes >= 8) then
                    -- We will wait min_words+1 to catch up
                    wait_cycles <= min_words + 1;
                    wait_bytes <= wait_bytes - 8 + remaining_bytes;
                else
                    -- We will wait min_words
                    wait_cycles <= min_words;
                    wait_bytes <= wait_bytes + remaining_bytes;
                end if;
            elsif (pause_input = '1') then
                -- Decrease the remaining cycles
                wait_cycles <= wait_cycles - 1;
            end if;
        end if;            
    end process;

    -- Flow control
    receiving_data  <= not (RX_SRC_RDY_N or TX_DST_RDY_N or pause_input);
    RX_DST_RDY_N    <= TX_DST_RDY_N or pause_input;
    TX_SRC_RDY_N    <= RX_SRC_RDY_N or pause_input;
    TX_SOF_N        <= RX_SOF_N;
    TX_SOP_N        <= RX_SOP_N;
    TX_EOF_N        <= RX_EOF_N;
    TX_EOP_N        <= RX_EOP_N;
    TX_REM          <= RX_REM;
    TX_DATA         <= RX_DATA;

end Behavioral;