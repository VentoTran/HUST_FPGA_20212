LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

ENTITY FPGA_DE1_20212 IS
	PORT(
		CLK				: IN		STD_LOGIC;
		UART_TX   		: OUT 	STD_LOGIC;
		LCD1602DATA		: OUT    STD_LOGIC_VECTOR(7 DOWNTO 0);
		LCD_E				: OUT		STD_LOGIC;
		LCD_RW			: OUT		STD_LOGIC;
		LCD_RS			: OUT		STD_LOGIC;
		I2C_SDA       	: INOUT  STD_LOGIC;  	
		I2C_SCL       	: INOUT  STD_LOGIC
	);
END FPGA_DE1_20212;


ARCHITECTURE BEHAVIOUR OF FPGA_DE1_20212 IS

	COMPONENT I2C_Master IS
		PORT(
			 clk       : IN     STD_LOGIC;                    	--system clock
			 reset_n   : IN     STD_LOGIC;                    	--active low reset
			 ena       : IN     STD_LOGIC;                    	--latch in command
			 addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); 	--address of target slave
			 rw        : IN     STD_LOGIC;                    	--'0' is write, '1' is read
			 data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); 	--data to write to slave
			 busy      : OUT    STD_LOGIC;                    	--indicates transaction in progress
			 data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); 	--data read from slave
			 ack_error : BUFFER STD_LOGIC;                    	--flag if improper acknowledge from slave
			 sda       : INOUT  STD_LOGIC;                    	--serial data output of i2c bus
			 scl       : INOUT  STD_LOGIC								--serial clock output of i2c bus
			 );                   
	END COMPONENT I2C_Master;
	
	SIGNAL I2C_RST, I2C_ENA, I2C_WR, I2C_BUSY, I2C_BUSY_PREV, I2C_ERROR: STD_LOGIC;
	SIGNAL I2C_ADDR: 		STD_LOGIC_VECTOR(6 DOWNTO 0) := "0111000";
	SIGNAL I2C_DATA_OUT: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL I2C_DATA_IN:	STD_LOGIC_VECTOR(7 DOWNTO 0);
	
	SIGNAL LCD_BUSY:		STD_LOGIC	:= '0';
	
	TYPE arr1 IS ARRAY (1 to 6) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
	TYPE arr2 IS ARRAY (1 to 16) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
	
	CONSTANT INIT: arr1 := (X"38",X"01",X"06",X"0C",X"02",x"80");
	CONSTANT TEMP: arr2 := (X"54",X"65",X"6D",X"70",X"3A",X"20",X"32",X"30",X"2E",X"36",X"35",X"20",X"DF",X"43",X"20",X"20");
	CONSTANT HUMD: arr2 := (X"48",X"75",X"6D",X"64",X"3A",X"20",X"37",X"38",X"2E",X"35",X"20",X"25",X"20",X"20",X"20",X"20");
	
	SIGNAL DATA: arr1 := (X"00",X"00",X"00",X"00",X"00",x"00");

