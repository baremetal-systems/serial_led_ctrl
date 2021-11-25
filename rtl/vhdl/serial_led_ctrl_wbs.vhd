library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity serial_led_ctrl_wbs is
    generic (
          SYSCON_CLK_FREQ         : natrual := 100000000
        ; WB_ADDR_WIDTH           : natural := 8
        ; WB_DATA_WIDTH           : natural := 32
    );
    port (
          wb_clk_i              : in std_logic
        ; wb_rst_i              : in std_logic
        ; wb_cyc_i              : in std_logic
 --       ; wb_lock_i             : in std_logic
        ; wb_stb_i              : in std_logic
--        ; wb_we_i               : in std_logic
        ; wb_addr_i             : in std_logic_vector (WB_ADDR_WIDTH - 1 downto 0)
        ; wb_dat_i              : in std_logic_vector (WB_DATA_WIDTH - 1 downto 0)
        ; wb_ack_o              : out std_logic := '0'
        ; wb_stall_o            : out std_logic := '0'
--        ; wb_err_o              : out std_logic := '0'
--        ; wb_rty_o              : out std_logic := '0'
    );
end entity serial_led_ctrl_wbs;

begin architecture synthesis of serial_led_ctrl_wbs

    component serial_led_ctrl_engine is
    
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
    end component serial_led_ctrl_engine;

    signal status_reg                   : std_logic_vector (WB_DATA_WORD - 1 downto 0) := (others => '0');
    signal led_data                     : std_logic_vector (WB_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal wr_en_led_engine             : std_logic := '0';
    signal led_data_ack                 : std_logic;

begin

    serial_led: serial_led_ctrl_engine
        generic map (
              CLOCK_FREQ        => SYSCON_CLK_FREQ
            , LED_DATA_WORD     => WB_DATA_WIDTH 
        )
        port map (
              clk               => wb_clk_i
            , rst               => wb_rst_i
            , output_en         => status_reg(0)
            , wr_en             => wr_en_led_engine
            , led_data_in       => led_data
            , busy              => wb_stall_o
            , led_data_ack      => led_data_ack
        );

    register_update_proc: process(wb_clk_i)
    begin
        if (rising_edge(wb_clk_i)) then
            if (wb_rst_i) then
               wr_en_led_engine <= '0';
               status_reg <= (others => '0');
               led_data <= (others => '0');
            else
                if (wb_cyc_i and wb_stb_i and not wb_stall_o) then
                    if (unsigned(wb_addr_i) = 1) then
                        led_data <= wb_dat_i;
                        wr_en_led_engine <= '1';
                        status_reg <= status_reg;
                    elsif (unsigned(wb_addr_i) = 0) then
                        status_reg <= wb_dat_i;
                        led_data <= led_data;
                        wr_en_led_engine <= '0';
                    else
                        status_reg <= status_reg;
                        led_data <= led_data;
                        wr_en_led_engine <= '0';
                    end if;
                else
                    status_reg <= status_reg;
                    led_data <= led_data;
                    wr_en_led_engine <= '0';
                end if;
            end if;
        end if;
    end process register_update_proc;

    trans_ack_compl_proc: process(wb_clk_i)
    begin
        if (rising_edge(clk)) then
            if (wb_rst_i) then
                wb_ack_o <= '0';
            else
                wb_ack_o <= wb_stb_i and led_data_ack;
            end if;
        end if;
    end process trans_ack_compl_proc;


end architecture synthesis;
