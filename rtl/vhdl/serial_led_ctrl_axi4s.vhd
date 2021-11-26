-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Filename: serial_led_ctrl_axi4s.vhd
-- Dependencies: serial_led_ctrl_engine.vhd
--
-- Brief: AXI peripheral interface to serial LED control engine
--        Peripherale is stalled as long as data word needs to be written to output
--        Bus transaction gets acknowledged after writing data word to register
--
-- Bus: AXI, Version 4
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

entity serial_led_ctrl_axi4s is

end entity serial_led_ctrl_axi4s;

architecture synthesis of serial_led_ctrl_axi4s is

    component serial_led_ctrl_engine is
        generic (
              CLOCK_FREQ                :  natural 
    		; LED_DATA_WORD             :  natural          
        );
        port (
              clk                       :  in std_logic   
            ; rst                       :  in std_logic  
    		; output_en                 :  in std_logic  
    		; wr_en 			        :  in std_logic   
            ; led_data_in               :  in std_logic_vector (LED_DATA_WORD -1 downto 0)
            ; led_data_out              :  out std_logic := '0'  
            ; busy                      :  out std_logic := '0'  
    		; led_data_ack              :  out std_logic := '0'  
        );
    end component serial_led_ctrl_engine;

    signal status_reg                   : std_logic_vector (AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal led_data                     : std_logic_vector (AXI_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal wr_en_led_engine             : std_logic := '0';
    signal led_data_ack                 : std_logic := '0';

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

end architecture synthesis;
