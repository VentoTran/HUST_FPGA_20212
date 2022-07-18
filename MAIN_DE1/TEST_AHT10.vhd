LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.all;

ENTITY TEST_AHT10 IS
	PORT(
		CLK				: IN		STD_LOGIC;
		SW					: IN		STD_LOGIC_VECTOR (9 DOWNTO 0);
		LEDR				: OUT		STD_LOGIC_VECTOR (9 DOWNTO 0);
		KEY				: IN		STD_LOGIC_VECTOR (3 DOWNTO 0);
		LEDG				: OUT 	STD_LOGIC_VECTOR (7 DOWNTO 0);
		LED7_0			: OUT		STD_LOGIC_VECTOR (6 DOWNTO 0);
		LED7_1			: OUT		STD_LOGIC_VECTOR (6 DOWNTO 0);
		LED7_2			: OUT		STD_LOGIC_VECTOR (6 DOWNTO 0);
		LED7_3			: OUT		STD_LOGIC_VECTOR (6 DOWNTO 0);
		I2C_SDA       	: INOUT  STD_LOGIC;  	
		I2C_SCL       	: INOUT  STD_LOGIC;
		SERIAL_TX			: OUT		STD_LOGIC
	);
END TEST_AHT10;


ARCHITECTURE BEHAVIOUR OF TEST_AHT10 IS
	
	TYPE ARR6bLED7A IS ARRAY (1 to 10) OF STD_LOGIC_VECTOR(6 DOWNTO 0);
	CONSTANT LED7A	:	ARR6bLED7A	:=	("1000000","1111001","0100100","0110000","0011001","0010010","0000010","1111000","0000000","0010000");
	
	TYPE ARR6 IS ARRAY (1 to 6) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL DATA: ARR6 := (X"00",X"00",X"00",X"00",X"00",x"00");
	
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
	
	COMPONENT UART_TX is
		port (
			CLK       : in  STD_LOGIC;
			TX_EN     : in  STD_LOGIC;
			TX_Byte   : in  STD_LOGIC_VECTOR(7 downto 0);
			TX_Serial : out STD_LOGIC := '0';
			TX_Done   : out STD_LOGIC := '0'
		);
	end COMPONENT UART_TX;
	
	SIGNAL UART_ENA		:	STD_LOGIC	:= '0';
	SIGNAL UART_BYTE		:	STD_LOGIC_VECTOR (7 DOWNTO 0);
	SIGNAL UART_DONE		:	STD_LOGIC	:= '0';
	SIGNAL UART_DONE_PREV:	STD_LOGIC	:= '0';
	SIGNAL UART_READY		:	STD_LOGIC	:= '0';
	
	SIGNAL I2C_RST			:	STD_LOGIC	:= '1';
	SIGNAL I2C_ENA			:	STD_LOGIC	:= '0';
	SIGNAL I2C_WR			:	STD_LOGIC;
	SIGNAL I2C_BUSY		:	STD_LOGIC	:= '0';
	SIGNAL I2C_BUSY_PREV	:	STD_LOGIC	:= '0';
	SIGNAL I2C_ERROR		:	STD_LOGIC	:= '0';
	SIGNAL I2C_ADDR		: 	STD_LOGIC_VECTOR(6 DOWNTO 0) := "0111000";
	SIGNAL I2C_DATA_OUT	: 	STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL I2C_DATA_IN	:	STD_LOGIC_VECTOR(7 DOWNTO 0);
	
	SIGNAL TEMPERATURE	:	INTEGER RANGE 0 TO 100;
	SIGNAL HUMIDITY		:	INTEGER RANGE 0 TO 100;

