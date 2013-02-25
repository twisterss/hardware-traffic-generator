--------------------------------------------------------------------------------
-- Testbench for the configuration remover
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY tb_config_remover IS
END tb_config_remover;
 
ARCHITECTURE behavior OF tb_config_remover IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT config_remover
    PORT(
         CLK : IN  std_logic;
         RESET : IN  std_logic;
         RX_DATA : IN  std_logic_vector(63 downto 0);
         RX_REM : IN  std_logic_vector(2 downto 0);
         RX_SOF_N : IN  std_logic;
         RX_EOF_N : IN  std_logic;
         RX_SOP_N : IN  std_logic;
         RX_EOP_N : IN  std_logic;
         RX_SRC_RDY_N : IN  std_logic;
         RX_DST_RDY_N : OUT  std_logic;
         TX_DATA : OUT  std_logic_vector(63 downto 0);
         TX_REM : OUT  std_logic_vector(2 downto 0);
         TX_SOF_N : OUT  std_logic;
         TX_EOF_N : OUT  std_logic;
         TX_SOP_N : OUT  std_logic;
         TX_EOP_N : OUT  std_logic;
         TX_SRC_RDY_N : OUT  std_logic;
         TX_DST_RDY_N : IN  std_logic;
         RECONF : IN std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';
   signal RESET : std_logic := '0';
   signal RX_DATA : std_logic_vector(63 downto 0) := (others => '0');
   signal RX_REM : std_logic_vector(2 downto 0) := (others => '0');
   signal RX_SOF_N : std_logic := '1';
   signal RX_EOF_N : std_logic := '1';
   signal RX_SOP_N : std_logic := '1';
   signal RX_EOP_N : std_logic := '1';
   signal RX_SRC_RDY_N : std_logic := '1';
   signal TX_DST_RDY_N : std_logic := '1';

 	--Outputs
   signal RX_DST_RDY_N : std_logic;
   signal TX_DATA : std_logic_vector(63 downto 0);
   signal TX_REM : std_logic_vector(2 downto 0);
   signal TX_SOF_N : std_logic;
   signal TX_EOF_N : std_logic;
   signal TX_SOP_N : std_logic;
   signal TX_EOP_N : std_logic;
   signal TX_SRC_RDY_N : std_logic;

   -- Clock period definitions
   constant CLK_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: config_remover PORT MAP (
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
          TX_DATA => TX_DATA,
          TX_REM => TX_REM,
          TX_SOF_N => TX_SOF_N,
          TX_EOF_N => TX_EOF_N,
          TX_SOP_N => TX_SOP_N,
          TX_EOP_N => TX_EOP_N,
          TX_SRC_RDY_N => TX_SRC_RDY_N,
          TX_DST_RDY_N => TX_DST_RDY_N,
          RECONF => '0'
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '0';
		wait for CLK_period/2;
		CLK <= '1';
		wait for CLK_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      RESET <= '1';
      wait for 100 ns;		
      RESET <= '0';

      wait for CLK_period*10;
      
      TX_DST_RDY_N <= '0';
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '0';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '0';
      RX_SOP_N <= '1';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '0';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '0';
      RX_SOP_N <= '1';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '0';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '0';
      RX_SOP_N <= '1';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '0';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '1');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '0';
      RX_SOP_N <= '1';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '0';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '0';
      RX_SOP_N <= '1';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '0';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '1');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '0';
      RX_SOP_N <= '1';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '0';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '1');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '0';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '1';
      RX_SOP_N <= '1';
      RX_EOP_N <= '1';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      RX_SOF_N <= '1';
      RX_EOF_N <= '0';
      RX_SOP_N <= '1';
      RX_EOP_N <= '0';
      RX_DATA <= (others => '0');
      wait for CLK_period;
      wait;
   end process;

END;
