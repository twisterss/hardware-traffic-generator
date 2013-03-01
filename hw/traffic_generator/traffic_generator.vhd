----------------------------------------------------------------------------------
-- Top of the traffic generator, to be included directly in the application
--  * receive the configuration as input
--  * send traffic as output
--  * action and status should be connected to the computer
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity traffic_generator is
    Generic (
        FLOW_COUNT      : integer := 1
    );
    Port (
        CLK             : in std_logic;
        RESET           : in std_logic;
        -- Input FrameLink (configuration)
        RX_DATA         : in std_logic_vector(63 downto 0);
        RX_REM          : in std_logic_vector(2 downto 0);
        RX_SOF_N        : in std_logic;
        RX_EOF_N        : in std_logic;
        RX_SOP_N        : in std_logic;
        RX_EOP_N        : in std_logic;
        RX_SRC_RDY_N    : in std_logic;
        RX_DST_RDY_N    : out std_logic;
        -- Output FrameLink (traffic)
        TX_DATA         : out std_logic_vector(63 downto 0);
        TX_REM          : out std_logic_vector(2 downto 0);
        TX_SOF_N        : out std_logic;
        TX_EOF_N        : out std_logic;
        TX_SOP_N        : out std_logic;
        TX_EOP_N        : out std_logic;
        TX_SRC_RDY_N    : out std_logic;
        TX_DST_RDY_N    : in std_logic;
        -- Software communication
        STATUS          : out std_logic_vector(31 downto 0);
        ACTION          : in std_logic_vector(31 downto 0);
        ACTION_ACK      : out std_logic
    );
end traffic_generator;

architecture Behavioral of traffic_generator is

        -- FrameLink between the frame merger and the controller
        signal merged_data          : std_logic_vector(63 downto 0);
        signal merged_rem           : std_logic_vector(2 downto 0);
        signal merged_sof_n         : std_logic;
        signal merged_eof_n         : std_logic;
        signal merged_sop_n         : std_logic;
        signal merged_eop_n         : std_logic;
        signal merged_src_rdy_n     : std_logic;
        signal merged_dst_rdy_n     : std_logic;

        -- FrameLinks between the controller and generators
        signal control_data         : std_logic_vector(64*FLOW_COUNT-1 downto 0);
        signal control_rem          : std_logic_vector(3*FLOW_COUNT-1 downto 0);
        signal control_sof_n        : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal control_eof_n        : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal control_sop_n        : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal control_eop_n        : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal control_src_rdy_n    : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal control_dst_rdy_n    : std_logic_vector(FLOW_COUNT-1 downto 0);

        -- FrameLinks between generators and the flow merger
        signal gen_data         : std_logic_vector(64*FLOW_COUNT-1 downto 0);
        signal gen_rem          : std_logic_vector(3*FLOW_COUNT-1 downto 0);
        signal gen_sof_n        : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal gen_eof_n        : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal gen_sop_n        : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal gen_eop_n        : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal gen_src_rdy_n    : std_logic_vector(FLOW_COUNT-1 downto 0);
        signal gen_dst_rdy_n    : std_logic_vector(FLOW_COUNT-1 downto 0);

        -- Reconfiguration signal
        signal reconf           : std_logic;
begin

    -- Conversion module: merge frames using parts
    frame_merger: entity work.frame_merger
    port map (
        CLK => CLK,
        RESET => RESET,
        RX_DATA => RX_DATA,
        RX_REM => RX_REM,
        RX_SOF_N => RX_SOF_N,
        RX_EOF_N => RX_EOF_N,
        RX_SOP_N => RX_SOP_N,
        RX_EOP_N => RX_EOP_N,
        RX_SRC_RDY_N => RX_SRC_RDY_N,
        RX_DST_RDY_N => RX_DST_RDY_N,
        TX_DATA => merged_data,
        TX_REM => merged_rem,
        TX_SOF_N => merged_sof_n,
        TX_EOF_N => merged_eof_n,
        TX_SOP_N => merged_sop_n,
        TX_EOP_N => merged_eop_n,
        TX_SRC_RDY_N => merged_src_rdy_n,
        TX_DST_RDY_N => merged_dst_rdy_n
    );

    -- Global controller
    controller: entity work.control
    generic map (
        FLOW_COUNT => FLOW_COUNT
    ) port map (
        CLK => CLK,
        RESET => RESET,
        RX_DATA => merged_data,
        RX_REM => merged_rem,
        RX_SOF_N => merged_sof_n,
        RX_EOF_N => merged_eof_n,
        RX_SOP_N => merged_sop_n,
        RX_EOP_N => merged_eop_n,
        RX_SRC_RDY_N => merged_src_rdy_n,
        RX_DST_RDY_N => merged_dst_rdy_n,
        TX_DATA => control_data,
        TX_REM => control_rem,
        TX_SOF_N => control_sof_n ,
        TX_EOF_N => control_eof_n,
        TX_SOP_N => control_sop_n,
        TX_EOP_N => control_eop_n,
        TX_SRC_RDY_N => control_src_rdy_n,
        TX_DST_RDY_N => control_dst_rdy_n,
        RECONF => reconf,
        STATUS => STATUS,
        ACTION => ACTION,
        ACTION_ACK => ACTION_ACK
    );

    -- Flow generators
    flow: for i in 0 to FLOW_COUNT-1 generate
        flow_gen: entity work.flow_generator
        port map (
            CLK => CLK,
            RESET => RESET,
            RX_DATA => control_data(64 * (i+1) - 1 downto 64*i),
            RX_REM => control_rem(3 * (i+1) - 1 downto 3*i),
            RX_SOF_N => control_sof_n(i),
            RX_EOF_N => control_eof_n(i),
            RX_SOP_N => control_sop_n(i),
            RX_EOP_N => control_eop_n(i),
            RX_SRC_RDY_N => control_src_rdy_n(i),
            RX_DST_RDY_N => control_dst_rdy_n(i),
            TX_DATA => gen_data(64 * (i+1) - 1 downto 64*i),
            TX_REM => gen_rem(3 * (i+1) - 1 downto 3*i),
            TX_SOF_N => gen_sof_n(i),
            TX_EOF_N => gen_eof_n(i),
            TX_SOP_N => gen_sop_n(i),
            TX_EOP_N => gen_eop_n(i),
            TX_SRC_RDY_N => gen_src_rdy_n(i),
            TX_DST_RDY_N => gen_dst_rdy_n(i),
            RECONF => reconf
        );
    end generate;

    -- Flow merger
    flow_merger: entity work.flow_merger
    generic map (
        FLOW_COUNT => FLOW_COUNT
    ) port map (
        CLK => CLK,
        RESET => RESET,
        RX_DATA => gen_data,
        RX_REM => gen_rem,
        RX_SOF_N => gen_sof_n,
        RX_EOF_N => gen_eof_n,
        RX_SOP_N => gen_sop_n,
        RX_EOP_N => gen_eop_n,
        RX_SRC_RDY_N => gen_src_rdy_n,
        RX_DST_RDY_N => gen_dst_rdy_n,
        TX_DATA => TX_DATA,
        TX_REM => TX_REM,
        TX_SOF_N => TX_SOF_N,
        TX_EOF_N => TX_EOF_N,
        TX_SOP_N => TX_SOP_N,
        TX_EOP_N => TX_EOP_N,
        TX_SRC_RDY_N => TX_SRC_RDY_N,
        TX_DST_RDY_N => TX_DST_RDY_N,
        RECONF => reconf
    ); 

end Behavioral;