BEGIN

	C1: I2C_Master port map (	clk=>CLK, 			reset_n=>I2C_RST, 		ena=>I2C_ENA, 				addr=>I2C_ADDR, 	rw=>I2C_WR, 	data_wr=>I2C_DATA_OUT,
										busy=>I2C_BUSY, 	data_rd=>I2C_DATA_IN, 	ack_error=>I2C_ERROR, 	sda=>I2C_SDA, 		scl=>I2C_SCL);

	C2: UART_TX port map	(CLK=>CLK,	TX_EN=>UART_ENA,	TX_Byte=>UART_BYTE,	TX_Done=>UART_DONE,	TX_Serial=>SERIAL_TX);
	
	P1: PROCESS(CLK)
		VARIABLE COUNT_1s: 		INTEGER RANGE 0 TO 50000000 := 0;
		VARIABLE FLAG_1s: 		INTEGER RANGE 0 TO 1 := 0;
		VARIABLE COUNT_SEND: 	INTEGER RANGE 0 TO 3	:= 0;
		VARIABLE COUNT_RECV: 	INTEGER RANGE 0 TO 6 := 0;
		VARIABLE FLAG_DONE: 		INTEGER RANGE 0 TO 1 := 0;
		VARIABLE ADC_TEMP_RAW:	STD_LOGIC_VECTOR (19 DOWNTO 0);
		VARIABLE ADC_HUMD_RAW:	STD_LOGIC_VECTOR (19 DOWNTO 0);
		VARIABLE TEMP_RAW:		INTEGER	:= 0;
		VARIABLE HUMD_RAW:		INTEGER	:=	0;
		VARIABLE LED:				STD_LOGIC	:= '0';
		VARIABLE J	:	INTEGER RANGE 0 TO 4;
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			
			I2C_RST <= '1';
			I2C_ADDR <= "0111000";
			I2C_BUSY_PREV <= I2C_BUSY;
			
			LEDG(5) <= I2C_ERROR;
			LEDG(3) <= I2C_BUSY;
			LEDG(6) <= LED;
			
			IF (I2C_BUSY_PREV = '0' AND I2C_BUSY = '1' AND I2C_ENA = '1' AND FLAG_1s = 1) THEN
				IF (COUNT_SEND = 3) THEN
					IF (COUNT_RECV < 6) THEN
						COUNT_RECV := COUNT_RECV + 1;
					END IF;
					IF (COUNT_RECV = 6) THEN
						I2C_ENA <= '0';
					END IF;
				END IF;
				
				IF (COUNT_SEND < 3) THEN
					COUNT_SEND := COUNT_SEND + 1;
					IF (COUNT_SEND = 3) THEN
						I2C_ENA <= '0';
						FLAG_1s := 0;
					END IF;
				END IF;
			END IF;
			
			IF (I2C_ERROR = '1') THEN
				I2C_RST <= '0';
				FLAG_1s := 0;
			END IF;
			
			IF (COUNT_1s = 50000000) THEN
				COUNT_1s := 0;
				FLAG_1s := 1;
				LED := NOT(LED);
			ELSE
				COUNT_1s := COUNT_1s + 1;
			END IF;
			
			IF (FLAG_1s = 1 AND FLAG_DONE = 1) THEN
				ADC_HUMD_RAW := DATA(2)(7 DOWNTO 0) & DATA(3)(7 DOWNTO 0) & DATA(4)(7 DOWNTO 4);
				ADC_TEMP_RAW := DATA(4)(3 DOWNTO 0) & DATA(5)(7 DOWNTO 0) & DATA(6)(7 DOWNTO 0);
				HUMD_RAW := to_integer(unsigned(ADC_HUMD_RAW));
				TEMP_RAW := to_integer(unsigned(ADC_TEMP_RAW));
				HUMIDITY <= INTEGER(HUMD_RAW * INTEGER(100) / 1048576);
				TEMPERATURE <= INTEGER(TEMP_RAW * INTEGER(200) / 1048576) - INTEGER(50);
				LEDG(7) <= '0';
				LEDG(2) <= '0';
				FLAG_1s := 0;
				FLAG_DONE := 0;
				UART_READY <= '1';
			END IF;
			
			IF (FLAG_1s = 1 AND FLAG_DONE = 0) THEN
				CASE COUNT_SEND IS
					WHEN 0 =>
						I2C_DATA_OUT <= "10101100";
						I2C_WR <= '0';
						I2C_ENA <= '1';
						LEDG(7) <= '1';
					WHEN 1 =>
						I2C_DATA_OUT <= "00110011";
					WHEN 2 =>
						I2C_DATA_OUT <= "00000000";
					WHEN 3 =>
						CASE COUNT_RECV IS
							WHEN 0 =>
								I2C_WR <= '1';
								I2C_ENA <= '1';
								LEDG(2) <= '1';
							WHEN 1 =>
								IF (I2C_BUSY = '0') THEN
									DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
								END IF;
							WHEN 2 =>
								IF (I2C_BUSY = '0') THEN
									DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
								END IF;
							WHEN 3 =>
								IF (I2C_BUSY = '0') THEN
									DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
								END IF;
							WHEN 4 =>
								IF (I2C_BUSY = '0') THEN
									DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
								END IF;
							WHEN 5 =>
								IF (I2C_BUSY = '0') THEN
									DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
								END IF;
							WHEN 6 =>
								IF (I2C_BUSY = '0') THEN
									DATA(COUNT_RECV)(7 DOWNTO 0) <= I2C_DATA_IN;
									FLAG_1s := 0;
									FLAG_DONE := 1;
									COUNT_SEND := 0;
									COUNT_RECV := 0;
								END IF;
						END CASE;
				END CASE;
			END IF;
			
			
			IF (UART_READY = '1') THEN
				UART_DONE_PREV <= UART_DONE;
				
				CASE J IS
					WHEN 0 =>
						UART_BYTE(7 DOWNTO 0) <= std_logic_vector(to_unsigned(TEMPERATURE, 8));
						UART_ENA <= '1';
						J := J + 1;
					WHEN 1 =>
						UART_ENA <= '0';
					WHEN 2 =>
						UART_BYTE(7 DOWNTO 0) <= std_logic_vector(to_unsigned(HUMIDITY, 8));
						UART_ENA <= '1';
						J := J + 1;
					WHEN 3 =>
						UART_ENA <= '0';
					WHEN 4 =>
						J := 0;
						UART_ENA <= '0';
						UART_READY <= '0';
						UART_DONE_PREV <= '0';
				END CASE;
				
				IF (UART_DONE_PREV = '0' AND UART_DONE = '1' AND ((J = 1) OR (J = 3))) THEN
					J := J + 1;
				END IF;
				
			END IF;
		
		END IF;
	END PROCESS;

	P2: PROCESS(CLK)
		VARIABLE I	:	INTEGER RANGE 0 TO 9;
	BEGIN
		IF (CLK'EVENT AND CLK = '1') THEN
			
			I := INTEGER(TEMPERATURE / 10);
			LED7_3 <= LED7A(I+1)(6 DOWNTO 0);
			I := TEMPERATURE MOD 10;
			LED7_2 <= LED7A(I+1)(6 DOWNTO 0);
		
			I := INTEGER(HUMIDITY / 10);
			LED7_1 <= LED7A(I+1)(6 DOWNTO 0);
			I := HUMIDITY MOD 10;
			LED7_0 <= LED7A(I+1)(6 DOWNTO 0);
			
		END IF;
	END PROCESS;


END BEHAVIOUR;