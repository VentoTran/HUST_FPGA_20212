library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity UART_TX is
  generic (
		CLKS_PER_BIT : integer := 434	 
   );
  port (
		CLK       : in  std_logic;
		TX_EN     : in  std_logic;
		TX_Byte   : in  std_logic_vector(7 downto 0);
		TX_Serial : out std_logic := '0';
		TX_Done   : out std_logic := '0'
   );
end UART_TX;
 
 
architecture Behavior of UART_TX is
 
  type STATE_TX is (s_Idle, s_TX_Start_Bit, s_TX_Data, s_TX_Stop_Bit);
  signal s_CURRENT : STATE_TX := s_Idle;
 
  signal Clk_Count : integer range 0 to CLKS_PER_BIT-1 := 0;
  signal Index_Bit: integer range 0 to 7 := 0;  -- 8 Bits Total
  signal TX_Data   : std_logic_vector(7 downto 0) := (others => '0');
  signal Done   : std_logic := '0';
   
begin

  p_UART_TX : process (CLK)
  begin
    if rising_edge(CLK) then
         
      case s_CURRENT is
 
        when s_Idle =>
          TX_Serial <= '1';         -- Drive Line High for Idle
          Done   <= '0';
          Clk_Count <= 0;
          Index_Bit<= 0;
 
          if TX_EN = '1' then
            TX_Data <= TX_Byte;
            s_CURRENT <= s_TX_Start_Bit;
          else
            s_CURRENT <= s_Idle;
          end if;
 
        -- Send out Start Bit. Start bit = 0
        when s_TX_Start_Bit =>
          TX_Serial <= '0';
 
          -- Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
          if Clk_Count < CLKS_PER_BIT-1 then
            Clk_Count <= Clk_Count + 1;
            s_CURRENT   <= s_TX_Start_Bit;
          else
            Clk_Count <= 0;
            s_CURRENT   <= s_TX_Data;
          end if;
  
        -- Wait CLKS_PER_BIT-1 clock cycles for data bits to finish          
        when s_TX_Data =>
          TX_Serial <= TX_Data(Index_Bit);
           
          if Clk_Count < CLKS_PER_BIT-1 then
            Clk_Count <= Clk_Count + 1;
            s_CURRENT   <= s_TX_Data;
          else
            Clk_Count <= 0;
             
            -- Check if we have sent out all bits
            if Index_Bit< 7 then
              Index_Bit<= Index_Bit+ 1;
              s_CURRENT   <= s_TX_Data;
            else
              Index_Bit<= 0;
              s_CURRENT   <= s_TX_Stop_Bit;
            end if;
          end if;
 
        -- Send out Stop bit.  Stop bit = 1
        when s_TX_Stop_Bit =>
          TX_Serial <= '1';
 
          -- Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
          if Clk_Count < CLKS_PER_BIT-1 then
            Clk_Count <= Clk_Count + 1;
            s_CURRENT   <= s_TX_Stop_Bit;
          else
            Done   <= '1';
            Clk_Count <= 0;
            s_CURRENT   <= s_Idle;
          end if;
      end case;
    end if;
  end process p_UART_TX;
 
  TX_Done <= Done;
   
end Behavior;