----------------------------------------------------------------------------------
-- Receives and stores the packets skeleton during configuration
-- Sends the skeleton a configured number of timers once
-- a SEND word has been received
--
-- Configuration:
-- - First word:
--      - id: 8 bits
--      - number of iterations: 32 bits
--      - padding: 13 bits
--      - number of bytes of the skeleton: 11 bits
-- - Next words: skeleton data
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity skeleton_sender is
    generic (
        -- Configuration identifier
        ID              : std_logic_vector(7 downto 0) := X"01";
        -- Start word identifier
        START_ID        : std_logic_vector(7 downto 0) := X"00"
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

-- FSM
type fsm_state is (WaitingConfig, StoringData, WaitingStart, SendingHeader1, SendingHeader2, SendingData);
signal state            : fsm_state;
signal state_nxt        : fsm_state;

-- Config
signal nb_bytes         : unsigned(10 downto 0);
signal nb_iter          : unsigned(31 downto 0);
signal nb_words         : unsigned(7 downto 0);
signal nb_bytes_rem     : unsigned(2 downto 0);

-- Sent iterations counter
signal iter_ctr         : unsigned(31 downto 0);
signal iter_ctr_en      : std_logic;
signal iter_ctr_reset   : std_logic;
-- Sent or received words counter
signal words_ctr        : unsigned(7 downto 0);
signal words_ctr_en     : std_logic;
signal words_ctr_reset  : std_logic;
signal words_ctr_sent   : unsigned(7 downto 0);
signal last_word_sent   : std_logic;

-- Control
signal save_config      : std_logic;
signal save_data        : std_logic;
signal send_header1     : std_logic;
signal send_header2     : std_logic;
signal send_data        : std_logic;
signal send_received    : std_logic;

-- Status
signal receiving_data   : std_logic;

-- RAM signals
signal ram_data         : std_logic_vector(63 downto 0);
signal ram_read         : std_logic;

begin

-- RAM connection
memory : entity work.single_port_ram
generic map(
    DATA_WIDTH => 64,
    ADDR_WIDTH => 8
)
port map(
    CLK     => CLK,
    DIN     => RX_DATA,
    ADDR    => std_logic_vector(words_ctr),
    EN      => ram_read,
    WE      => save_data,
    DOUT    => ram_data
);

-- Status management
receiving_data <= (not RX_SRC_RDY_N) and (not TX_DST_RDY_N);

-- FSM
fsm_state_man : process (CLK, RESET) begin
    if RESET = '1' then
        state <= WaitingConfig;
    elsif rising_edge(CLK) then
        state <= state_nxt;
    end if;
end process;

fsm_logic: process (state, receiving_data, RX_SOP_N, RX_DATA, RX_EOP_N, TX_DST_RDY_N, words_ctr, last_word_sent, iter_ctr, nb_iter, RECONF) begin
    state_nxt <= state;
    iter_ctr_en <= '0';
    iter_ctr_reset <= '0';
    words_ctr_en <= '0';
    words_ctr_reset <= '0';
    save_config <= '0';
    save_data <= '0';
    send_header1 <= '0';
    send_header2 <= '0';
    send_data <= '0';
    send_received <= '0';
    ram_read <= '0';

    case state is
        -- Waiting for the good configuration
        when WaitingConfig =>
            send_received <= '1';
            if receiving_data = '1' and RX_SOP_N ='0' and RX_DATA(63 downto 56) = ID then
                save_config <= '1';
                state_nxt <= StoringData;
                words_ctr_reset <= '1';
            end if;
        -- Storing configured data
        when StoringData =>
            send_received <= '1';
            words_ctr_en <= receiving_data;
            save_data <= receiving_data;
            if receiving_data = '1' and RX_EOP_N = '0' then -- if we get the last part of skeleton_sender configuration
                --reading and writing skeleton_sender LAST part of configuration into the RAM
                state_nxt <= WaitingStart; -- we received the last part of configuration for skeleton_sender
            end if;
        -- Waiting for the start frame
        when WaitingStart =>
            iter_ctr_reset <= '1';
            if receiving_data = '1' and RX_DATA(63 downto 56) = START_ID and RX_SOP_N = '0' then -- case where we receive a start frame
                state_nxt <= SendingHeader1;
            else
                send_received <= '1';
            end if;
        -- Send length header
        when SendingHeader1 =>
            send_header1 <= '1';
            -- Prepare the word counter for the next frame (counter at 0)
            words_ctr_reset <= '1'; 
            if TX_DST_RDY_N = '0' then
                state_nxt <= SendingHeader2;
            end if;
        -- Send empty header
        when SendingHeader2 =>
            send_header2 <= '1';
            -- Prepare the word counter and RAM for the next frame (counter at 1, RAM at 0)
            if (words_ctr = 0) then
                ram_read <= '1';
                words_ctr_en <= '1';
            end if;
            if TX_DST_RDY_N = '0' then
                state_nxt <= SendingData;
            end if;
        -- Send frame data
        when SendingData =>
            send_data <= '1';
            if TX_DST_RDY_N = '0' then
                words_ctr_en <= '1';
                ram_read <= '1';
                if last_word_sent = '1' then
                    iter_ctr_en <= '1';
                    if iter_ctr = (nb_iter - 1) then
                        state_nxt <= WaitingStart;
                    else
                        state_nxt <= SendingHeader1;
                    end if;
                end if;
            end if;
        when others =>
    end case;
    -- Reconfiguration sends back to the start
    if RECONF = '1' then
        state_nxt <= WaitingConfig;
    end if;
end process;

-- Configuration saving
nb_words <= unsigned(nb_bytes(10 downto 3)) when nb_bytes(2 downto 0) = "000" else (unsigned(nb_bytes(10 downto 3)) + 1);
nb_bytes_rem <= unsigned(nb_bytes(2 downto 0));
config_saving: process(CLK) begin
    if rising_edge(CLK) then
        if save_config = '1' then
            nb_iter <= unsigned(RX_DATA(55 downto 24));
            nb_bytes <= unsigned(RX_DATA(10 downto 0));
        end if;
    end if;
end process;

-- Iterations counter
iter_counter: process(CLK) begin    
    if rising_edge(CLK) then
        if iter_ctr_reset = '1' then
            iter_ctr <= (others => '0');
        elsif iter_ctr_en = '1' then
            iter_ctr <= iter_ctr + 1;
        end if;
    end if;
end process;

-- Words counter
last_word_sent <= '1' when words_ctr_sent = (nb_words-1) else '0';
words_counter: process(CLK) begin
        if rising_edge(CLK) then
            if words_ctr_reset = '1' then
                words_ctr <= (others => '0');
            elsif words_ctr_en = '1' then
                words_ctr <= words_ctr + 1;
            end if;
        if (ram_read = '1') then
            -- memory read => counter read
            words_ctr_sent <= words_ctr;
        end if;
        end if;
end process;

-- NetCope management
RX_DST_RDY_N <= TX_DST_RDY_N when send_received = '1' else '1';
nc_manager: process(CLK) begin
    if rising_edge(CLK) then
        if (TX_DST_RDY_N = '0') then
            if send_header1 = '1' then
                TX_DATA <= x"00000000000C" & "00000" & std_logic_vector(nb_bytes + 16);
                TX_REM <= "111";
                TX_SOF_N <= '0';
                TX_EOF_N <= '1';
                TX_SOP_N <= '0';
                TX_EOP_N <= '1';
                TX_SRC_RDY_N <= '0';
            elsif send_header2 = '1' then
                TX_DATA <= (others => '0');
                TX_REM <= "111";
                TX_SOF_N <= '1';
                TX_EOF_N <= '1';
                TX_SOP_N <= '1';
                TX_EOP_N <= '0';
                TX_SRC_RDY_N <= '0';
            elsif send_data = '1' then
                TX_DATA <= ram_data;
                if last_word_sent = '1' then
                    TX_REM <= std_logic_vector(nb_bytes_rem - 1);
                else
                    TX_REM <= "111";
                end if;
                TX_SOF_N <= '1';
                TX_EOF_N <= not last_word_sent;
                if words_ctr_sent = 0 then
                    TX_SOP_N <= '0';
                else
                    TX_SOP_N <= '1';
                end if;
                TX_EOP_N <= not last_word_sent;
                TX_SRC_RDY_N <= '0';
            elsif send_received = '1' then
                TX_DATA <= RX_DATA;
                TX_REM <= RX_REM;
                TX_SOF_N <= RX_SOF_N;
                TX_EOF_N <= RX_EOF_N;
                TX_SOP_N <= RX_SOP_N;
                TX_EOP_N <= RX_EOP_N;
                TX_SRC_RDY_N <= RX_SRC_RDY_N;
            else
                TX_SRC_RDY_N <= '1';
            end if;
        end if;
    end if;
end process;

end Behavioral;
