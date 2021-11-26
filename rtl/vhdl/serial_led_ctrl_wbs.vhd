-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Filename: serial_led_ctrl_wbs.vhd
-- Dependencies: serial_led_ctrl_engine.vhd
--
-- Brief: WB peripheral interface to serial LED control engine
--        Peripherale is stalled as long as data word needs to be written to output
--        Bus transaction gets acknowledged after writing data word to register
--
-- Bus: Wishbone, Version B4
--
-- Author: Digital Runecaster
-- Date: November 2021
-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Version: 0.1
-- License: MLP v2.0 - Mozilla Public License, v. 2.0
-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Status: Work in Progress
-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity serial_led_ctrl_wbs is
    generic (
          SYSCON_CLK_FREQ         : natrual := 100000000                                -- system clock frequency
        ; WB_ADDR_WIDTH           : natural := 8                                        -- WB address bus width
        ; WB_DATA_WIDTH           : natural := 32                                       -- WB data width, must be equal to LED data
    );
    port (
          wb_clk_i              : in std_logic                                          -- syscon clk
        ; wb_rst_i              : in std_logic                                          -- syscon rst
        ; wb_cyc_i              : in std_logic                                          -- bus transaction
        ; wb_stb_i              : in std_logic                                          -- peripheral transaction request
        ; wb_addr_i             : in std_logic_vector (WB_ADDR_WIDTH - 1 downto 0)      -- register address
        ; wb_dat_i              : in std_logic_vector (WB_DATA_WIDTH - 1 downto 0)      -- data input
        ; wb_ack_o              : out std_logic := '0'                                  -- transaction complete
        ; wb_stall_o            : out std_logic := '0'                                  -- peripheral busy
    );
end entity serial_led_ctrl_wbs;

begin architecture synthesis of serial_led_ctrl_wbs

    component serial_led_ctrl_engine is
    
        generic (
              CLOCK_FREQ                :   natural := 1  
    		; LED_DATA_WORD             :   natural := 32          
        );
        port (
              clk                       :   in std_logic   
            ; rst                       :   in std_logic  
    		; output_en                 :   in std_logic  
    		; wr_en 			        :   in std_logic   
            ; led_data_in               :   in std_logic_vector (LED_DATA_WORD -1 downto 0)
            ; led_data_out              :   out std_logic := '0'  
            ; busy                      :   out std_logic := '0'  
    		; led_data_ack              :   out std_logic := '0'  
        );
    end component serial_led_ctrl_engine;

    signal status_reg                   : std_logic_vector (WB_DATA_WORD - 1 downto 0) := (others => '0');
    signal led_data                     : std_logic_vector (WB_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal wr_en_led_engine             : std_logic := '0';
    signal led_data_ack                 : std_logic;

begin

    --
    -- Instantiate LED engine
    --
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

    --
    -- Process for setting LED data or output enable staus
    --
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

    --
    -- Bus transaction complete process
    --
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
