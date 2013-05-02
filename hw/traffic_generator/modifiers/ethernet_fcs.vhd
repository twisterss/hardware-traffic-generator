----------------------------------------------------------------------------------
-- Computes and sets the FCS field of Ethernet (CRC32 calculation)
-- This modifier sets the FCS field on the last bytes of each frame if configured.
-- A delay of 1 clock cycle is incurred on the bus, processing is never stopped.
--
-- Configuration:
-- - First (and only) word:
--      - id: 8 bits
--      - padding
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ethernet_fcs is
    generic (
        ID              : std_logic_vector(7 downto 0) := X"02"
    );
    port (
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
end ethernet_fcs;

architecture Behavioral of ethernet_fcs is

    -- FSM
    type fsm_state is (WaitingConfig, Transparent, WaitForFrameLength, SkipNetcopeHeader, InFrame);
    signal state                    : fsm_state;
    signal state_nxt                : fsm_state;

    -- Management of the position in the frame
    signal store_length             : std_logic;
    signal in_frame_data            : std_logic;
    signal in_frame_data_stored     : std_logic;
    -- number of bytes of the frame: does not include NetCope header but does include FCS
    signal remaining_bytes          : unsigned(15 downto 0);
    signal remaining_bytes_stored   : unsigned(15 downto 0);
    signal remaining_bytes_no_crc   : unsigned(15 downto 0);
    -- valid when in frame data, set to 1 only if this is the first data word
    signal first_word               : std_logic;
    -- should some of the received data be included in CRC computation?
    signal crc_data_received        : std_logic;
    
    -- CRC connections
    signal crc_data_bytes           : std_logic_vector(3 downto 0);
    signal crc_inv_in               : std_logic_vector(31 downto 0);
    signal crc_inv_out              : std_logic_vector(31 downto 0);
    signal crc                      : std_logic_vector(31 downto 0);

    -- FrameLink management
    signal rx_data_stored           : std_logic_vector(63 downto 0);
    signal tx_data_crc              : std_logic_vector(63 downto 0);
    signal fl_receiving             : std_logic;

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
            CLK         => CLK,
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

    -- FSM
    fsm_sync: process (RESET, CLK) begin
        if (RESET = '1') then
            state <= WaitingConfig;
        elsif (rising_edge(CLK)) then
            state <= state_nxt;
        end if;
    end process;

    fsm_async: process (state, fl_receiving, rx_sop_n_int, rx_eop_n_int, rx_data_int, rx_sof_n_int, rx_eof_n_int, RECONF) begin
        state_nxt <= state;
        store_length <= '0';
        in_frame_data <= '0';

        case state is
            when WaitingConfig =>
                if (fl_receiving = '1') then
                    if (rx_sop_n_int ='0' and rx_data_int(63 downto 56) = ID) then
                        -- Received the proper configuration word
                        state_nxt <= WaitForFrameLength;
                    elsif (rx_eof_n_int = '0') then
                        -- End of configuration without being configured
                        state_nxt <= Transparent;
                    end if;
                end if;
            when Transparent =>
                -- Nothing to do: forward traffic
            when WaitForFrameLength =>
                if (fl_receiving = '1' and rx_sof_n_int = '0') then
                    -- Received the first word of a frame
                    store_length <= '1';
                    if (rx_eop_n_int = '0') then
                        state_nxt <= InFrame;
                    else
                        state_nxt <= SkipNetcopeHeader;
                    end if;
                end if;
            when SkipNetcopeHeader =>
                if (fl_receiving = '1' and rx_eop_n_int = '0') then
                    -- End of NetCOPE header
                    state_nxt <= InFrame;
                end if;
            when InFrame =>
                in_frame_data <= '1';
                if (fl_receiving = '1' and rx_eof_n_int = '0') then
                    -- Received the last word of the frame
                    state_nxt <= WaitForFrameLength;
                end if;
            when others =>
        end case;

        -- Restart signal watched in all states
        if (RECONF = '1') then
            state_nxt <= WaitingConfig;
        end if;
    end process;

    -- Frame position management
    remaining_bytes_no_crc <= remaining_bytes - 4;
    crc_data_received <= '1' when (in_frame_data = '1' and remaining_bytes > 4 and fl_receiving = '1') else '0';
    manage_pos:process (CLK) begin
        if (rising_edge(CLK)) then
            if (store_length = '1') then
                remaining_bytes <= unsigned(rx_data_int(15 downto 0)) - 16;
                first_word <= '1';
            elsif (in_frame_data = '1' and fl_receiving = '1') then
                remaining_bytes <= remaining_bytes - 8;
                first_word <= '0';
            end if;
        end if;
    end process;

    -- CRC calculation
    crc_inv_in <= (others => '1') when first_word = '1' else crc_inv_out;
    crc_data_bytes <= "1000" when (remaining_bytes > 11) else std_logic_vector(remaining_bytes_no_crc(3 downto 0));

    crc_calculator: entity work.crc32_8bytes
    PORT MAP (
        CLK => CLK,
        CRC_INV_IN => crc_inv_in,
        DATA => rx_data_int,
        DATA_BYTES => crc_data_bytes,
        EN => crc_data_received,
        CRC_INV_OUT => crc_inv_out,
        CRC => crc
    );

    -- FrameLink manager
    send_fcs: process (rx_data_stored, remaining_bytes_stored, crc) begin
        -- choose where the CRC should be sent
        case remaining_bytes_stored is
            when X"000B" =>
                tx_data_crc <= crc(7 downto 0) & rx_data_stored(55 downto 0);
            when X"000A" =>
                tx_data_crc <= crc(15 downto 0) & rx_data_stored(47 downto 0);
            when X"0009" =>
                tx_data_crc <= crc(23 downto 0) & rx_data_stored(39 downto 0);
            when X"0008" =>
                tx_data_crc <= crc & rx_data_stored(31 downto 0);
            when X"0007" =>
                tx_data_crc <= X"00" & crc & rx_data_stored(23 downto 0);
            when X"0006" =>
                tx_data_crc <= X"0000" & crc & rx_data_stored(15 downto 0);
            when X"0005" =>
                tx_data_crc <= X"000000" & crc & rx_data_stored(7 downto 0);
            when X"0004" =>
                tx_data_crc <= X"00000000" & crc;
            when X"0003" =>
                tx_data_crc <= X"0000000000" & crc(31 downto 8);
            when X"0002" =>
                tx_data_crc <= X"000000000000" & crc(31 downto 16);
            when X"0001" =>
                tx_data_crc <= X"00000000000000" & crc(31 downto 24);
            when others =>
                tx_data_crc <= rx_data_stored;
        end case;
    end process;

    fl_receiving <= '1' when (rx_src_rdy_n_int = '0' and TX_DST_RDY_N = '0') else '0';
    rx_dst_rdy_n_int <= TX_DST_RDY_N;
    TX_DATA <= rx_data_stored when (in_frame_data_stored = '0') else tx_data_crc;
    send_data:process (CLK, RESET) begin
        if (RESET = '1') then
            TX_SRC_RDY_N <= '1';
            in_frame_data_stored <= '0';
        elsif (rising_edge(CLK)) then
            if (RECONF = '1') then
                -- Forget data remaining to send if reconf
                TX_SRC_RDY_N <= '1';
            elsif (TX_DST_RDY_N = '0') then
                rx_data_stored <= rx_data_int;
                TX_REM <= rx_rem_int;
                TX_SOF_N <= rx_sof_n_int;
                TX_EOF_N <= rx_eof_n_int;
                TX_SOP_N <= rx_sop_n_int;
                TX_EOP_N <= rx_eop_n_int;
                TX_SRC_RDY_N <= rx_src_rdy_n_int;
                in_frame_data_stored <= in_frame_data;
                remaining_bytes_stored <= remaining_bytes;
            end if;
        end if;
    end process;

end Behavioral;

