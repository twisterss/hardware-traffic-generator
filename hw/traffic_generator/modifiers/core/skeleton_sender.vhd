----------------------------------------------------------------------------------
-- Skeleton_Sender
-- Description : Skeleton sender is the first block of the pipeline used to generate traffic. It wiil first receive his configuration and then, when receiving
-- the start word, will produce a certain number of packet according to the configuration.
--
-- Configuration : first byte : id (generic typically x"01") +  4 next bytes : nb iteration + 1 byte empty + 2 bytes : nb_bytes into the skeleton  (==> 8 bytes)
--                       (example in hexa >>> 01 + 00000006 + 00 +  00FF == skeleton sender ID + 6 iteration + empty byte + 256 bytes into the skeleton )
--                       then, comes the skeleton itself (number of configuration lines = nb_bytes / 8 )
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Skeleton_Sender is
generic(
        ID              : std_logic_vector(7 downto 0) := x"01"; --one byte to call the skeleton_sender during configuration
        START_ID        : std_logic_vector(7 downto 0) := X"00" -- how does the start byte look like
    );
port(
        CLK             : in std_logic;
        RESET           : in std_logic;
        RECONF          : in std_logic;
        --Framelink RX signals
        RX_SOF_N        : in std_logic;
        RX_SOP_N        : in std_logic;
        RX_EOF_N        : in std_logic;
        RX_EOP_N        : in std_logic;
        RX_SRC_RDY_N    : in std_logic;
        RX_REM          : in std_logic_vector(2 downto 0);
        RX_DATA         : in std_logic_vector(63 downto 0);
        RX_DST_RDY_N    : out std_logic;
        --Framelink TX signals
        TX_SOF_N        : out std_logic;
        TX_SOP_N        : out std_logic;
        TX_EOF_N        : out std_logic;
        TX_EOP_N        : out std_logic;
        TX_SRC_RDY_N    : out std_logic;
        TX_REM          : out std_logic_vector(2 downto 0);
        TX_DATA         : out std_logic_vector(63 downto 0);
        TX_DST_RDY_N    : in std_logic
    );

end Skeleton_Sender;

architecture a_SkeletonSender of Skeleton_Sender is

---- signals ----
    type fsm_state is (WaitingConf, Configuring, WaitingStart, NCAdding1, NCAdding2, Transmitting);
    signal state                : fsm_state;
    signal next_state       : fsm_state;

    -- flags --
    signal save_nb_iter     : std_logic; -- 1 = saving configuration , 0 = not saving configuration
    signal save_nb_lines    : std_logic; -- 1 = saving number of lines in ram, 0 = do nothing
    signal framelink_man    : std_logic; -- 1 = managing framelink bus, 0 = only transmitting framelink bus
    signal nb_iter_done     : std_logic_vector(31 downto 0); --number of iterations effectively done by SkSender - effectively counted
    signal nb_iter          : std_logic_vector(31 downto 0); --number of iteration of SkeletonSender, n= 3 means 3 frames after configuration, read in conf
    signal we_nb_iter_done  : std_logic; -- flag for incrementing nb_iter_done
    signal nb_bytes         : std_logic_vector(15 downto 0); -- number of bytes in the skeleton
    signal nb_lines         : std_logic_vector(7 downto 0); --number of lines written in the RAM
    signal NC_we_1          : std_logic; --first 8 bytes of netcope write enable
    signal NC_we_2          : std_logic; --next and last 8 bytes netcope write enable

    -- framelink bus flags --
    signal en_rx_dst_rdy    : std_logic; -- flag for enabling RX_DST_RDY_N, currently useless
    signal en_tx_src_rdy    : std_logic; -- flag for enabling TX_SRC_RDY_N
    signal en_tx_sof        : std_logic; -- flag for enabling TX_SOF_N
    signal en_tx_eof        : std_logic; -- flag for enabling TX_EOF_N
    signal en_tx_sop        : std_logic; -- flag for enabling TX_SOP_N
    signal en_tx_eop        : std_logic; -- flag for enabling TX_EOP_N
    signal en_tx_rem        : std_logic; -- flag for enabling TX_REM

    -- RAM related signals --
    signal ram_addr         : std_logic_vector(7 downto 0);
    signal ram_we           : std_logic;
    signal ram_re           : std_logic;
    signal ram_dout         : std_logic_vector(63 downto 0);
    signal en_ram_count     : std_logic;
    signal reset_ram_addr   : std_logic;

begin

