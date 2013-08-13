-- Example application.vhd for integration of the traffic
-- generator on the Combov2 10G2 board.
-- This file is adapted from the example file provided
-- with the NetCOPE platform.
--
--
-- application.vhd : Combov2 NetCOPE application module
-- Copyright (C) 2009 CESNET
-- Author(s): Jan Stourac <xstour03@stud.fit.vutbr.cz>
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in
--    the documentation and/or other materials provided with the
--    distribution.
-- 3. Neither the name of the Company nor the names of its contributors
--    may be used to endorse or promote products derived from this
--    software without specific prior written permission.
--
-- This software is provided ``as is'', and any express or implied
-- warranties, including, but not limited to, the implied warranties of
-- merchantability and fitness for a particular purpose are disclaimed.
-- In no event shall the company or contributors be liable for any
-- direct, indirect, incidental, special, exemplary, or consequential
-- damages (including, but not limited to, procurement of substitute
-- goods or services; loss of use, data, or profits; or business
-- interruption) however caused and on any theory of liability, whether
-- in contract, strict liability, or tort (including negligence or
-- otherwise) arising in any way out of the use of this software, even
-- if advised of the possibility of such damage.
--
-- $Id$
--

-- ----------------------------------------------------------------------------
--                             Entity declaration
-- ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all; 
use work.combov2_core_const.all;
use work.combov2_user_const.all;
use work.math_pack.all;
use work.ibuf_general_pkg.all;
use work.addr_space.all;
use work.network_mod_10g2_64_const.all;
Library UNISIM;
use UNISIM.vcomponents.all;

architecture full of APPLICATION is

    component tsu_async is
    -- PORTS
    port (
        RESET          : in std_logic;

        -- Input interface
        IN_CLK         : in std_logic;

        IN_TS          : in std_logic_vector(63 downto 0);
        IN_TS_DV       : in std_logic;

        -- Output interface
        OUT_CLK        : in std_logic;

        OUT_TS         : out std_logic_vector(63 downto 0);
        OUT_TS_DV      : out std_logic
    );
    end component tsu_async;

component GICS_IB_ENDPOINT_SYNTH 
    port(
        -- Common interface -----------------------------------------------------
        CLK               : in std_logic;  
        RESET             : in std_logic;  

        -- IB Interface ---------------------------------------------------------
        IB_DOWN_DATA      : in  std_logic_vector(63 downto 0);
        IB_DOWN_SOF_N     : in  std_logic;
        IB_DOWN_EOF_N     : in  std_logic;
        IB_DOWN_SRC_RDY_N : in  std_logic;
        IB_DOWN_DST_RDY_N : out std_logic;

        IB_UP_DATA        : out std_logic_vector(63 downto 0);
        IB_UP_SOF_N       : out std_logic;
        IB_UP_EOF_N       : out std_logic;
        IB_UP_SRC_RDY_N   : out std_logic;
        IB_UP_DST_RDY_N   : in  std_logic;      

        -- Write Interface ------------------------------------------------------
        WR_REQ            : out std_logic;                           
        WR_RDY            : in  std_logic;                                 
        WR_DATA           : out std_logic_vector(63 downto 0);
        WR_ADDR           : out std_logic_vector(31 downto 0);       
        WR_BE             : out std_logic_vector(7 downto 0);        
        WR_LENGTH         : out std_logic_vector(11 downto 0);       
        WR_SOF            : out std_logic;                           
        WR_EOF            : out std_logic;

        -- Read Interface -------------------------------------------------------
        RD_REQ            : out std_logic;                           
        RD_ARDY_ACCEPT    : in  std_logic;                           
        RD_ADDR           : out std_logic_vector(31 downto 0);        
        RD_BE             : out std_logic_vector(7 downto 0);       
        RD_LENGTH         : out std_logic_vector(11 downto 0);       
        RD_SOF            : out std_logic;                           
        RD_EOF            : out std_logic;                    

        RD_DATA           : in  std_logic_vector(63 downto 0); 
        RD_SRC_RDY        : in  std_logic;                           
        RD_DST_RDY        : out std_logic;

        -- Bus Master Interface -------------------------------------------------
        BM_DATA           : in  std_logic_vector(63 downto 0);
        BM_SOF_N          : in  std_logic;
        BM_EOF_N          : in  std_logic;
        BM_SRC_RDY_N      : in  std_logic;
        BM_DST_RDY_N      : out std_logic;

        BM_TAG            : out std_logic_vector(7 downto 0);
        BM_TAG_VLD        : out std_logic
  );
