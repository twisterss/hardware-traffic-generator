----------------------------------------------------------------------------------
-- CRC32 computation: up to 8 bytes per clock cycle.
-- Set the enable signal to 1 and get the result at the next clock cycle.
-- The inverted result can be used as input to keep computing the same CRC.
-- To compute a new CRC, set CRC_INV_IN to 0xFFFFFFFF.
-- "Data bytes" indicates how many bytes of input data are valid.
-- For example: data bytes = 2 => only data(15 downto 0) is valid.
-- If you do not get the expected results, check the byte order of data.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity crc32_8bytes is
    Port ( 
        CLK         : in std_logic;
        -- Negated value of the CRC to start from
        CRC_INV_IN  : in std_logic_vector(31 downto 0);
        -- Data to compute the CRC from
        DATA        : in std_logic_vector(63 downto 0);
        -- Number of valid bytes of the data (1 to 8). First valid byte: 7 downto 0.
        DATA_BYTES  : in std_logic_vector(3 downto 0);
        -- Enable computation
        EN          : in std_logic;
        -- Negated value of the resulting CRC
        CRC_INV_OUT : out std_logic_vector(31 downto 0);
        -- Resulting CRC
        CRC     : out std_logic_vector(31 downto 0)
    );
end crc32_8bytes;

architecture Behavioral of crc32_8bytes is

    -- ROM definition
    type crc_array is array(0 to 255) of std_logic_vector(31 downto 0);
    type lookup_array is array(0 to 7) of crc_array;

    -- Function to precompute the ROM values
    function init_rom return lookup_array is
        variable mem : lookup_array;
        constant poly : std_logic_vector(31 downto 0) := X"EDB88320";
        variable crc : std_logic_vector(31 downto 0);
        variable temp : std_logic_vector(31 downto 0);
    begin
        for i in 0 to 7 loop
            for j in 0 to 255 loop
                if (i = 0) then
                    crc := std_logic_vector(to_unsigned(j, 32));
                    for k in 0 to 7 loop
                        if (crc(0) = '1') then
                            crc := '0' & crc(31 downto 1);
                            crc := crc xor poly;
                        else
                            crc := '0' & crc(31 downto 1);
                        end if;
                    end loop;
                    mem(i)(j) := crc;
                else
                    temp := x"00" & mem(i-1)(j)(31 downto 8);
                    mem(i)(j) := temp xor mem(0)(to_integer(unsigned(mem(i-1)(j)(7 downto 0))));
                end if;
            end loop;
        end loop;
        return mem;
    end;

    constant rom            : lookup_array := init_rom;

    signal data_xor         : std_logic_vector(63 downto 0);
    signal data_xor_sel     : std_logic_vector(63 downto 0);
    signal crc_inv          : std_logic_vector(31 downto 0);
    signal crc_inv_remain   : std_logic_vector(31 downto 0);

begin

    -- Compute the XOR with the initial inverted CRC
    data_xor <= data(63 downto 32) & (data(31 downto 0) xor CRC_INV_IN);

    -- Select data that should be used if not 8 bytes
    data_select: process (DATA_BYTES, data_xor) begin
        case (to_integer(unsigned(DATA_BYTES))) is
            when 1 =>
                data_xor_sel <= data_xor(7 downto 0) & X"00000000000000"; 
            when 2 =>
                data_xor_sel <= data_xor(15 downto 0) & X"000000000000";
            when 3 =>
                data_xor_sel <= data_xor(23 downto 0) & X"0000000000";
            when 4 =>
                data_xor_sel <= data_xor(31 downto 0) & X"00000000";
            when 5 =>
                data_xor_sel <= data_xor(39 downto 0) & X"000000";
            when 6 =>
                data_xor_sel <= data_xor(47 downto 0) & X"0000";
            when 7 =>
                data_xor_sel <= data_xor(55 downto 0) & X"00";
            when others =>
                data_xor_sel <= data_xor;
        end case;
    end process;

    -- Select the part of CRC that was not included when less than 4 bytes
    crc_select: process (DATA_BYTES, crc_inv) begin
        case (to_integer(unsigned(DATA_BYTES))) is
            when 1 =>
                crc_inv_remain <= X"000000" & crc_inv(31 downto 24); 
            when 2 =>
                crc_inv_remain <= X"0000" & crc_inv(31 downto 16); 
            when 3 =>
                crc_inv_remain <= X"00" & crc_inv(31 downto 8); 
            when others =>
                crc_inv_remain <= (others => '0');
        end case;
    end process;

    -- Compute the CRC
    CRC <= not crc_inv;
    CRC_INV_OUT <= crc_inv;
    compute: process (CLK) begin
        if (rising_edge(CLK)) then
            if (EN = '1') then
                crc_inv <= crc_inv_remain
                    xor rom(0)(to_integer(unsigned(data_xor_sel(63 downto 56))))
                    xor rom(1)(to_integer(unsigned(data_xor_sel(55 downto 48))))
                    xor rom(2)(to_integer(unsigned(data_xor_sel(47 downto 40))))
                    xor rom(3)(to_integer(unsigned(data_xor_sel(39 downto 32))))
                    xor rom(4)(to_integer(unsigned(data_xor_sel(31 downto 24))))
                    xor rom(5)(to_integer(unsigned(data_xor_sel(23 downto 16))))
                    xor rom(6)(to_integer(unsigned(data_xor_sel(15 downto 8))))
                    xor rom(7)(to_integer(unsigned(data_xor_sel(7 downto 0))));
            end if;
        end if;
    end process;

end Behavioral;

