----------------------------------------------------------------------------------
-- Merge a configurable number of flows together and respect each flow data rate.
-- A frame is sent only if fully received.
-- Each flow is checked for a full frame successively.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
USE ieee.math_real.log2;
USE ieee.math_real.ceil;

entity flow_merger is
    Generic (
        -- Number of flow generators connected in input
        FLOW_COUNT          : integer := 1;
        -- Maximum number of words in 1 frame
        MAX_WORDS_PER_FRAME : integer := 256;
        -- Minimum number of words in 1 frame
        MIN_WORDS_PER_FRAME : integer := 8
    );
    Port (
        CLK             : in std_logic;
        RESET           : in std_logic;
        -- Input FrameLinks (x FLOW_COUNT)
        RX_DATA         : in std_logic_vector(64*FLOW_COUNT-1 downto 0);
        RX_REM          : in std_logic_vector(3*FLOW_COUNT-1 downto 0);
        RX_SOF_N        : in std_logic_vector(FLOW_COUNT-1 downto 0);
        RX_EOF_N        : in std_logic_vector(FLOW_COUNT-1 downto 0);
        RX_SOP_N        : in std_logic_vector(FLOW_COUNT-1 downto 0);
        RX_EOP_N        : in std_logic_vector(FLOW_COUNT-1 downto 0);
        RX_SRC_RDY_N    : in std_logic_vector(FLOW_COUNT-1 downto 0);
        RX_DST_RDY_N    : out std_logic_vector(FLOW_COUNT-1 downto 0);
        -- Output FrameLoutk
        TX_DATA         : out std_logic_vector(63 downto 0);
        TX_REM          : out std_logic_vector(2 downto 0);
        TX_SOF_N        : out std_logic;
        TX_EOF_N        : out std_logic;
        TX_SOP_N        : out std_logic;
        TX_EOP_N        : out std_logic;
        TX_SRC_RDY_N    : out std_logic;
        TX_DST_RDY_N    : in std_logic;
        -- Synchronous reset
        RECONF          : in std_logic
    );
end flow_merger;

architecture Behavioral of flow_merger is

    -- Width of the flow count
    constant FLOW_COUNT_LOG     : integer := integer(ceil(log2(real(FLOW_COUNT+1))));
    -- Maximum number of frames in a fifo
    constant MAX_FRAMES         : integer := integer(ceil(real(MAX_WORDS_PER_FRAME) / real(MIN_WORDS_PER_FRAME)));
    -- Width of the frames count
    constant MAX_FRAMES_LOG     : integer := integer(ceil(log2(real(MAX_FRAMES+1))));

    -- Input of each FIFO (derived signals)
    signal fifo_rx_dst_rdy_n    : std_logic_vector(FLOW_COUNT-1 downto 0);

    -- Output of each FIFO
    type data_array is array(0 to FLOW_COUNT-1) of std_logic_vector(63 downto 0);
    type rem_array is array(0 to FLOW_COUNT-1) of std_logic_vector(2 downto 0);
    signal fifo_data            : data_array;
    signal fifo_rem             : rem_array;
    signal fifo_sof_n           : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_eof_n           : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_sop_n           : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_eop_n           : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_src_rdy_n       : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_dst_rdy_n       : std_logic_vector(FLOW_COUNT-1 downto 0);

    -- Output of the selected FIFO (derived signals)
    signal fifo_src_rdy_n_sel   : std_logic;
    signal fifo_eof_n_sel       : std_logic;

    -- Number of frames in each FIFO
    type frame_count_array is array(0 to FLOW_COUNT-1) of unsigned(MAX_FRAMES_LOG-1 downto 0);
    signal fifo_frames          : frame_count_array;
    signal fifo_frame_in        : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_frame_out       : std_logic_vector(FLOW_COUNT-1 downto 0);

    -- Selected flow
    type flow_count_array is array(0 to FLOW_COUNT-1) of unsigned(FLOW_COUNT_LOG-1 downto 0);
    signal fifo_selected            : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_selected_prev       : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_selected_nxt        : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_can_select          : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_selected_id         : unsigned(FLOW_COUNT_LOG-1 downto 0);
    signal fifo_selected_id_tmp     : flow_count_array;
    signal fifo_selected_none_tmp   : std_logic_vector(FLOW_COUNT-1 downto 0);
    signal fifo_selected_none       : std_logic;

    signal go_to_nxt_fifo           : std_logic;

