--------------------------------------------------------------------------------
-- Control TestBench
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY tb_control IS
END tb_control;
 
ARCHITECTURE behavior OF tb_control IS 
  
    COMPONENT control
 	generic (
		FLOW_COUNT 			: integer := 1
	);
	Port (
		CLK				: in std_logic;
		RESET			: in std_logic;
		RX_DATA			: in std_logic_vector(63 downto 0);
		RX_REM 			: in std_logic_vector(2 downto 0);
		RX_SOF_N 		: in std_logic;
		RX_EOF_N 		: in std_logic;
		RX_SOP_N 		: in std_logic;
		RX_EOP_N 		: in std_logic;
		RX_SRC_RDY_N	: in std_logic;
		RX_DST_RDY_N 	: out std_logic;
		TX_DATA			: out std_logic_vector(64*FLOW_COUNT-1 downto 0);
		TX_REM 			: out std_logic_vector(3*FLOW_COUNT-1 downto 0);
		TX_SOF_N 		: out std_logic_vector(FLOW_COUNT-1 downto 0);
		TX_EOF_N 		: out std_logic_vector(FLOW_COUNT-1 downto 0);
		TX_SOP_N 		: out std_logic_vector(FLOW_COUNT-1 downto 0);
		TX_EOP_N 		: out std_logic_vector(FLOW_COUNT-1 downto 0);
		TX_SRC_RDY_N 	: out std_logic_vector(FLOW_COUNT-1 downto 0);
		TX_DST_RDY_N 	: in std_logic_vector(FLOW_COUNT-1 downto 0);
		RECONF 			: out std_logic_vector(FLOW_COUNT-1 downto 0);
		STATUS			: out std_logic_vector(31 downto 0);
		ACTION			: in std_logic_vector(31 downto 0);
		ACTION_ACK		: out std_logic
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
   signal TX_DST_RDY_N : std_logic_vector(1 downto 0) := (others => '1');
   signal ACTION : std_logic_vector(31 downto 0) := (others => '0');

 	--Outputs
   signal RX_DST_RDY_N : std_logic;
   signal TX_DATA : std_logic_vector(127 downto 0);
   signal TX_REM : std_logic_vector(5 downto 0);
   signal TX_SOF_N : std_logic_vector(1 downto 0);
   signal TX_EOF_N : std_logic_vector(1 downto 0);
   signal TX_SOP_N : std_logic_vector(1 downto 0);
   signal TX_EOP_N : std_logic_vector(1 downto 0);
   signal TX_SRC_RDY_N : std_logic_vector(1 downto 0);
   signal RECONF : std_logic_vector(1 downto 0);
   signal STATUS : std_logic_vector(31 downto 0);
   signal ACTION_ACK : std_logic;

   -- Clock period definitions
   constant CLK_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: control GENERIC MAP (
          FLOW_COUNT => 2
        ) PORT MAP (
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
          RECONF => RECONF,
          STATUS => STATUS,
          ACTION => ACTION,
          ACTION_ACK => ACTION_ACK
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '1';
		wait for CLK_period/2;
		CLK <= '0';
		wait for CLK_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      RESET <= '1';
      wait for 101 ns;	
      RESET <= '0';
      wait for CLK_period*10;
      -- Generator ready to received
      TX_DST_RDY_N <= "00";
      -- Send configuration frame
      RX_DATA <= X"AAAAAAAAAAAAAAAA";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"BBBBBBBBBBBBBBBB";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '1';
      wait for CLK_period;
      RX_DATA <= X"CCCCCCCCCCCCCCCC";
      RX_SRC_RDY_N <= '1';
      wait for CLK_period;
      RX_SRC_RDY_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"DDDDDDDDDDDDDDDD";
      RX_EOF_N <= '0';   
      wait for CLK_period;
      RX_EOF_N <= '1';  
      -- Send configuration frame
      RX_DATA <= X"AAAAAAAAAAAAAAAA";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"BBBBBBBBBBBBBBBB";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '1';
      wait for CLK_period;
      RX_DATA <= X"CCCCCCCCCCCCCCCC";
      RX_SRC_RDY_N <= '1';
      wait for CLK_period;
      RX_SRC_RDY_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"DDDDDDDDDDDDDDDD";
      RX_EOF_N <= '0';   
      wait for CLK_period;
      RX_EOF_N <= '1';  
      -- Send configuration frame
      RX_DATA <= X"AAAAAAAAAAAAAAAA";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"BBBBBBBBBBBBBBBB";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '1';
      wait for CLK_period;
      RX_DATA <= X"CCCCCCCCCCCCCCCC";
      RX_SRC_RDY_N <= '1';
      wait for CLK_period;
      RX_SRC_RDY_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"DDDDDDDDDDDDDDDD";
      RX_EOF_N <= '0';   
      wait for CLK_period;
      RX_EOF_N <= '1';  
      RX_SRC_RDY_N <= '1';   
      -- Generator not ready
      TX_DST_RDY_N <= "11";
      wait for 5*CLK_period; 
      -- Action START
      ACTION <= X"00000001";
      wait for CLK_period;
      ACTION <= X"00000000";
      wait for 10*CLK_period; 
      -- Generator ready
      TX_DST_RDY_N <= "00";
      wait for 3*CLK_period; 
      -- Generator not ready
      TX_DST_RDY_N <= "11";
      wait for 10*CLK_period; 
      -- Generator ready
      TX_DST_RDY_N <= "00";
      wait for 10*CLK_period; 
      -- ACTION RESTART
      ACTION <= X"00000002";
      wait for CLK_period;
      ACTION <= X"00000000";
      wait for 4*CLK_period;
      -- Send configuration frame
      RX_DATA <= X"AAAAAAAAAAAAAAAA";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"BBBBBBBBBBBBBBBB";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '1';
      wait for CLK_period;
      RX_DATA <= X"CCCCCCCCCCCCCCCC";
      RX_SRC_RDY_N <= '1';
      wait for CLK_period;
      RX_SRC_RDY_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"DDDDDDDDDDDDDDDD";
      RX_EOF_N <= '0';   
      wait for CLK_period;
      RX_EOF_N <= '1';  
      RX_SRC_RDY_N <= '1'; 
      wait for CLK_period; 
      -- Send configuration frame
      RX_DATA <= X"AAAAAAAAAAAAAAAA";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"BBBBBBBBBBBBBBBB";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '1';
      wait for CLK_period;
      RX_DATA <= X"CCCCCCCCCCCCCCCC";
      RX_SRC_RDY_N <= '1';
      wait for CLK_period;
      RX_SRC_RDY_N <= '0';
      -- ACTION RESTART
      ACTION <= X"00000002";
      wait for CLK_period;
      ACTION <= X"00000000";
      RX_DATA <= X"DDDDDDDDDDDDDDDD";
      RX_EOF_N <= '0';   
      wait for CLK_period;
      RX_EOF_N <= '1';  
      RX_SRC_RDY_N <= '1';  
      wait for CLK_period; 
      -- Send configuration frame
      RX_DATA <= X"AAAAAAAAAAAAAAAA";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"BBBBBBBBBBBBBBBB";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '1';
      wait for CLK_period;
      RX_DATA <= X"CCCCCCCCCCCCCCCC";
      RX_SRC_RDY_N <= '1';
      wait for CLK_period;
      RX_SRC_RDY_N <= '0';
      wait for CLK_period;
      RX_DATA <= X"DDDDDDDDDDDDDDDD";
      RX_EOF_N <= '0';   
      wait for CLK_period; 
      -- Send configuration frame
      RX_DATA <= X"AAAAAAAAAAAAAAAA";
      RX_SRC_RDY_N <= '0';
      RX_SOF_N <= '0';
      RX_EOF_N <= '1';   
      wait for CLK_period;
      RX_DATA <= X"BBBBBBBBBBBBBBBB";
      RX_SOF_N <= '1';
      -- Generator not ready
      TX_DST_RDY_N <= "11";
      wait for 5*CLK_period;
      -- Generator ready
      TX_DST_RDY_N <= "00";
      wait for CLK_period;
      RX_DATA <= X"CCCCCCCCCCCCCCCC";
      wait for CLK_period;
      RX_DATA <= X"DDDDDDDDDDDDDDDD";
      RX_EOF_N <= '0';   
      wait for CLK_period;
      RX_EOF_N <= '1';  
      RX_SRC_RDY_N <= '1'; 
      wait;
   end process;

END;