end component;

-- ----------------------------------------------------------------------------
--                            Signal declaration
-- ----------------------------------------------------------------------------

    -- Communication between the computer and the generator
    signal generator_status         : std_logic_vector(31 downto 0);
    signal generator_action         : std_logic_vector(31 downto 0);
    signal generator_action_ack     : std_logic;

    -- Signals Internal Bus Endpoint signals
    signal ibep_wr_req              : std_logic;
    signal ibep_rd_req              : std_logic;
    signal reg_ibep_rd_req          : std_logic;
    signal ibep_rd_dst_rdy          : std_logic;

    signal ibep_dwr                 : std_logic_vector(63 downto 0);
    signal ibep_wr_be               : std_logic_vector(7 downto 0);
    signal ibep_wraddr              : std_logic_vector(31 downto 0);
    signal ibep_rdaddr              : std_logic_vector(31 downto 0);
    signal ibep_wr                  : std_logic;
    signal ibep_rd                  : std_logic;
    signal ibep_drd                 : std_logic_vector(63 downto 0);
    signal ibep_ack                 : std_logic;

    signal reg_ibep_drdy            : std_logic;
    -- -------------------------------------------------------------------------
    --                         Pacodag signals
    -- -------------------------------------------------------------------------
    signal ts0_sync                 : std_logic_vector(63 downto 0);
    signal ts0_dv_sync              : std_logic;
    signal ts1_sync                 : std_logic_vector(63 downto 0);
    signal ts1_dv_sync              : std_logic;

    signal write_mac                : std_logic;

