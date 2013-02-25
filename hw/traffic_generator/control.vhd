----------------------------------------------------------------------------------
-- Control of the traffic generator:
--  * receive the configuration and disptach it to the flow generators
--  * send the start message
--  * manage the reconf signal
--  * monitor the generators state
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
USE ieee.math_real.log2;
USE ieee.math_real.ceil;

entity control is
    generic (
        -- Number of flow generators connected in output
        FLOW_COUNT      : integer := 1
    );
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
        -- Output FrameLinks (x FLOW_COUNT)
        TX_DATA         : out std_logic_vector(64*FLOW_COUNT-1 downto 0);
        TX_REM          : out std_logic_vector(3*FLOW_COUNT-1 downto 0);
        TX_SOF_N        : out std_logic_vector(FLOW_COUNT-1 downto 0);
        TX_EOF_N        : out std_logic_vector(FLOW_COUNT-1 downto 0);
        TX_SOP_N        : out std_logic_vector(FLOW_COUNT-1 downto 0);
        TX_EOP_N        : out std_logic_vector(FLOW_COUNT-1 downto 0);
        TX_SRC_RDY_N    : out std_logic_vector(FLOW_COUNT-1 downto 0);
        TX_DST_RDY_N    : in std_logic_vector(FLOW_COUNT-1 downto 0);
        -- Output reconf signal (synchronous reset for flow generators)
        RECONF          : out std_logic;
        -- Software communication
        STATUS          : out std_logic_vector(31 downto 0);
        ACTION          : in std_logic_vector(31 downto 0);
        ACTION_ACK      : out std_logic
    );
end control;

architecture Behavioral of control is

    -- Status and action words
    constant STATUS_CONFIG      : std_logic_vector(31 downto 0) := X"00000001";
    constant STATUS_FULL_CONFIG : std_logic_vector(31 downto 0) := X"00000002";
    constant STATUS_SENDING     : std_logic_vector(31 downto 0) := X"00000003";
    constant STATUS_IDLE        : std_logic_vector(31 downto 0) := X"00000004";
    constant ACTION_SEND        : std_logic_vector(31 downto 0) := X"00000001";
    constant ACTION_RESTART     : std_logic_vector(31 downto 0) := X"00000002";

    -- FSM
    type fsm_state is (ReceiveConf, FullyConfigured, SendStart, SendReconf, Running, Idle);
    signal state                : fsm_state;
    signal state_nxt            : fsm_state;

    -- Counter: number of fully configured flow generators
    constant FLOW_COUNT_LOG     : integer := integer(ceil(log2(real(FLOW_COUNT+1))));
    signal flows_counter        : unsigned(FLOW_COUNT_LOG-1 downto 0);
    signal flows_counter_fast   : unsigned(FLOW_COUNT_LOG-1 downto 0);
    signal flows_counter_en     : std_logic;
    signal flows_counter_reset  : std_logic;
    signal flows_counter_all    : std_logic;
    -- Indicates that the value of flows_counter should be FLOW_COUNT
    -- not actually set because it would cause out of bound errors
    signal flows_counter_set_all: std_logic;

    -- Control of the output to flow generators
    signal tx_forward           : std_logic;
    signal tx_send_start        : std_logic;
    signal tx_send_reconf       : std_logic;
    signal tx_sending_eof       : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal tx_eof_will_be_sent  : std_logic;

    -- Keep up to date on if all generators are ready
    signal flows_ready          : std_logic;
    signal flows_ready_check    : unsigned(FLOW_COUNT_LOG-1 downto 0);
    signal flows_ready_temp     : std_logic;
    signal flows_ready_force_no : std_logic;
    signal flows_ready_wait     : std_logic;

    -- Separated output FrameLinks
    type data_array is array(0 to FLOW_COUNT-1) of std_logic_vector(63 downto 0);
    type rem_array is array(0 to FLOW_COUNT-1) of std_logic_vector(2 downto 0);
    signal tx_data_a            : data_array;
    signal tx_rem_a             : rem_array;

