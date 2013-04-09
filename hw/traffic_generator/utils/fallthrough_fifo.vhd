----------------------------------------------------------------------------------
-- Fallthrough FIFO:
-- the oldest stored value is always available at the FIFO output.
-- Setting read_en signals to read the next value.
-- Data goes through as fast as possible:
-- no delay if empty
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity FALLTHROUGH_FIFO is
    generic (
        DATA_WIDTH : integer := 64;
        DEPTH      : integer := 512
        );
    port (
        -- global FPGA clock
        CLK : in std_logic;

        -- global synchronous reset
        RESET : in std_logic;

        -- Write interface
        DATA_IN  : in std_logic_vector(DATA_WIDTH-1 downto 0);
        WRITE_EN : in std_logic;

        -- Read interface
        DATA_OUT : out std_logic_vector(DATA_WIDTH-1 downto 0);
        READ_EN  : in  std_logic;

        -- Control
        STATE_FULL  : out std_logic;
        STATE_EMPTY : out std_logic
        );
end FALLTHROUGH_FIFO;

architecture Behavioral of FALLTHROUGH_FIFO is

    -- FIFO connections
    signal fifo_data_in: std_logic_vector(DATA_WIDTH-1 downto 0);
    signal fifo_data_out: std_logic_vector(DATA_WIDTH-1 downto 0);
    signal fifo_write_en: std_logic;
    signal fifo_read_en: std_logic;
    signal fifo_empty: std_logic;
    signal fifo_full: std_logic;
    signal data_out_reg: std_logic_vector(DATA_WIDTH-1 downto 0);
    signal data_out_keep: std_logic;
    
    type state_type is (OUT_EMPTY, OUT_KEEP, OUT_FIFO);
    signal state: state_type;
    signal state_nxt: state_type;

begin

    -- Simple FIFO instance
    SIMPLE_FIFO_inst: entity work.SIMPLE_FIFO
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            DEPTH => DEPTH-1
            )
        port map (
            CLK => CLK,
            RESET => RESET,
            
            DATA_IN => fifo_data_in,
            WRITE_EN => fifo_write_en,
            
            DATA_OUT => fifo_data_out,
            READ_EN => fifo_read_en,
            
            STATE_FULL => fifo_full,
            STATE_EMPTY => fifo_empty
            );
            
    -- Direct connections
    fifo_data_in <= DATA_IN;
    
    -- Register that keeps the latest value
    process (CLK, RESET) begin
        if (CLK'event and CLK = '1') then
            if (data_out_keep = '1') then
                data_out_reg <= DATA_IN;
            end if;          
        end if;
    end process;
    
    -- FSM: ensure that there is always a result at FIFO output
    process (CLK, RESET) begin
        if (RESET = '1') then
            state <= OUT_EMPTY;
        elsif (CLK'event and CLK = '1') then
            state <= state_nxt;
        end if;
    end process;
    process (state, WRITE_EN, READ_EN, fifo_empty, fifo_full, DATA_IN, fifo_data_out, data_out_reg) begin
        state_nxt <= state;
        data_out_keep <= '0';
        fifo_read_en <= '0';
        fifo_write_en <= '0';
        STATE_EMPTY <= '1';
        STATE_FULL <= '1';
        DATA_OUT <= (others => '0');
        case state is
            when OUT_EMPTY =>
                if (WRITE_EN = '1') then
                    if (READ_EN = '0') then
                        data_out_keep <= '1';
                        state_nxt <= OUT_KEEP;
                    end if;
                    STATE_EMPTY <= '0';
                else
                    STATE_EMPTY <= '1';
                end if;
                STATE_FULL <= '0';
                DATA_OUT <= DATA_IN;
            when OUT_KEEP =>
                if (READ_EN = '1') then
                    if (fifo_empty = '1') then
                        if (WRITE_EN = '1') then
                            data_out_keep <= '1';
                        else
                            state_nxt <= OUT_EMPTY;
                        end if;
                    else
                        state_nxt <= OUT_FIFO;
                        fifo_write_en <= WRITE_EN;
                        fifo_read_en <= '1';
                    end if;
                else
                    fifo_write_en <= WRITE_EN;
                end if;
                STATE_EMPTY <= '0';
                STATE_FULL <= fifo_full;
                DATA_OUT <= data_out_reg;
            when OUT_FIFO =>
                if (READ_EN = '1') then
                    if (fifo_empty = '1') then
                        if (WRITE_EN = '1') then
                            data_out_keep <= '1';
                            state_nxt <= OUT_KEEP;
                        else
                            state_nxt <= OUT_EMPTY;
                        end if;
                    else
                        fifo_write_en <= WRITE_EN;
                        fifo_read_en <= '1';
                    end if;
                else
                    fifo_write_en <= WRITE_EN;
                end if;
                STATE_EMPTY <= '0';
                STATE_FULL <= fifo_full;
                DATA_OUT <= fifo_data_out;
        end case;
    end process;
end Behavioral;