-- RAM mapping --
RAM_ss : entity work.single_port_ram
    generic map(
        DATA_WIDTH => 64,
        ADDR_WIDTH => 8
    )
    port map(
        CLK     => CLK,
        DIN     => RX_DATA,
        ADDR    => ram_addr,
        EN      => ram_re,
        WE      => ram_we,
        DOUT    => ram_dout
    );


---- processes ----

-- State sequencing process which handle reconfiguration too
Sequencing : process (CLK, RESET)

    begin

    if RESET = '1' then
        state <= WaitingConf;
    elsif rising_edge(CLK) then
        if RECONF = '1' then
            state <= WaitingConf;
        else
            state <= next_state;
        end if;
    end if;

end process Sequencing;


-- Finite state machine process
FSM_SS : process (state, RX_SRC_RDY_N,RX_SOP_N, RX_DATA, RX_EOP_N, TX_DST_RDY_N, nb_lines, ram_addr, nb_iter, nb_iter_done)

    begin

    --default values of signals
    next_state          <= state;

    we_nb_iter_done <= '0';
    save_nb_iter        <= '0';
    save_nb_lines       <= '0';
    ram_we              <= '0';
    ram_re              <= '0';
    en_ram_count        <= '0';
    reset_ram_addr      <= '0';
    framelink_man       <= '0';
    NC_we_1             <= '0';
    NC_we_2             <= '0';
    
    en_rx_dst_rdy       <= '0';
    en_tx_src_rdy       <= '0';
    en_tx_sof           <= '0';
    en_tx_eof           <= '0';
    en_tx_sop           <= '0';
    en_tx_eop           <= '0';
    en_tx_rem           <= '0';

    case state is

        -- waiting of configuration state
        when WaitingConf =>
            if RX_SRC_RDY_N ='0' and TX_DST_RDY_N ='0' and RX_SOP_N ='0' and RX_DATA(63 downto 56) = ID then --if we get the begining of a part
                save_nb_iter <= '1'; -- writing number of iteration
                next_state <= Configuring;
            else
                next_state <= WaitingConf;
            end if;

        -- reception state
        when Configuring =>
            
            if RX_SRC_RDY_N = '0' then
                ram_we          <= '1'; --reading and writing SkeletonSender configuration into the RAM
                en_ram_count    <= '1';
                
                if RX_EOP_N = '1' then -- while it's not the end of the configuration frame of SkeletonSender
                    next_state <= Configuring;
                else -- if we get the last part of SkeletonSender configuration
                    --reading and writing SkeletonSender LAST part of configuration into the RAM
                    next_state <= WaitingStart; -- we received the last part of configuration for SkeletonSender
                end if;
            else
                next_state <= Configuring;
            end if;

        -- waiting for the start-frame state
        when WaitingStart =>
            
            if RX_DATA(63 downto 56) = START_ID and RX_SOP_N = '0' and RX_SRC_RDY_N = '0' then -- case where we receive a start frame
                framelink_man   <= '1';
                
                save_nb_lines <= '1';
                next_state <= NCAdding1;
            else
                next_state <= WaitingStart;
            end if;

        -- netCope header adding states
        when NCAdding1 =>
            framelink_man   <= '1';
            en_tx_src_rdy   <= '1';
            en_tx_sof       <= '1';
            en_tx_sop       <= '1';
            reset_ram_addr  <= '1';
            NC_we_1         <= '1'; -- TX_DATA <= netcope header 1st 8 bytes
            
            if TX_DST_RDY_N = '0' then
                next_state  <= NCAdding2;
            else
                next_state  <= NCAdding1;
            end if;

        when NCAdding2 =>
            framelink_man   <= '1';
            en_tx_eop       <= '1';
            en_tx_src_rdy   <= '1';
            NC_we_2         <= '1'; -- TX_DATA <= netcope header 2nd 8 bytes
            
            if TX_DST_RDY_N = '0' then
                en_ram_count        <= '1';
                ram_re              <= '1';
                we_nb_iter_done <= '1';
                next_state          <= Transmitting;
            else
                next_state <= NCAdding2;
            end if;

        -- transmitting state => spitting bits until we reach the right number of iterations
        when Transmitting =>
            framelink_man   <= '1';
            
            if TX_DST_RDY_N = '0' then
                en_tx_src_rdy   <= '1';
                en_ram_count    <= '1';
                ram_re          <= '1';
                
                if nb_lines = ram_addr then --we reached the top of the ram > end of a frame
                    en_tx_eof <= '1'; --end of frame
                    en_tx_eop <= '1'; --end of part
                    en_tx_rem <= '1'; -- inserting drem
                    if nb_iter_done = nb_iter then
                        -- stop sending, number of iteration reached
                        next_state <= WaitingStart;
                    else
                        next_state <= NCAdding1;
                    end if;
                else
                    if ram_addr = x"01" then
                        en_tx_sop <= '1';
                    end if;
                    next_state <= Transmitting;
                end if;
            else
                next_state <= Transmitting;
            end if;

        when others =>
            next_state <= WaitingConf;
    end case;