begin


    -- FSM
    fsm_sync: process (RESET, CLK) begin
        if (RESET = '1') then
            state <= ReceiveConf;
        elsif (rising_edge(CLK)) then
            state <= state_nxt;
        end if;
    end process;

    fsm_async: process (state, ACTION, flows_counter, tx_eof_will_be_sent, flows_counter, RX_SRC_RDY_N, flows_ready) begin
        state_nxt <= state;
        flows_counter_en <= '0';
        flows_counter_reset <= '0';
        flows_counter_set_all <= '0';
        tx_forward <= '0';
        tx_send_start <= '0';
        tx_send_reconf <= '0';
        flows_ready_force_no <= '0';
        STATUS <= STATUS_IDLE;
        ACTION_ACK <= '0';

        case state is
            when ReceiveConf =>
                STATUS <= STATUS_CONFIG;
                if (ACTION = ACTION_SEND and flows_counter > 0) then
                    -- Action: send packets (even if not fully configured)
                    ACTION_ACK <= '1';
                    state_nxt <= SendStart;
                elsif (ACTION = ACTION_RESTART) then
                    -- Action: restart the configuration
                    ACTION_ACK <= '1';
                    state_nxt <= SendReconf;                    
                elsif (tx_eof_will_be_sent = '1') then
                    -- Sent a full frame to a generator
                    if (flows_counter >= FLOW_COUNT-1) then
                        state_nxt <= FullyConfigured;
                        flows_counter_set_all <= '1';
                    else
                        tx_forward <= '1';
                        flows_ready_force_no <= not RX_SRC_RDY_N;
                        flows_counter_en <= '1';
                    end if;
                else
                    -- Transmitting
                    tx_forward <= '1';
                    flows_ready_force_no <= not RX_SRC_RDY_N;
                end if;
            when FullyConfigured => 
                STATUS <= STATUS_FULL_CONFIG;
                if (ACTION = ACTION_SEND) then
                    -- Action: send packets
                    ACTION_ACK <= '1';
                    state_nxt <= SendStart;
                elsif (ACTION = ACTION_RESTART) then
                    -- Action: restart the configuration
                    ACTION_ACK <= '1';
                    state_nxt <= SendReconf;
                end if;
            when SendStart =>
                -- Make sure all generators are configured before sending start to all
                STATUS <= STATUS_CONFIG;
                if (flows_ready = '1') then
                    tx_send_start <= '1';
                    flows_ready_force_no <= '1';
                    state_nxt <= Running;
                end if;
            when SendReconf =>
                -- Send immediately the reconf signal to all generators
                tx_send_reconf <= '1';
                flows_counter_reset <= '1';
                state_nxt <= ReceiveConf;
            when Running =>
                STATUS <= STATUS_SENDING;
                if (ACTION = ACTION_RESTART) then
                    -- Action: restart the configuration
                    ACTION_ACK <= '1';
                    state_nxt <= SendReconf;
                elsif (flows_ready = '1') then
                    state_nxt <= Idle;
                end if;
            when Idle =>
                STATUS <= STATUS_IDLE;
                if (ACTION = ACTION_RESTART) then
                    -- Action: restart the configuration
                    ACTION_ACK <= '1';
                    state_nxt <= SendReconf;
                end if;
        end case;
    end process;

    -- Flows counter
    flows_counter_fast <= (others => '0') when (flows_counter_reset = '1') else flows_counter + 1 when (flows_counter_en = '1') else flows_counter;
    flows_count: process (CLK, RESET) begin
        if (RESET = '1') then
            flows_counter <= (others => '0');
            flows_counter_all <= '0';
        elsif (rising_edge(CLK)) then
            if (flows_counter_reset = '1') then
                flows_counter <= (others => '0');
                flows_counter_all <= '0';
            elsif (flows_counter_en = '1') then
                flows_counter <= flows_counter + 1;
            elsif (flows_counter_set_all = '1') then
                flows_counter_all <= '1';
            end if;                
        end if;
    end process;

    -- Check routinely if flows are ready
    ready_check: process(RESET, CLK) begin
        if (RESET = '1') then
            flows_ready <= '0';
            flows_ready_temp <= '0';
            flows_ready_check <= (others => '0');
        elsif (rising_edge(CLK)) then
            if (flows_ready_force_no = '1' or flows_ready_wait = '1') then
                -- Something happened, reset ready to NO
                flows_ready <= '0';
                flows_ready_temp <= '0';
                flows_ready_check <= (others => '0');
            else
                if (flows_ready_check = to_unsigned(0, FLOW_COUNT_LOG)) then
                    -- Check the first flow genrator and set the ready status found
                    flows_ready <= flows_ready_temp;
                    flows_ready_temp <= not TX_DST_RDY_N(0);
                else
                    -- Check 1 flow generator per clock cycle
                    flows_ready_temp <= flows_ready_temp and not TX_DST_RDY_N(to_integer(flows_ready_check));
                end if;
                -- Increment the check pointer
                if (flows_ready_check < FLOW_COUNT-1) then
                    flows_ready_check <= flows_ready_check + 1;
                else
                    flows_ready_check <= (others => '0');
                end if;
            end if;
            -- Wait one clock cycle after force no
            flows_ready_wait <= flows_ready_force_no;
        end if;
    end process;

    -- Manage output to flow generators
    RX_DST_RDY_N <= (not tx_forward) or TX_DST_RDY_N(to_integer(flows_counter));
    tx_eof_will_be_sent <= (not TX_DST_RDY_N(to_integer(flows_counter))) and tx_sending_eof(to_integer(flows_counter));
    send_framelink: for i in 0 to FLOW_COUNT-1 generate
        -- FrameLink
        send_data: process (CLK, RESET) begin
            if (RESET = '1') then
                TX_SRC_RDY_N(i) <= '1';
            elsif (rising_edge(CLK)) then
                if (tx_forward = '1') then
                    -- Forward data directly from RX to the good TX
                    if (flows_counter_fast = i) then
                        if (TX_DST_RDY_N(i) = '0') then
                            tx_data_a(i) <= RX_DATA;
                            tx_rem_a(i) <= RX_REM;
                            TX_SOF_N(i) <= RX_SOF_N;
                            TX_EOF_N(i) <= RX_EOF_N;
                            TX_SOP_N(i) <= RX_SOP_N;
                            TX_EOP_N(i) <= RX_EOP_N;
                            TX_SRC_RDY_N(i) <= RX_SRC_RDY_N;
                            tx_sending_eof(i) <= (not RX_EOF_N) and (not RX_SRC_RDY_N);
                        end if;
                    else
                        TX_SRC_RDY_N(i) <= '1';
                        tx_sending_eof(i) <= '0';
                    end if;
                elsif (tx_send_start = '1' and (flows_counter_all = '1' or i < flows_counter_fast)) then
                    -- Send the START word, target supposed ready (true thanks to config_remover)
                    -- only to the configured flow generators
                    tx_data_a(i) <= (others => '0');
                    tx_rem_a(i) <= (others => '0');
                    TX_SOF_N(i) <= '0';
                    TX_EOF_N(i) <= '0';
                    TX_SOP_N(i) <= '0';
                    TX_EOP_N(i) <= '0';
                    TX_SRC_RDY_N(i) <= '0';
                    tx_sending_eof(i) <= '0';
                else
                    TX_SRC_RDY_N(i) <= '1';
                    tx_sending_eof(i) <= '0';
                end if;
            end if;
        end process;
    end generate;

    -- Reconfiguration signal
    reconfigure: process(CLK) begin
        RECONF <= tx_send_reconf;
    end process;

    -- Merge output FrameLinks
    merge: for i in 0 to FLOW_COUNT-1 generate
        TX_DATA(64 * (i+1) - 1 downto 64*i) <= tx_data_a(i);
        TX_REM(3 * (i+1) - 1 downto 3*i) <= tx_rem_a(i);
    end generate;

end Behavioral;
