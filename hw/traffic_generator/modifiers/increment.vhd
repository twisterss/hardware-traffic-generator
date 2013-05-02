----------------------------------------------------------------------------------
-- Modifies one 16 bits field by setting a value that is incremented
-- depending on the number of received packets.
--
-- Configuration: 
-- - First word:
--      - id: 8 bits
--      - minimum: 16 bits
--      - maximum: 16 bits
--      - packets skipped for value changes (in number of sent packets): 16 bits
--      - inverted (0: increment, 1: decrement): 1 bit
--      - padding
-- - Second word:
--      - increment value (unsigned): 16 bits
--      - field offset (in bytes from packet start): 11 bits
--      - padding
--
-- Notes:
-- - Packets skipped should be 0 to increment every time,
--   1 to increment every 2 packets, etc...
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity increment is
    generic (
        -- Configuration identifier
        ID          : std_logic_vector(7 downto 0) := x"06"
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
end increment;

architecture Behavioral of increment is
    -- FSM states
    type fsm_state is (WaitingConf1, WaitingConf2, Transparent, WaitingFrame, WaitingData, InData);
    signal state           : fsm_state;
    signal state_nxt       : fsm_state;

    -- Configuration data
    signal store_conf1      : std_logic;
    signal store_conf2      : std_logic;
    signal min_count        : unsigned(15 downto 0);
    signal max_count        : unsigned(15 downto 0);
    signal step_skip        : unsigned(15 downto 0);
    signal increment        : unsigned(15 downto 0);
    signal is_inverted      : std_logic;
    signal insert_offset    : unsigned(10 downto 0);

    -- Counter
    signal new_frame        : std_logic;
    signal step_counter     : unsigned(15 downto 0);
    signal new_step         : std_logic;
    signal counter          : unsigned(15 downto 0);

    -- Flow management
    signal in_data          : std_logic;
    signal bytes_counter    : unsigned(10 downto 0);
    signal insert_data      : std_logic_vector(15 downto 0);
    signal insert_shift     : unsigned(10 downto 0);

    -- Input signals (registered)
    signal rx_data_int              : std_logic_vector(63 downto 0);
    signal rx_rem_int               : std_logic_vector(2 downto 0);
    signal rx_sof_n_int             : std_logic;
    signal rx_eof_n_int             : std_logic;
    signal rx_sop_n_int             : std_logic;
    signal rx_eop_n_int             : std_logic;
    signal rx_src_rdy_n_int         : std_logic;
    signal rx_dst_rdy_n_int         : std_logic;
begin

    -- Tiny fifo to cut the input critical path only
    frame_fifo : entity work.FRAME_FIFO
        generic map(
            DATA_WIDTH  => 64,
            DEPTH       => 2
        )
        port map(
            CLK             => CLK,
            RESET           => RESET,
            RX_DATA         => RX_DATA,
            RX_REM          => RX_REM,
            RX_SOF_N        => RX_SOF_N,
            RX_EOF_N        => RX_EOF_N,
            RX_SOP_N        => RX_SOP_N,
            RX_EOP_N        => RX_EOP_N,
            RX_SRC_RDY_N    => RX_SRC_RDY_N,
            RX_DST_RDY_N    => RX_DST_RDY_N,
            TX_DATA         => rx_data_int,
            TX_REM          => rx_rem_int,
            TX_SOF_N        => rx_sof_n_int,
            TX_EOF_N        => rx_eof_n_int,
            TX_SOP_N        => rx_sop_n_int,
            TX_EOP_N        => rx_eop_n_int,
            TX_SRC_RDY_N    => rx_src_rdy_n_int,
            TX_DST_RDY_N    => rx_dst_rdy_n_int
        );

    -- FSM state management
    process (CLK, RESET) begin
        if RESET = '1' then
            state <= WaitingConf1;
        elsif rising_edge(CLK) then
            if RECONF = '1' then
                state <= WaitingConf1;
            else
                state <= state_nxt;
            end if;
        end if;
    end process;

    -- FSM logic
    process (state, rx_src_rdy_n_int, TX_DST_RDY_N, rx_sop_n_int, rx_eop_n_int, rx_eof_n_int, rx_data_int, rx_sof_n_int) begin
        state_nxt       <= state;
        store_conf1     <= '0';
        store_conf2     <= '0';
        in_data         <= '0';
        new_frame       <= '0';

        case state is
            -- Waiting for configuration data (first word)
            when WaitingConf1 =>
                if (rx_src_rdy_n_int = '0' and TX_DST_RDY_N = '0') then
                    if (rx_eof_n_int = '0') then
                        -- Last config. word: not configured
                        state_nxt <= Transparent;
                    elsif (rx_sop_n_int ='0' and rx_data_int(63 downto 56) = ID) then
                        -- First configuration word
                        store_conf1 <= '1';
                        state_nxt <= WaitingConf2;
                    end if;
                end if;
            -- Waiting for configuration data (second word)
            when WaitingConf2 =>
                if (rx_src_rdy_n_int = '0' and TX_DST_RDY_N = '0') then
                    -- Second configuration word
                    store_conf2 <= '1';
                    state_nxt <= WaitingFrame;
                end if;
            -- Not configured: forward data
            when Transparent =>
            -- Waiting for the start of a frame
            when WaitingFrame =>
                if (rx_src_rdy_n_int = '0' and TX_DST_RDY_N = '0' and rx_sof_n_int = '0') then
                    state_nxt <= WaitingData;
                end if;
            -- Waiting for the end of the header
            when WaitingData =>
                if (rx_src_rdy_n_int = '0' and TX_DST_RDY_N = '0' and rx_eop_n_int = '0') then
                    state_nxt <= InData;
                end if;
            -- Inserting data
            when InData =>
                if (rx_src_rdy_n_int = '0' and TX_DST_RDY_N = '0') then
                    in_data <= '1';
                    if (rx_eof_n_int = '0') then
                        state_nxt <= WaitingFrame;
                        new_frame <= '1';
                    end if;
                end if;
            when others =>
        end case;
    end process;

    -- Configuration saving process
    process(CLK) begin
        if (rising_edge(CLK)) then
            if (store_conf1 = '1') then
                min_count       <= unsigned(rx_data_int(55 downto 40));
                max_count       <= unsigned(rx_data_int(39 downto 24));
                step_skip       <= unsigned(rx_data_int(23 downto 8));
                is_inverted     <= rx_data_int(7);
            end if;
            if (store_conf2 = '1') then
                increment       <= unsigned(rx_data_int(63 downto 48));
                insert_offset   <= unsigned(rx_data_int(47 downto 37));
            end if;
        end if;
    end process;

    -- Step counter
    new_step <= '1' when (new_frame = '1' and step_counter = step_skip) else '0';
    process(CLK) begin
        if (rising_edge(CLK)) then
            if (store_conf2 = '1') then
                -- Reset
                step_counter <= (others => '0');
            elsif (new_frame = '1') then
                if (step_counter = step_skip) then
                    -- New step detected
                    step_counter <= (others => '0');
                else
                    step_counter <= step_counter + 1;
                end if;
            end if;
        end if;
    end process;

    -- Configurable counter
    process(CLK) begin
        if (rising_edge(CLK)) then
            if (is_inverted = '0') then
                -- Incrementing counter
                if (store_conf2 = '1') then
                    -- Reset
                    counter <= min_count;
                elsif (new_step = '1') then
                    if (counter > max_count - increment) then
                        -- Overflow
                        counter <= min_count;
                    else
                        counter <= counter + increment;
                    end if;
                end if;
            else 
                -- Decrementing counter
                if (store_conf2 = '1') then
                    -- Reset
                    counter <= max_count;
                elsif (new_step = '1') then
                    if (counter < min_count + increment) then
                        -- Overflow
                        counter <= max_count;
                    else
                        counter <= counter - increment;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Input bytes counter
    process(CLK) begin
        if (rising_edge(CLK)) then
            if (new_frame = '1' or store_conf2 = '1') then
                bytes_counter <= (others => '0');
            elsif (in_data = '1') then
                bytes_counter <= bytes_counter + 8;
            end if;
        end if;
    end process;

    -- Data bus management
    rx_dst_rdy_n_int    <= TX_DST_RDY_N;
    TX_SOF_N            <= rx_sof_n_int;    
    TX_SOP_N            <= rx_sop_n_int;    
    TX_EOF_N            <= rx_eof_n_int;    
    TX_EOP_N            <= rx_eop_n_int;    
    TX_SRC_RDY_N        <= rx_src_rdy_n_int;
    TX_REM              <= rx_rem_int;

    -- Data insertion
    insert_shift <= insert_offset + 1 - bytes_counter;
    insert_data <= std_logic_vector(counter(7 downto 0)) & std_logic_vector(counter(15 downto 8));
    process(in_data, insert_offset, bytes_counter, insert_shift, rx_data_int, insert_data) begin
        if (in_data = '0' or insert_offset + 1 < bytes_counter or insert_shift > 8) then
            TX_DATA <= rx_data_int;
        else
            case insert_shift(3 downto 0) is
                when X"0" => 
                    TX_DATA <= rx_data_int(63 downto 8) & insert_data(15 downto 8);
                when X"1" => 
                    TX_DATA <= rx_data_int(63 downto 16) & insert_data;
                when X"2" => 
                    TX_DATA <= rx_data_int(63 downto 24) & insert_data & rx_data_int(7 downto 0);
                when X"3" => 
                    TX_DATA <= rx_data_int(63 downto 32) & insert_data & rx_data_int(15 downto 0);
                when X"4" => 
                    TX_DATA <= rx_data_int(63 downto 40) & insert_data & rx_data_int(23 downto 0);
                when X"5" => 
                    TX_DATA <= rx_data_int(63 downto 48) & insert_data & rx_data_int(31 downto 0);
                when X"6" => 
                    TX_DATA <= rx_data_int(63 downto 56) & insert_data & rx_data_int(39 downto 0);
                when X"7" => 
                    TX_DATA <= insert_data & rx_data_int(47 downto 0);
                when X"8" => 
                    TX_DATA <= insert_data(7 downto 0) & rx_data_int(55 downto 0);
                when others =>
                    TX_DATA <= (others => '-');
            end case;
        end if;
    end process;

end Behavioral;