-- ----------------------------------------------------------------------------
--                             Architecture body
-- ----------------------------------------------------------------------------
begin

    -- -------------------------------------------------------------------------
    --                             FrameLink
    -- -------------------------------------------------------------------------
    -- DMA -> NET
    OBUF1_RX_DATA     <= RX1_DATA;
    OBUF1_RX_REM      <= RX1_DREM;
    OBUF1_RX_SOF_N    <= RX1_SOF_N;
    OBUF1_RX_EOF_N    <= RX1_EOF_N;
    OBUF1_RX_SOP_N    <= RX1_SOP_N;
    OBUF1_RX_EOP_N    <= RX1_EOP_N;
    OBUF1_RX_SRC_RDY_N<= RX1_SRC_RDY_N;
    RX1_DST_RDY_N     <= OBUF1_RX_DST_RDY_N;

    -- NET -> DMA
    TX0_DATA          <= IBUF0_TX_DATA;
    TX0_DREM          <= IBUF0_TX_REM;
    TX0_SOF_N         <= IBUF0_TX_SOF_N;
    TX0_EOF_N         <= IBUF0_TX_EOF_N;
    TX0_SOP_N         <= IBUF0_TX_SOP_N;
    TX0_EOP_N         <= IBUF0_TX_EOP_N;
    TX0_SRC_RDY_N     <= IBUF0_TX_SRC_RDY_N;
    IBUF0_TX_DST_RDY_N<= TX0_DST_RDY_N;

    TX1_DATA          <= IBUF1_TX_DATA;
    TX1_DREM          <= IBUF1_TX_REM;
    TX1_SOF_N         <= IBUF1_TX_SOF_N;
    TX1_EOF_N         <= IBUF1_TX_EOF_N;
    TX1_SOP_N         <= IBUF1_TX_SOP_N;
    TX1_EOP_N         <= IBUF1_TX_EOP_N;
    TX1_SRC_RDY_N     <= IBUF1_TX_SRC_RDY_N;
    IBUF1_TX_DST_RDY_N<= TX1_DST_RDY_N;

    -- Traffic generator connections (receive from computer port 0, send to network port 0)
    generator: entity work.traffic_generator
    PORT MAP (
        CLK => CLK,
        RESET => RESET,
        RX_DATA => RX0_DATA,
        RX_REM => RX0_DREM,
        RX_SOF_N => RX0_SOF_N,
        RX_EOF_N => RX0_EOF_N,
        RX_SOP_N => RX0_SOP_N,
        RX_EOP_N => RX0_EOP_N,
        RX_SRC_RDY_N => RX0_SRC_RDY_N,
        RX_DST_RDY_N => RX0_DST_RDY_N,
        TX_DATA => OBUF0_RX_DATA,
        TX_REM => OBUF0_RX_REM,
        TX_SOF_N => OBUF0_RX_SOF_N,
        TX_EOF_N => OBUF0_RX_EOF_N,
        TX_SOP_N => OBUF0_RX_SOP_N,
        TX_EOP_N => OBUF0_RX_EOP_N,
        TX_SRC_RDY_N => OBUF0_RX_SRC_RDY_N,
        TX_DST_RDY_N => OBUF0_RX_DST_RDY_N,
        STATUS => generator_status,
        ACTION => generator_action,
        ACTION_ACK => generator_action_ack
    );

    -- -------------------------------------------------------------------------
    --                         Connection to the computer
    -- -------------------------------------------------------------------------

    -- Create one cycle read latency
    process(CLK)
    begin
        if (CLK'event and CLK = '1') then
            if (RESET = '1') then
                MI32_DRDY <= '0';
            else
                MI32_DRDY <= MI32_RD;
            end if;
        end if;
    end process;

    MI32_ARDY <= MI32_RD or MI32_WR;

    -- Select which register to read 
    process(CLK)
    begin
        if (CLK'event and CLK = '1') then
            case conv_integer(unsigned(MI32_ADDR(4 downto 2))) is
                when 0 => MI32_DRD <= generator_status;
                when 1 => MI32_DRD <= generator_action;
                when others => MI32_DRD <= X"DEADBEEF";
            end case;
        end if;
    end process;

    -- Write to the action register if asked
    process(CLK)
    begin
        if (CLK'event and CLK = '1') then
            if (RESET = '1') then
                generator_action <= (others => '0');
            else
                if (generator_action_ack = '1') then
                    generator_action <= (others => '0');
                elsif (conv_integer(unsigned(MI32_ADDR(4 downto 2))) = 1 and MI32_WR = '1') then
                    generator_action <= MI32_DWR;
                end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --                            Internal Bus
    -- -------------------------------------------------------------------------
    IB_ENDPOINT_I : GICS_IB_ENDPOINT_SYNTH
    port map(
        -- Common Interface
        CLK        => CLK,
        RESET      => RESET,

        -- Internal Bus Interface
        IB_DOWN_DATA        => IB_DOWN_DATA,
        IB_DOWN_SOF_N       => IB_DOWN_SOF_N,
        IB_DOWN_EOF_N       => IB_DOWN_EOF_N,
        IB_DOWN_SRC_RDY_N   => IB_DOWN_SRC_RDY_N,
        IB_DOWN_DST_RDY_N   => IB_DOWN_DST_RDY_N,
        IB_UP_DATA          => IB_UP_DATA,
        IB_UP_SOF_N         => IB_UP_SOF_N,
        IB_UP_EOF_N         => IB_UP_EOF_N,
        IB_UP_SRC_RDY_N     => IB_UP_SRC_RDY_N,
        IB_UP_DST_RDY_N     => IB_UP_DST_RDY_N,

        -- Write Interface
        WR_REQ        => ibep_wr_req,
        WR_RDY        => ibep_wr_req,
        WR_DATA       => ibep_dwr,
        WR_ADDR       => ibep_wraddr,
        WR_BE         => ibep_wr_be,
        WR_LENGTH     => open,
        WR_SOF        => open,
        WR_EOF        => open,

        -- Read Interface
        RD_REQ           => ibep_rd_req,
        RD_ARDY_ACCEPT   => ibep_rd_dst_rdy,
        RD_ADDR          => ibep_rdaddr,
        RD_BE            => open,
        RD_LENGTH        => open,
        RD_SOF           => open,
        RD_EOF           => open,
        RD_DATA          => ibep_drd,
        RD_SRC_RDY       => reg_ibep_rd_req,
        RD_DST_RDY       => ibep_rd_dst_rdy,

        -- Bus Master Interface
        BM_DATA          => X"0000000000000000",
        BM_SOF_N         => '1',
        BM_EOF_N         => '1',
        BM_SRC_RDY_N     => '1',
        BM_DST_RDY_N     => open,
        BM_TAG           => open,
        BM_TAG_VLD       => open
    );

    RAMB18SDP_inst0 : RAMB18SDP
    generic map (
        DO_REG   => 0,            -- Optional output register (0 or 1)
        INIT     => X"000000000", --  Initial values on output port
        SIM_COLLISION_CHECK => "ALL",
        SIM_MODE => "SAFE",
        SRVAL    => X"000000000"  --  Set/Reset value for port output
        )
    port map (
        DO       => ibep_drd(31 downto 0),  -- 32-bit Data Output
        DOP      => open,                   -- 4-bit  Parity Output
        RDCLK    => CLK,                    -- 1-bit read port clock
        RDEN     => ibep_rd_req,            -- 1-bit read port enable
        REGCE    => '1',                    -- 1-bit register enable input
        SSR      => '0',              -- 1-bit synchronous output set/reset input
        WRCLK    => CLK,                    -- 1-bit write port clock
        WREN     => ibep_wr_req,            -- 1-bit write port enable
        WRADDR   => ibep_wraddr(10 downto 2),-- 9-bit write port address input
        RDADDR   => ibep_rdaddr(10 downto 2),-- 9-bit read port address input
        DI       => ibep_dwr(31 downto 0),  -- 32-bit data input
        DIP      => "0000",                 -- 4-bit parity data input
        WE       => ibep_wr_be(3 downto 0)  -- 4-bit write enable input
    );

    RAMB18SDP_inst1 : RAMB18SDP
    generic map (
        DO_REG   => 0,             -- Optional output register (0 or 1)
        INIT     => X"000000000",  --  Initial values on output port
        SIM_COLLISION_CHECK => "ALL",
        SIM_MODE => "SAFE",
        SRVAL    => X"000000000"   --  Set/Reset value for port output
        )
    port map (
        DO       => ibep_drd(63 downto 32), -- 32-bit Data Output
        DOP      => open,                   -- 4-bit  Parity Output
        RDCLK    => CLK,                    -- 1-bit read port clock
        RDEN     => ibep_rd_req,            -- 1-bit read port enable
        REGCE    => '1',                    -- 1-bit register enable input
        SSR      => '0',              -- 1-bit synchronous output set/reset input
        WRCLK    => CLK,                    -- 1-bit write port clock
        WREN     => ibep_wr_req,            -- 1-bit write port enable
        WRADDR   => ibep_wraddr(10 downto 2),-- 9-bit write port address input
        RDADDR   => ibep_rdaddr(10 downto 2),-- 9-bit read port address input
        DI       => ibep_dwr(63 downto 32), -- 32-bit data input
        DIP      => "0000",                 -- 4-bit parity data input
        WE       => ibep_wr_be(7 downto 4)  -- 4-bit write enable input
    );
    
    -- Delay read request and use it as acknowledge of read data
    reg_ibep_rd_req_p : process(CLK)
    begin
        if CLK'event and CLK = '1' then
            reg_ibep_rd_req <= ibep_rd_req;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    --                              PACODAG
    -- -------------------------------------------------------------------------
    PACODAG_TOP_I: entity work.pacodag_tsu_top2_t64
    generic map(
        HEADER_EN => PACODAG_HEADER_EN,
        FOOTER_EN => PACODAG_FOOTER_EN
    )
    port map(
        -- Common interface
        RESET    => RESET,
        -- IBUF interface
        PCD0_CTRL_CLK              => IBUF0_CTRL_CLK,
        PCD0_CTRL_DATA             => IBUF0_CTRL_DATA,
        PCD0_CTRL_REM              => IBUF0_CTRL_REM,
        PCD0_CTRL_SRC_RDY_N        => IBUF0_CTRL_SRC_RDY_N,
        PCD0_CTRL_SOP_N            => IBUF0_CTRL_SOP_N,
        PCD0_CTRL_EOP_N            => IBUF0_CTRL_EOP_N,
        PCD0_CTRL_DST_RDY_N        => IBUF0_CTRL_DST_RDY_N,
        PCD0_CTRL_RDY              => IBUF0_CTRL_RDY,
        PCD0_SOP                   => IBUF0_SOP,
        PCD0_STAT_PAYLOAD_LEN      => IBUF0_PAYLOAD_LEN,
        PCD0_STAT_FRAME_ERROR      => IBUF0_FRAME_ERROR,
        PCD0_STAT_CRC_CHECK_FAILED => IBUF0_CRC_CHECK_FAILED,
        PCD0_STAT_MAC_CHECK_FAILED => IBUF0_MAC_CHECK_FAILED,
        PCD0_STAT_LEN_BELOW_MIN    => IBUF0_LEN_BELOW_MIN,
        PCD0_STAT_LEN_OVER_MTU     => IBUF0_LEN_OVER_MTU,
        PCD0_STAT_DV               => IBUF0_STAT_DV,

        PCD1_CTRL_CLK              => IBUF1_CTRL_CLK,
        PCD1_CTRL_DATA             => IBUF1_CTRL_DATA,
        PCD1_CTRL_REM              => IBUF1_CTRL_REM,
        PCD1_CTRL_SRC_RDY_N        => IBUF1_CTRL_SRC_RDY_N,
        PCD1_CTRL_SOP_N            => IBUF1_CTRL_SOP_N,
        PCD1_CTRL_EOP_N            => IBUF1_CTRL_EOP_N,
        PCD1_CTRL_DST_RDY_N        => IBUF1_CTRL_DST_RDY_N,
        PCD1_CTRL_RDY              => IBUF1_CTRL_RDY,
        PCD1_SOP                   => IBUF1_SOP,
        PCD1_STAT_PAYLOAD_LEN      => IBUF1_PAYLOAD_LEN,
        PCD1_STAT_FRAME_ERROR      => IBUF1_FRAME_ERROR,
        PCD1_STAT_CRC_CHECK_FAILED => IBUF1_CRC_CHECK_FAILED,
        PCD1_STAT_MAC_CHECK_FAILED => IBUF1_MAC_CHECK_FAILED,
        PCD1_STAT_LEN_BELOW_MIN    => IBUF1_LEN_BELOW_MIN,
        PCD1_STAT_LEN_OVER_MTU     => IBUF1_LEN_OVER_MTU,
        PCD1_STAT_DV               => IBUF1_STAT_DV,

        TS0       => ts0_sync,
        TS0_DV    => ts0_dv_sync,
        TS1       => ts1_sync,
        TS1_DV    => ts1_dv_sync
    );

    -- ---------------------------------------------------------------
    -- Generate tsu_async only if timestamp unit is also generated
    ts_true_async : if TIMESTAMP_UNIT = true generate
    tsu_async_i0 : tsu_async
        -- PORTS
        port map (
            RESET          => RESET,
            -- Input interface
            IN_CLK         => TS_CLK,
            IN_TS          => TS,
            IN_TS_DV       => TS_DV,
            -- Output interface
            OUT_CLK        => IBUF0_CTRL_CLK,
            OUT_TS         => ts0_sync,
            OUT_TS_DV      => ts0_dv_sync
        );
        tsu_async_i1 : tsu_async
        -- PORTS
        port map (
            RESET          => RESET,
            -- Input interface
            IN_CLK         => TS_CLK,
            IN_TS          => TS,
            IN_TS_DV       => TS_DV,
            -- Output interface
            OUT_CLK        => IBUF1_CTRL_CLK,
            OUT_TS         => ts1_sync,
            OUT_TS_DV      => ts1_dv_sync
        );
    end generate ts_true_async;

    -- Else map TS and TS_DV signals directly into pacodag
    ts_false_async : if TIMESTAMP_UNIT = false generate
        ts0_sync <= TS;
        ts0_dv_sync <= TS_DV;
        ts1_sync <= TS;
        ts1_dv_sync <= TS_DV;
    end generate ts_false_async;
    -- ---------------------------------------------------------------

end architecture full;
