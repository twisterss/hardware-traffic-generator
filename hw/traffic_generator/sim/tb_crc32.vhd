--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   08:54:53 02/12/2013
-- CRC32 test
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY tb_crc32 IS
END tb_crc32;
 
ARCHITECTURE behavior OF tb_crc32 IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT crc32_8bytes
    PORT(
         CLK : IN  std_logic;
         CRC_INV_IN : IN  std_logic_vector(31 downto 0);
         DATA : IN  std_logic_vector(63 downto 0);
         DATA_BYTES  : in std_logic_vector(3 downto 0);
         EN : IN  std_logic;
         CRC_INV_OUT : OUT  std_logic_vector(31 downto 0);
         CRC : OUT  std_logic_vector(31 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal CLK : std_logic := '0';
   signal CRC_INV_IN : std_logic_vector(31 downto 0) := (others => '1');
   signal DATA : std_logic_vector(63 downto 0) := (others => '0');
   signal DATA_BYTES : std_logic_vector(3 downto 0) := "1000";
   signal EN : std_logic := '0';

 	--Outputs
   signal CRC_INV_OUT : std_logic_vector(31 downto 0);
   signal CRC : std_logic_vector(31 downto 0);
   
   signal expected_crc : std_logic_vector(31 downto 0);
   signal error : std_logic;

   -- Clock period definitions
   constant CLK_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: crc32_8bytes PORT MAP (
          CLK => CLK,
          CRC_INV_IN => CRC_INV_IN,
          DATA => DATA,
          DATA_BYTES => DATA_BYTES,
          EN => EN,
          CRC_INV_OUT => CRC_INV_OUT,
          CRC => CRC
        );

   -- Clock process definitions
   CLK_process :process
   begin
		CLK <= '1';
		wait for CLK_period/2;
		CLK <= '0';
		wait for CLK_period/2;
   end process;

   error <= '0' when (expected_crc = crc) else '1';
   -- Stimulus process
   stim_proc: process
   begin		
      wait for 101 ns;	
      wait for CLK_period*10;
      DATA <= X"0000000000000000";
      EN <= '1';
      wait for CLK_period;
      expected_crc <= X"6522DF69";
      DATA <= X"070C040A00300D0F"; -- 0F0D30000A040C07
      EN <= '1';
      wait for CLK_period;
      expected_crc <= X"83CA39BF";
      CRC_INV_IN <= CRC_INV_OUT;
      DATA <= X"040C440A80300D51"; -- 510D30800A440C04
      EN <= '1';
      wait for CLK_period;
      expected_crc <= X"EF0B67B9";
      CRC_INV_IN <= CRC_INV_OUT;
      DATA <= X"140C400A80310D01"; -- 010D31800A400C14
      DATA_BYTES <= "0010";
      EN <= '1';
      wait for CLK_period;
      expected_crc <= X"C0A25102";
      EN <= '0';
      wait;
   end process;

END;
