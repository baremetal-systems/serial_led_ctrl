library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library STD;
use STD.env.finish;

entity tb_serial_led_ctrl_engine is
end entity tb_serial_led_ctrl_engine;

architecture behavior of tb_serial_led_ctrl_engine is

    component serial_led_ctrl_engine is
        generic (
              CLOCK_FREQ      :   natural
            ; LED_DATA_WORD   :   natural
        );

        port (
            clk             :   in std_logic;
            rst             :   in std_logic;
		    wr_en           :   in std_logic;
		    output_en       :   in std_logic;
            led_data_in     :   in std_logic_vector (LED_DATA_WORD -1 downto 0);
            led_data_out    :   out std_logic;
            busy            :   out std_logic;
		    led_data_ack    :   out std_logic
        );
    end component serial_led_ctrl_engine;

    constant CLK_PERIOD : time := 50 ns;
	constant LED_COUNT : natural := 2;
	constant LED_DATA_PERIOD : natural := 640 * LED_COUNT;

    signal tb_clk : std_logic := '1';
    signal tb_rst : std_logic := '0';
	signal tb_led_data : std_logic_vector (31 downto 0) := (others => '0');
    signal tb_led_data_out : std_logic;
    signal tb_busy : std_logic;
	signal tb_wr_en : std_logic := '0';
	signal tb_output_en : std_logic := '0';
	signal tb_led_data_ack : std_logic := '0';

begin

    tb_clk <= not tb_clk after CLK_PERIOD / 2;

    led_engine: serial_led_ctrl_engine
        generic map (
              CLOCK_FREQ => 12000000
            , LED_DATA_WORD => 32
        )
        port map (
            clk => tb_clk,
            rst => tb_rst,
			wr_en => tb_wr_en,
			output_en => tb_output_en,
			led_data_in => tb_led_data,
            led_data_out => tb_led_data_out,
            busy => tb_busy,
			led_data_ack => tb_led_data_ack
        );

    reset_process: process
    begin
        wait for CLK_PERIOD;
        tb_rst <= '1';
        wait for CLK_PERIOD * 2;
        tb_rst <= '0';
        wait;
    end process reset_process;

    process
    begin
		tb_output_en <= '1';
		wait for CLK_PERIOD * 10;
		tb_led_data <= b"00000000_00000000_00000000_00001111";
		tb_wr_en <= '1';
		wait for CLK_PERIOD * 1;
	    tb_wr_en <= '0';	
		wait until tb_busy = '0';

		tb_led_data <= b"00000000_00000000_00001111_00000000";
		tb_wr_en <= '1';
		wait for CLK_PERIOD * 1;
	    tb_wr_en <= '0';	
		wait until tb_busy = '0';

		tb_led_data <= b"00000000_00001111_00000000_00000000";
		tb_wr_en <= '1';
		wait for CLK_PERIOD * 1;
	    tb_wr_en <= '0';	
		wait until tb_busy = '0';

		tb_led_data <= b"00001111_00000000_00000000_00000000";
		tb_wr_en <= '1';
		wait for CLK_PERIOD * 1;
	    tb_wr_en <= '0';	
		wait until tb_busy = '0';

		wait for CLK_PERIOD * LED_DATA_PERIOD;
		tb_led_data <= b"00001111_00001111_00001111_00001111";
		tb_wr_en <= '1';
		wait for CLK_PERIOD * 1;
	    tb_wr_en <= '0';	
        wait until tb_busy = '0';

		tb_output_en <= '0';

		wait for CLK_PERIOD * 10;

		report "End of simulation";
        finish;
    end process;

end architecture behavior;