end process FSM_SS;

-- process for saving nb_iter and nb_bytes 
SaveConfig : process(CLK)

    begin

    if rising_edge(CLK) then
        if save_nb_iter = '1' then
            nb_iter     <= RX_DATA(55 downto 24);
            nb_bytes <= RX_DATA(15 downto 0);
        end if;
    end if;

end process SaveConfig;

-- process for saving number of lines in RAM
SaveNbLines : process(CLK)

    begin

    if rising_edge(CLK) then
        if save_nb_lines = '1' then
            nb_lines <= ram_addr;
        end if;
    end if;

end process SaveNbLines;

-- process for saving number of iterations done since we start sending
NbIterDone : process(CLK, RESET)

    begin

    if RESET = '1' then
        nb_iter_done <= x"00000000";
    elsif rising_edge(CLK) then
        if RECONF = '1' then
            nb_iter_done <= x"00000000";
        elsif we_nb_iter_done = '1' then
            nb_iter_done <= std_logic_vector(unsigned(nb_iter_done)+1);
        end if;
    end if;

end process NbIterDone;

--counting process, enabling configuration writing into the RAM (=Skeleton saving process)
Counter : process(CLK, RESET)

    begin

    if RESET='1' then
        ram_addr <= x"00";
    elsif rising_edge(CLK) then
        if en_ram_count = '1' then
            ram_addr <= std_logic_vector(unsigned(ram_addr) + 1);
        elsif reset_ram_addr = '1' then -- when we reach the NCAdding state, reinitializing ram_addr
            ram_addr <= x"00";
        end if;
    end if;

end process Counter;


-- NetCope header adding and TX_DATA managing
NetcopeHeader: process(CLK)

    begin

    if rising_edge(CLK) then
        if TX_DST_RDY_N = '0' then -- in case the next block isn't ready, keeping the value
            if framelink_man = '1' then
                if NC_we_1 = '1' then
                    TX_DATA <= x"00000000000C" & std_logic_vector(unsigned(nb_bytes) +16);
                elsif NC_we_2 = '1' then
                    TX_DATA <= (others=>'0');
                else
                    TX_DATA <= ram_dout;
                end if;
            else
                TX_DATA <= RX_DATA;
            end if;
        end if;
    end if;

end process NetcopeHeader;


--framelink signals management process (except TX_DATA)
FrameLinkMan : process(CLK)

    begin

    if rising_edge(CLK) then
        if TX_DST_RDY_N = '0' then
            if framelink_man = '0' then
                RX_DST_RDY_N    <= TX_DST_RDY_N;
                TX_SRC_RDY_N    <= RX_SRC_RDY_N;
                TX_SOF_N        <= RX_SOF_N;
                TX_SOP_N        <= RX_SOP_N;
                TX_EOF_N        <= RX_EOF_N;
                TX_EOP_N        <= RX_EOP_N;
                TX_REM          <= RX_REM;
            else -- transmitting
                if en_rx_dst_rdy = '1' then
                    RX_DST_RDY_N <= '0';
                else
                    RX_DST_RDY_N <= '1';
                end if;
                if en_tx_src_rdy = '1' then
                    TX_SRC_RDY_N <= '0';
                else
                    TX_SRC_RDY_N <= '1';
                end if;
                if en_tx_sof = '1' then
                    TX_SOF_N <= '0';
                else
                    TX_SOF_N <= '1';
                end if;
                if en_tx_eof = '1' then
                    TX_EOF_N <= '0';
                else
                    TX_EOF_N <= '1';
                end if;
                if en_tx_sop = '1' then
                    TX_SOP_N <= '0';
                else
                    TX_SOP_N <= '1';
                end if;
                if en_tx_eop = '1' then
                    TX_EOP_N <= '0';
                else
                    TX_EOP_N <= '1';
                end if;
                if en_tx_rem = '1' then
                    TX_REM <= std_logic_vector(unsigned(nb_bytes(2 downto 0)) -1);
                else
                    TX_REM <= "111";
                end if;
            end if;
        end if;
    end if;

end process FrameLinkMan;

end a_SkeletonSender;