begin

    -- Put received flows in FIFOs
    fifos: for i in 0 to FLOW_COUNT-1 generate
    
        -- FIFO connection
        RX_DST_RDY_N(i) <= fifo_rx_dst_rdy_n(i);
        fifo: entity work.frame_fifo
        generic map (
            DEPTH => MAX_WORDS_PER_FRAME
        ) port map (
            CLK => CLK,
            RESET => RESET,
            CLEAR => RECONF,
            RX_DATA => RX_DATA(64 * (i+1) - 1 downto 64*i),
            RX_REM => RX_REM(3 * (i+1) - 1 downto 3*i),
            RX_SOF_N => RX_SOF_N(i),
            RX_EOF_N => RX_EOF_N(i),
            RX_SOP_N => RX_SOP_N(i),
            RX_EOP_N => RX_EOP_N(i),
            RX_SRC_RDY_N => RX_SRC_RDY_N(i),
            RX_DST_RDY_N => fifo_rx_dst_rdy_n(i),
            TX_DATA => fifo_data(i),
            TX_REM => fifo_rem(i),
            TX_SOF_N => fifo_sof_n(i),
            TX_EOF_N => fifo_eof_n(i),
            TX_SOP_N => fifo_sop_n(i),
            TX_EOP_N => fifo_eop_n(i),
            TX_SRC_RDY_N => fifo_src_rdy_n(i),
            TX_DST_RDY_N => fifo_dst_rdy_n(i)
        );

        -- Enable the FIFO if selected
        fifo_dst_rdy_n(i) <= TX_DST_RDY_N or not fifo_selected(i);

        -- Count the number of full frames in the FIFO
        fifo_frame_in(i) <= not (RX_SRC_RDY_N(i) or fifo_rx_dst_rdy_n(i) or RX_EOF_N(i));
        fifo_frame_out(i) <= not (fifo_src_rdy_n(i) or fifo_dst_rdy_n(i) or fifo_sof_n(i));
        frame_counter: process(CLK, RESET) begin
            if RESET = '1' then
                fifo_frames(i) <= (others => '0');
            elsif rising_edge(CLK) then
                if (RECONF = '1') then
                    fifo_frames(i) <= (others => '0');
                elsif (fifo_frame_in(i) = '1' and fifo_frame_out(i) = '0') then
                    fifo_frames(i) <= fifo_frames(i) + 1;
                elsif (fifo_frame_in(i) = '0' and fifo_frame_out(i) = '1') then
                    fifo_frames(i) <= fifo_frames(i) - 1;
                end if;
            end if;
        end process;

        -- Select this FIFO next if the previous one is not ready to select
        -- or if the previous one is currently selected
        -- and if this FIFO has at least 1 full frame to send.
        fifo_selected_nxt(i) <= '1' when (fifo_can_select(i) = '1' and fifo_frames(i) > 0) else '0';

        fifo_select_first: if i = 0 generate
            fifo_can_select(i) <= '1' when (fifo_selected_prev(FLOW_COUNT-1) = '1' or (fifo_can_select(FLOW_COUNT-1) = '1' and fifo_selected_nxt(FLOW_COUNT-1) = '0')) else '0';
        end generate;
        fifo_select_next: if i > 0 generate
            fifo_can_select(i) <= '1' when (fifo_selected_prev(i-1) = '1' or (fifo_can_select(i-1) = '1' and fifo_selected_nxt(i-1) = '0')) else '0';
        end generate;      

        fifo_selection: process(CLK, RESET) begin
            if (RESET = '1') then
                fifo_selected(i) <= '0';
            elsif rising_edge(CLK) then
                if (RECONF = '1') then
                    fifo_selected(i) <= '0';
                elsif go_to_nxt_fifo = '1' then
                    fifo_selected(i) <= fifo_selected_nxt(i);
                end if;
            end if;
        end process;

    end generate;

    -- Decode the identifier of the currently selected FIFO
    fifo_selected_id <= fifo_selected_id_tmp(FLOW_COUNT-1);
    fifo_selected_none <= fifo_selected_none_tmp(FLOW_COUNT-1);
    decode_fifo_id: for i in 0 to FLOW_COUNT-1 generate
        first_decode: if i = 0 generate
            fifo_selected_id_tmp(0) <= (others => '0');
            fifo_selected_none_tmp(0) <= not fifo_selected(0);
        end generate;
        other_decodes: if i > 0 generate
            fifo_selected_id_tmp(i) <= fifo_selected_id_tmp(i-1) when (fifo_selected(i) = '0') else to_unsigned(i, FLOW_COUNT_LOG);
            fifo_selected_none_tmp(i) <= fifo_selected_none_tmp(i-1) when (fifo_selected(i) = '0') else '0';
        end generate;
    end generate;

    -- Keep the last selection to know the current priority
    keep_last_delected: process(CLK, RESET) begin
        if (RESET = '1') then
            fifo_selected_prev <= (0 => '1', others => '0');
        elsif (rising_edge(CLK)) then
            if (RECONF = '1') then
                fifo_selected_prev <= (0 => '1', others => '0');
            elsif (fifo_selected_none = '0') then
                fifo_selected_prev <= fifo_selected;
            end if;
        end if;
    end process; 

    -- Connect to output the proper FIFO
    TX_DATA <= fifo_data(to_integer(fifo_selected_id));
    TX_REM <= fifo_rem(to_integer(fifo_selected_id));
    TX_SOF_N <= fifo_sof_n(to_integer(fifo_selected_id));
    fifo_eof_n_sel <= fifo_eof_n(to_integer(fifo_selected_id));
    TX_EOF_N <= fifo_eof_n_sel;
    TX_SOP_N <= fifo_sop_n(to_integer(fifo_selected_id));
    TX_EOP_N <= fifo_eop_n(to_integer(fifo_selected_id));
    fifo_src_rdy_n_sel <= fifo_src_rdy_n(to_integer(fifo_selected_id));
    -- Not ready if no FIFO is selected
    TX_SRC_RDY_N <= '1' when (fifo_selected_none = '1') else fifo_src_rdy_n_sel;

    -- Decide when to go to the next FIFO
    go_to_nxt_fifo <= '1' when (fifo_selected_none = '1' or (TX_DST_RDY_N = '0' and fifo_src_rdy_n_sel = '0' and fifo_eof_n_sel = '0')) else '0';

end Behavioral;

