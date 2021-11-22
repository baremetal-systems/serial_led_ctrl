library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity serial_led_ctrl_engine is

    generic (
          CLOCK_FREQ                :   natural := 1  -- value of system clock frequency, e.g. 12_000_000
		; LED_DATA_WORD             :   natural := 32  -- data word for led, 32/24 bits
    );

    port (
          clk                       :   in std_logic  -- system clock in 
        ; rst                       :   in std_logic  -- system reset in
		; output_en                 :   in std_logic  -- enable led output pulse
		; wr_en 			        :   in std_logic  -- write falg for led data in 
        ; led_data_in               :   in std_logic_vector (LED_DATA_WORD -1 downto 0)  -- led data word in
        ; led_data_out              :   out std_logic := '0'  -- serial output to sk6812 led
        ; busy                      :   out std_logic := '0'  -- busy signal, writing serial led data word
		; led_data_ack              :   out std_logic := '0'  -- ack signal for new led data word
    );
end entity serial_led_ctrl_engine;


architecture synthesis of serial_led_ctrl_engine is	

	constant LED_PULSE_FREQ			:	natural := 800000;
	constant LED_PULSE_TICK_COUNT	: 	natural := natural(CEIL(real(CLOCK_FREQ) / real(LED_PULSE_FREQ))) + 1;
	constant PULSE_0_TICK_COUNT		:   natural := (natural(CEIL(real(LED_PULSE_TICK_COUNT) / real(8))) * 2) - 1;
	constant PULSE_1_TICK_COUNT		:	natural := (natural(CEIL(real(LED_PULSE_TICK_COUNT) / real(8))) * 5) - 1;
	constant TICK_COUNTER_WIDTH		:	natural := natural(CEIL(LOG2(real(LED_PULSE_TICK_COUNT)))); --+ 1;

	signal led_tick_counter_reg		:	std_logic_vector (TICK_COUNTER_WIDTH downto 0) := (others => '0');
	signal led_serial_out			:	std_logic := '0';

	signal wr_en_reg				:	std_logic := '0';
	signal out_en_reg				:	std_logic := '0';
	signal engine_busy_reg			:	std_logic := '0';
	signal data_ack_reg				:	std_logic := '0';

	signal led_data_reg				:	std_logic_vector (LED_DATA_WORD -1 downto 0) := (others => '0');
	signal bit_count_reg			:   std_logic_vector (LED_DATA_WORD -1 downto 0) := (others => '0');

	function all_bits_set(std_vec: std_logic_vector) return boolean is
		constant compare_vec : std_logic_vector (std_vec'range) := (others => '1');
	begin
		return std_vec = compare_vec;
	end function;


begin
	
	--
	-- CONTINOUS SIGNAL ASSIGNMENTS
	--	
	led_data_ack <= data_ack_reg;
	busy <= engine_busy_reg;
	led_data_out <= led_serial_out;

	--
	-- SK6812 pulse generation engine
	--
	led_engine_proc: process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				led_tick_counter_reg <= (others => '0');
				bit_count_reg <= (others => '0');
			else
				if (out_en_reg = '1') then
					if (engine_busy_reg = '1') then
						if (unsigned(led_tick_counter_reg) < LED_PULSE_TICK_COUNT - 1) then
							led_tick_counter_reg <= std_logic_vector (unsigned(led_tick_counter_reg) + 1);
							bit_count_reg <= bit_count_reg;
						else 
							led_tick_counter_reg <= (others => '0');
--							bit_count_reg <= std_logic_vector (unsigned(bit_count_reg) + 1);
							bit_count_reg <= bit_count_reg(LED_DATA_WORD - 2 downto 0) & '1';
						end if;
					else
						led_tick_counter_reg <= (others => '0');
						bit_count_reg <= (others => '0');
					end if;
				else
					led_tick_counter_reg <= (others => '0');
					bit_count_reg <= (others => '0');
				end if;
			end if;
		end if;
	end process led_engine_proc;

    --
	-- serial out generation
	--
	led_out_proc: process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				led_serial_out <= '0';
			else
				if (engine_busy_reg = '1' and bit_count_reg(LED_DATA_WORD - 1) /= '1') then
						if (led_data_reg(LED_DATA_WORD -1) = '1') then
							if (unsigned(led_tick_counter_reg) < PULSE_1_TICK_COUNT) then
								led_serial_out <= '1';
							else
								led_serial_out <= '0';
							end if;
						else
							if (unsigned(led_tick_counter_reg) < PULSE_0_TICK_COUNT) then
								led_serial_out <= '1';
							else
								led_serial_out <= '0';
							end if;
						end if;
				else 
					led_serial_out <= '0';
				end if;
			end if;
		end if;
	end process led_out_proc;

	--
	-- data update process
	--
	led_update_proc: process(clk)
	begin
		if (rising_edge(clk)) then
			if(rst = '1') then
				wr_en_reg <= '0';
				out_en_reg <= '0';
				engine_busy_reg <= '0';
				data_ack_reg <= '0';

				led_data_reg <= (others => '0');
			else
				out_en_reg <= output_en;
				wr_en_reg <= wr_en;

				if (wr_en = '1' and wr_en_reg = '0') then
					data_ack_reg <= '1';
				else
					data_ack_reg <= '0';
				end if;

				if (data_ack_reg = '1' and engine_busy_reg = '0') then
					led_data_reg <= led_data_in;
				elsif (unsigned(led_tick_counter_reg) >= LED_PULSE_TICK_COUNT -1) then
					led_data_reg <= std_logic_vector (shift_left(unsigned(led_data_reg), 1));
				else
					led_data_reg <= led_data_reg;
				end if;

				if (data_ack_reg <= '1' and wr_en_reg = '1') then
					engine_busy_reg <= '1';
				elsif (bit_count_reg(LED_DATA_WORD -1) = '1') then
					engine_busy_reg <= '0';
				else
					engine_busy_reg <= engine_busy_reg;
				end if;
			end if;	
		end if;
	end process led_update_proc;

end architecture synthesis;