BEGIN

	LCD_RW <= '0';
	I2C_RST <= '1';
	I2C_ADDR <= "0111000";

	C1: I2C_Master port map (	clk=>CLK, 			reset_n=>I2C_RST, 		ena=>I2C_ENA, 				addr=>I2C_ADDR, 	rw=>I2C_WR, 	data_wr=>I2C_DATA_OUT,
										busy=>I2C_BUSY, 	data_rd=>I2C_DATA_IN, 	ack_error=>I2C_ERROR, 	sda=>I2C_SDA, 		scl=>I2C_SCL);
	
	P1: PROCESS(CLK)
		VARIABLE COUNT_500ms: 	INTEGER RANGE 0 TO 25000000;
		VARIABLE FLAG_500ms: 	INTEGER RANGE 0 TO 1;
		VARIABLE COUNT_SEND: 	INTEGER RANGE 0 TO 3;
		VARIABLE COUNT_RECV: 	INTEGER RANGE 0 TO 6;
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			
			I2C_BUSY_PREV <= I2C_BUSY;
			IF (I2C_BUSY_PREV = '0' AND I2C_BUSY = '1') THEN
				IF (COUNT_SEND /= 3) THEN
					COUNT_SEND := COUNT_SEND + 1;
					IF (COUNT_SEND = 3) THEN
						I2C_ENA <= '0';
					END IF;
				ELSE
					COUNT_RECV := COUNT_RECV + 1;
					IF (COUNT_RECV = 6) THEN
						I2C_ENA <= '0';
					END IF;
				END IF;
			END IF;
		
			IF (COUNT_500ms = 25000000) THEN
				COUNT_500ms := 0;
				FLAG_500ms := 1;
			ELSE
				COUNT_500ms := COUNT_500ms + 1;
			END IF;
			
			IF (FLAG_500ms = 1 AND COUNT_SEND /= 3) THEN
				IF (COUNT_SEND = 0) THEN
					I2C_DATA_OUT <= X"AC";
					I2C_WR <= '0';
					I2C_ENA <= '1';
				elsif (COUNT_SEND = 1) THEN
					I2C_DATA_OUT <= X"33";
					I2C_WR <= '0';
					I2C_ENA <= '1';
				elsif (COUNT_SEND = 2) THEN
					I2C_DATA_OUT <= X"00";
					I2C_WR <= '0';
					I2C_ENA <= '1';
					FLAG_500ms := 0;
					COUNT_RECV := 0;
				END IF;
			END IF;
			
			IF (FLAG_500ms = 1 AND COUNT_SEND = 3) THEN
				IF (COUNT_RECV = 0) THEN
					I2C_WR <= '1';
					I2C_ENA <= '1';
				elsif (COUNT_RECV = 1) THEN
					IF (I2C_BUSY = '0') THEN
						DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
					END IF;
					I2C_WR <= '1';
					I2C_ENA <= '1';
				elsif (COUNT_RECV = 2) THEN
					IF (I2C_BUSY = '0') THEN
						DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
					END IF;
					I2C_WR <= '1';
					I2C_ENA <= '1';
				elsif (COUNT_RECV = 3) THEN
					IF (I2C_BUSY = '0') THEN
						DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
					END IF;
					I2C_WR <= '1';
					I2C_ENA <= '1';
				elsif (COUNT_RECV = 4) THEN
					IF (I2C_BUSY = '0') THEN
						DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
					END IF;
					I2C_WR <= '1';
					I2C_ENA <= '1';
				elsif (COUNT_RECV = 5) THEN
					IF (I2C_BUSY = '0') THEN
						DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
					END IF;
					I2C_WR <= '1';
					I2C_ENA <= '1';
				elsif (COUNT_RECV = 6) THEN
					IF (I2C_BUSY = '0') THEN
						DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
						FLAG_500ms := 0;
						COUNT_SEND := 0;
					END IF;
				END IF;
			END IF;
		
		END IF;
	END PROCESS;
	
	P2: PROCESS(CLK)
		VARIABLE i: INTEGER RANGE 1 TO 7 := 1;
		VARIABLE j: INTEGER RANGE 1 TO 34 := 1;
		variable k : integer := 0;
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			IF (i < 7 AND LCD_BUSY = '0') THEN
				LCD1602DATA <= INIT(i)(7 DOWNTO 0);
				LCD_RS <= '0';
				LCD_BUSY <= '1';
				i := i + 1;
			END IF;	
			
			IF (LCD_BUSY = '0' AND i = 7) THEN
				CASE j IS
					WHEN 1 TO 16 =>
						LCD1602DATA <= TEMP(j)(7 DOWNTO 0);
						LCD_RS <= '1';
						LCD_BUSY <= '1';
						j := j + 1;
					WHEN 17 =>
						LCD1602DATA <= X"C0";
						LCD_RS <= '0';
						LCD_BUSY <= '1';
						j := j + 1;
					WHEN 18 to 33 =>
						LCD1602DATA <= HUMD(j-17)(7 DOWNTO 0);
						LCD_RS <= '1';
						LCD_BUSY <= '1';
						j := j + 1;
					WHEN 34 =>
						LCD1602DATA <= X"80";
						LCD_RS <= '0';
						LCD_BUSY <= '1';
						j := 1;
				END CASE;
			END IF;
			
			IF (LCD_BUSY = '1') THEN
				IF (k <= 1000000) THEN
					k := k + 1;
					LCD_E <= '1';
				elsif ((k > 1000000) and (k < 2000000)) THEN
					k := k + 1;
					LCD_E <= '0';
				elsif k = 2000000 THEN
					LCD_BUSY <= '0';
					k := 0;
				END IF;
			END IF;
		END IF;
	END PROCESS;


END BEHAVIOUR;

