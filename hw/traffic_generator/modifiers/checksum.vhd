----------------------------------------------------------------------------------
-- Computes a checksum value and sets it. Works for the IP, UDP or TCP checksum.
--
-- Configuration: 
-- - First (and only) word:
--      - id: 8 bits
--      - computation start offset (in bytes from packet start, must be even): 11 bits
--      - computation end offset (in bytes from packet start): 11 bits
--      - value offset (in bytes from packet start, first of the 2 bytes): 11 bits
--      - IP header start offset (set to 0 if unused): 11 bits
--      - checksum type (0: no pseudo-header, 1: IPv4 pseudo-header, 2: IPv6 pseudo-header (to be implemented)): 2 bits 
--      - padding
--
-- Notes : 
-- - Checksum bytes must be set to zero in the skeleton in order to compute a proper Checksum
-- - A checksum is 2-bytes long
-- - If the computation end offset is after the end of the packet, the computation stops at the end of the packet
--
-- Not implemented yet :
-- - IPv6 pseudo-header calculation
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ceil;

entity checksum is
    generic (
        -- Configuration identifier
        ID : std_logic_vector(7 downto 0) := x"03";
        -- Maximum number of words in 1 frame
        MAX_WORDS_PER_FRAME : integer := 256;
        -- Minimum number of words in 1 frame
        MIN_WORDS_PER_FRAME : integer := 8
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
end checksum;

architecture Behavioral of checksum is

    -- Maximum number of frames in the FIFO
    constant MAX_FRAMES         : integer := integer(ceil(real(MAX_WORDS_PER_FRAME) / real(MIN_WORDS_PER_FRAME)));

    -- Size of the pseudo-header masks
    constant IPV4_MASK_BYTES    : integer := 20;

    -- FSM states
    type fsm_state is (WaitingConf, Transparent, WaitingFirstFrame, SkipHeader, InData);
    signal state_comp           : fsm_state;
    signal state_comp_nxt       : fsm_state;
    signal state_ins            : fsm_state;
    signal state_ins_nxt        : fsm_state;

    -- Configuration data
    signal store_conf           : std_logic;
    signal checksum_start       : unsigned(10 downto 0); -- start byte
    signal checksum_end         : unsigned(10 downto 0); -- stop byte included in computation
    signal checksum_offset      : unsigned(10 downto 0); -- where the checksum is located
    signal checksum_ip          : unsigned(10 downto 0); -- byte offset of the IP header
    signal checksum_type        : std_logic_vector(1 downto 0); --presence and type of pseudo header

    -- FRAME fifo signals
    signal keep_fifo_empty      : std_logic;
    signal stop_sending         : std_logic;

    signal rx_dst_rdy_n_int     : std_logic;
    signal tx_src_rdy_n_int     : std_logic;
    signal receiving_data       : std_logic;
    signal sending_data         : std_logic;

    signal ffifo_rx_src_rdy_n   : std_logic;
    signal ffifo_rx_dst_rdy_n   : std_logic;
    signal ffifo_tx_data        : std_logic_vector(63 downto 0);
    signal ffifo_tx_sof_n       : std_logic;
    signal ffifo_tx_eof_n       : std_logic;
    signal ffifo_tx_sop_n       : std_logic;
    signal ffifo_tx_eop_n       : std_logic;
    signal ffifo_tx_src_rdy_n   : std_logic;
    signal ffifo_tx_dst_rdy_n   : std_logic;

    -- Constants for input bits selection
    type ext_mask_array is array (0 to 8) of std_logic_vector(63 downto 0);
    -- Mask depending on the data start offset
    constant start_mask           : ext_mask_array := (X"FFFFFFFFFFFFFFFF", X"FFFFFFFFFFFFFFFF", X"FFFFFFFFFFFF0000", X"FFFFFFFFFFFF0000", X"FFFFFFFF00000000", X"FFFFFFFF00000000", X"FFFF000000000000", X"FFFF000000000000", X"0000000000000000");
    -- Mask depending on the data end offset
    constant end_mask             : ext_mask_array := (X"00000000000000FF", X"000000000000FFFF", X"0000000000FFFFFF", X"000000FFFFFFFFFF", X"000000FFFFFFFFFF", X"0000FFFFFFFFFFFF", X"00FFFFFFFFFFFFFF", X"FFFFFFFFFFFFFFFF", X"0000000000000000");
    
    -- Mask for the IPv4 pseudo-header depending on the IP header shift
    type ipv4_mask_array is array (0 to IPV4_MASK_BYTES+7) of std_logic_vector(63 downto 0);
    function init_ipv4_mask return ipv4_mask_array is
        variable mask : ipv4_mask_array;
        variable shifted_full_mask : std_logic_vector(IPV4_MASK_BYTES*8-1 downto 0);
        constant full_mask : std_logic_vector(IPV4_MASK_BYTES*8-1 downto 0) := X"FFFFFFFFFFFFFFFF0000FF0000000000FFFF0000";
    begin
        -- Store the IPv4 header mask for each shift value
        for i in -7 to IPV4_MASK_BYTES-1 loop
            -- Shift manually
            shifted_full_mask := full_mask;
            if i < 0 then
                for j in 1 to -i loop
                    shifted_full_mask := shifted_full_mask(IPV4_MASK_BYTES*8-9 downto 0) & X"00";
                end loop;
            else
                for j in 1 to i loop
                    shifted_full_mask := X"00" & shifted_full_mask(IPV4_MASK_BYTES*8-1 downto 8);
                end loop;
            end if;
            mask(i+7) := shifted_full_mask(63 downto 0);
        end loop;
        return mask;
    end;
    constant ipv4_mask            : ipv4_mask_array := init_ipv4_mask;

    -- Incoming bytes counter
    signal bytes_in             : unsigned(10 downto 0);

    -- Mask management
    signal header_mask          : std_logic_vector(63 downto 0);
    signal global_mask          : std_logic_vector(63 downto 0);

    -- Checksum computation
    signal checksum_en          : std_logic;
    signal checksum_in          : std_logic_vector(63 downto 0);
    signal checksum_int         : unsigned(31 downto 0);
    signal checksum_int_base    : unsigned(31 downto 0);
    signal checksum_subtract    : std_logic_vector(15 downto 0);
    signal checksum             : std_logic_vector(15 downto 0);
    signal checksum_rdy         : std_logic;
    signal checksum_rdy_reg     : std_logic;
    signal checksum_int_rdy     : std_logic;
    signal checksum_data_rdy    : std_logic;
    signal checksum_stop        : std_logic;
    signal checksum_save        : std_logic;
    signal checksum_rst         : std_logic;
    signal checksum_int_rst     : std_logic;
    signal start_offset         : unsigned(10 downto 0);
    signal end_offset           : unsigned(10 downto 0);

    -- Outgoing bytes counter 
    signal bytes_out            : unsigned(10 downto 0);
    signal bytes_out_en         : std_logic;
    signal bytes_out_rst        : std_logic;

    -- Checksum fifo output signals
    signal checksum_out         : std_logic_vector(15 downto 0);
    signal checksum_out_read    : std_logic;
    signal checksum_out_empty   : std_logic;

    -- Checksum insertion
    signal insert_en            : std_logic;
    signal insert_shift         : unsigned(10 downto 0);

begin

    -- Fifo to store computed checksums
    -- considered never full
    checksum_fifo : entity work.FALLTHROUGH_FIFO
        generic map(
            DATA_WIDTH  => 16,
            DEPTH       => MAX_FRAMES
        )
        port map(
            CLK         => CLK,
            RESET       => RESET,
            DATA_IN     => checksum,
            WRITE_EN    => checksum_save,
            READ_EN     => checksum_out_read,
            DATA_OUT    => checksum_out,
            STATE_EMPTY => checksum_out_empty
        );

    -- Fifo to store packets while computing
    frame_fifo : entity work.FRAME_FIFO
        generic map(
            DATA_WIDTH  => 64,
            DEPTH       => MAX_WORDS_PER_FRAME
        )
        port map(
            CLK         => CLK,
            RESET           => RESET,

            -- RX FrameLink interface
            RX_DATA         => RX_DATA,
            RX_REM          => RX_REM,
            RX_SOF_N        => RX_SOF_N,
            RX_EOF_N        => RX_EOF_N,
            RX_SOP_N        => RX_SOP_N,
            RX_EOP_N        => RX_EOP_N,
            RX_SRC_RDY_N    => ffifo_rx_src_rdy_n,
            RX_DST_RDY_N    => ffifo_rx_dst_rdy_n,

            -- TX FrameLink interface
            TX_DATA         => ffifo_tx_data,
            TX_REM          => TX_REM,
            TX_SOF_N        => ffifo_tx_sof_n,
            TX_EOF_N        => ffifo_tx_eof_n,
            TX_SOP_N        => ffifo_tx_sop_n,
            TX_EOP_N        => ffifo_tx_eop_n,
            TX_SRC_RDY_N    => ffifo_tx_src_rdy_n,
            TX_DST_RDY_N    => ffifo_tx_dst_rdy_n
        );

    -- Frame FIFO connections
    -- keep_fifo_empty is used to act as if RX and TX were connected without FIFO
    -- stop_sending is used to stop emptying the FIFO
    ffifo_rx_src_rdy_n  <= RX_SRC_RDY_N or (keep_fifo_empty and TX_DST_RDY_N);
    RX_DST_RDY_N        <= rx_dst_rdy_n_int;
    rx_dst_rdy_n_int    <= TX_DST_RDY_N when (keep_fifo_empty = '1') else ffifo_rx_dst_rdy_n;
    TX_SOF_N            <= ffifo_tx_sof_n;
    TX_EOF_N            <= ffifo_tx_eof_n;
    TX_SOP_N            <= ffifo_tx_sop_n;
    TX_EOP_N            <= ffifo_tx_eop_n;
    TX_SRC_RDY_N        <= tx_src_rdy_n_int;
    tx_src_rdy_n_int    <= ffifo_tx_src_rdy_n or stop_sending;
    ffifo_tx_dst_rdy_n  <= TX_DST_RDY_N or stop_sending;

    receiving_data      <= not (RX_SRC_RDY_N or rx_dst_rdy_n_int);
    sending_data        <= not (tx_src_rdy_n_int or TX_DST_RDY_N);

    -- FSM states management
    process (CLK, RESET) begin
        if RESET = '1' then
            state_comp <= WaitingConf;
            state_ins <= WaitingConf;
        elsif rising_edge(CLK) then
            if RECONF = '1' then
                state_comp <= WaitingConf;
                state_ins <= WaitingConf;
            else
                state_comp <= state_comp_nxt;
                state_ins <= state_ins_nxt;
            end if;
        end if;
    end process;

    -- Receiving FSM (computes the checksum)
    process (state_comp, receiving_data, checksum_rdy, RX_SOP_N, RX_EOP_N, RX_SOF_N, RX_DATA, RX_EOF_N) begin
        state_comp_nxt  <= state_comp;
        store_conf      <= '0';
        keep_fifo_empty <= '0';
        checksum_en     <= '0';
        checksum_rst    <= '0';
        checksum_stop   <= '0';

        case state_comp is
            -- Waiting for configuration data
            when WaitingConf =>
                -- FIFO is kept empty to avoid hiding busy modifiers after this one
                keep_fifo_empty <= '1';
                if (receiving_data = '1') then
                    if (RX_SOP_N ='0' and RX_DATA(63 downto 56) = ID) then
                        -- Configuration word
                        store_conf <= '1';
                        state_comp_nxt <= WaitingFirstFrame;
                    elsif (RX_EOF_N = '0') then
                        state_comp_nxt <= Transparent;
                    end if;
                end if;
            -- Not configured: forward data
            when Transparent =>
            -- Waiting for the first data frame
            when WaitingFirstFrame =>
                -- FIFO is kept empty to avoid hiding busy modifiers after this one
                keep_fifo_empty <= '1';
                if (receiving_data = '1' and RX_EOF_N = '0') then
                    state_comp_nxt <= SkipHeader;
                end if;
            -- Waiting for the header end
            when SkipHeader =>
                if (receiving_data = '1' and RX_EOP_N = '0') then
                    -- Reset as late as possible to leave time for checksum computation (guaranteed)
                    checksum_rst <= '1';
                    state_comp_nxt <= InData;
                end if;
            -- Receiving data and computing
            when InData =>
                if (receiving_data = '1') then
                    checksum_en <= '1';
                    if (RX_EOF_N = '0') then
                        state_comp_nxt <= SkipHeader;
                        -- Force the checksum to stop even if not at configured end offset
                        checksum_stop <= '1';
                    end if;
                end if;
            when others =>
        end case;
    end process;

    -- Configuration saving process
    process(CLK) begin
        if (rising_edge(CLK)) then
            if (store_conf = '1') then
                checksum_start   <= unsigned(RX_DATA(55 downto 45));
                checksum_end     <= unsigned(RX_DATA(44 downto 34));
                checksum_offset  <= unsigned(RX_DATA(33 downto 23));
                checksum_ip      <= unsigned(RX_DATA(22 downto 12));
                checksum_type    <= RX_DATA(11 downto 10);
            end if;
        end if;
    end process;

    -- Incoming bytes counter
    process(CLK) begin
        if (rising_edge(CLK)) then
            if (checksum_rst = '1') then
                bytes_in <= (others => '0');
            elsif (checksum_en = '1') then
                bytes_in <= bytes_in + 8;
            end if;
        end if;
    end process;

    -- Header mask management:
    -- depends on the checksum type
    -- and current offset in the packet
    process(bytes_in, checksum_type, checksum_ip) begin
        if (checksum_type = "01" and bytes_in + 7 >= checksum_ip and bytes_in <= checksum_ip + IPV4_MASK_BYTES - 1) then
            -- In IPv4 pseudo-header
            header_mask <= ipv4_mask(to_integer(bytes_in + 7 - checksum_ip));
        else
            header_mask <= (others => '0');
        end if;
    end process;

    -- Subtraction management: used to
    -- remove the IP header length if there is a IP pseudo-header:
    -- the pseudo-header takes the payload size, not the IP size
    -- Checked: this field is always valid at the good step in the checksum computation pipeline
    process(CLK, RESET) begin
        if (RESET = '1') then
            checksum_subtract <= (others => '0');
        elsif (rising_edge(CLK)) then
            if (checksum_en = '1') then
                if (checksum_type = "01" and bytes_in <= checksum_ip and bytes_in + 7 >= checksum_ip) then
                    checksum_subtract <= "00" & RX_DATA(to_integer((checksum_ip-bytes_in)*8 + 3) downto to_integer((checksum_ip-bytes_in)*8)) & "00" & X"00";
                end if;
            end if;
        end if;
    end process;

    -- Checksum pipeline input selection
    start_offset <= (3 => '1', others => '0') when (checksum_start > bytes_in + 7) else (checksum_start - bytes_in) when (bytes_in < checksum_start) else (others => '0');
    end_offset <= (3 => '1', others => '0') when (bytes_in > checksum_end) else (checksum_end - bytes_in) when (bytes_in + 7 > checksum_end) else (0 => '1', 1 => '1', 2 => '1', others => '0');
    global_mask <= (start_mask(to_integer(start_offset)) and end_mask(to_integer(end_offset))) or header_mask;
    process(CLK) begin
        if (rising_edge(CLK)) then
            -- Data ready signal (last data set)
            if (checksum_en = '1' and (bytes_in + 7 >= checksum_end or checksum_stop = '1')) then
                checksum_data_rdy <= '1';
            elsif (RESET = '1' or checksum_rst = '1') then
                checksum_data_rdy <= '0';
            end if;
            -- Set the good mask on checksum input
            if (checksum_en = '1') then
                checksum_in <= RX_DATA and global_mask;
            else 
                checksum_in <= (others => '0');
            end if;
        end if;
    end process;

    -- Checksum pipeline computation
    checksum_int_base <= (others => '0') when (checksum_int_rst = '1') else checksum_int;
    process(CLK) begin
        if (rising_edge(CLK)) then
            -- Sum input data bytes
            -- The carry is guaranteed to not overflow for much more than the packet size
            checksum_int <= checksum_int_base + unsigned(checksum_in(63 downto 48)) + unsigned(checksum_in(47 downto 32)) + unsigned(checksum_in(31 downto 16)) + unsigned(checksum_in(15 downto 0));
            -- Sum the carry to the current result: no overflow by construction
            -- Subtract the checksum_subtract value: used for IP pseudo-header computation
            checksum <= not(std_logic_vector(checksum_int(31 downto 16) + checksum_int(15 downto 0) - unsigned(checksum_subtract)));
        end if;
    end process;

    -- Checksum pipeline ready and reset propagation
    -- The save signal is at 1 during 1 clock cycle for each checksum
    checksum_save <= checksum_rdy and not checksum_rdy_reg;
    process(CLK) begin
        if (rising_edge(CLK)) then
            checksum_int_rst <= checksum_rst;
            checksum_int_rdy <= checksum_data_rdy;
            checksum_rdy <= checksum_int_rdy;
            -- For rising edge detection
            checksum_rdy_reg <= checksum_rdy;
        end if;
    end process;

    -- Sending FSM (insert the checksum in data)
    process (state_ins, ffifo_tx_sof_n, ffifo_tx_eop_n, ffifo_tx_eof_n, sending_data, checksum_out_empty, store_conf, bytes_out, checksum_offset) begin
        state_ins_nxt       <= state_ins;
        bytes_out_rst       <= '0';
        bytes_out_en        <= '0';
        insert_en           <= '0';
        stop_sending        <= '0';
        checksum_out_read   <= '0';

        case state_ins is
            -- Waits for the end of the configuration
            when WaitingConf =>
                if (sending_data = '1' and ffifo_tx_eof_n = '0') then
                    state_ins_nxt <= Transparent;
                elsif (store_conf = '1') then
                    state_ins_nxt <= WaitingFirstFrame;
                end if;
            -- Waits for reconfiguration
            when Transparent =>
            -- Waiting for the first data frame
            when WaitingFirstFrame =>
                if (sending_data = '1' and ffifo_tx_eof_n = '0') then
                    state_ins_nxt <= SkipHeader;
                end if;
            -- Waiting for the header end
            when SkipHeader =>
                bytes_out_rst <= '1';
                if (sending_data = '1' and ffifo_tx_eop_n = '0') then
                    state_ins_nxt <= InData;
                end if;
            -- Receiving data
            when InData =>
                if (bytes_out <= (checksum_offset + 1) and (bytes_out + 7) >= checksum_offset) then
                    -- Insert the checksum or stop the output flow
                    if (checksum_out_empty = '1') then
                        stop_sending <= '1';
                    else
                        insert_en <= '1';
                    end if;
                end if;
                if (sending_data = '1') then
                    bytes_out_en <= '1';
                    if (ffifo_tx_eof_n = '0') then
                        state_ins_nxt <= SkipHeader;
                        -- Go to next checksum
                        checksum_out_read <= '1';
                    end if;
                end if;
            when others =>
        end case;
    end process;

    -- Outgoing bytes counter
    process(CLK) begin
        if (rising_edge(CLK)) then
            if (bytes_out_rst = '1') then
                bytes_out <= (others => '0');
            elsif (bytes_out_en = '1') then
                bytes_out <= bytes_out + 8;
            end if;
        end if;
    end process;

    -- Insert the checksum value into TX_DATA
    insert_shift <= checksum_offset + 1 - bytes_out;
    process(insert_en, ffifo_tx_data, checksum_out, insert_shift) begin
            if insert_en = '0' then
                TX_DATA <= ffifo_tx_data;
            else
                case insert_shift(3 downto 0) is
                    when X"0" => 
                        TX_DATA <= ffifo_tx_data(63 downto 8) & checksum_out(7 downto 0);
                    when X"1" => 
                        TX_DATA <= ffifo_tx_data(63 downto 16) & checksum_out;
                    when X"2" => 
                        TX_DATA <= ffifo_tx_data(63 downto 24) & checksum_out & ffifo_tx_data(7 downto 0);
                    when X"3" => 
                        TX_DATA <= ffifo_tx_data(63 downto 32) & checksum_out & ffifo_tx_data(15 downto 0);
                    when X"4" => 
                        TX_DATA <= ffifo_tx_data(63 downto 40) & checksum_out & ffifo_tx_data(23 downto 0);
                    when X"5" => 
                        TX_DATA <= ffifo_tx_data(63 downto 48) & checksum_out & ffifo_tx_data(31 downto 0);
                    when X"6" => 
                        TX_DATA <= ffifo_tx_data(63 downto 56) & checksum_out & ffifo_tx_data(39 downto 0);
                    when X"7" => 
                        TX_DATA <= checksum_out & ffifo_tx_data(47 downto 0);
                    when X"8" => 
                        TX_DATA <= checksum_out(15 downto 8) & ffifo_tx_data(55 downto 0);
                    when others =>
                        TX_DATA <= (others => '-');
                end case;
            end if;
    end process;

end Behavioral;