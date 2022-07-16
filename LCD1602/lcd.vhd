library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity lcd is
	port( 
		clk    	: in 		std_logic;                          --clock i/p
		lcd_e 	: out 	std_logic;                         	--enable control
		data_out : out 	std_logic_vector(7 downto 0);			--data line out
		data_in	: in 		std_logic_vector(7 downto 0);			--data line in
		busy		: out 	std_logic;									--latch in data tu send
		latch		: in		std_logic
	);     
end lcd;


architecture Behavioral of lcd is

	signal tbusy: STD_LOGIC := '0';

begin

	process(clk)
		variable i : integer := 0;
		begin
			if ((clk'event) and (clk = '1')) then
				if (latch = '1' OR tbusy = '1') then
					tbusy <= '1';
					if (i <= 1000000) then
						i := i + 1;
						lcd_e <= '1';
						data_out <= data_in;
					elsif ((i > 1000000) and (i < 2000000)) then
						i := i + 1;
						lcd_e <= '0';
					elsif i = 2000000 then
						tbusy <= '0';
						i := 0;
					end if;
				end if;
			end if;
			busy <= tbusy;
	end process;

end Behavioral;