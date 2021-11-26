-- +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Filename: serial_led_ctrl_ambas.vhd
-- Dependencies: serial_led_ctrl_engine.vhd
--
-- Brief: AMBA peripheral interface to serial LED control engine
--        Peripherale is stalled as long as data word needs to be written to output
--        Bus transaction gets acknowledged after writing data word to register
--
-- Bus: AMBA, Version 4
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

entity serial_led_ctrl_amabs is
    generic (
          PCLK_FREQ                     : natural := 100000000                                -- system clock frequency
        ; PSEL_ADDR                     : natural := 0
        ; PADDR_WIDTH                   : natural := 8                                        -- WB address bus width
        ; PSEL_WIDTH                    : natural := 8
        ; PWDATA_WIDTH                  : natural := 32                                       -- WB data width, must be equal to LED data
    );
    port (
          pclk                          : in std_logic
        ; presetn                       : in std_logic
        ; paddr                         : in std_logic_vector (PADDR_WIDTH - 1 downto 0)
        ; psel                          : in std_logic 
        ; penable                       : in std_logic
        ; pwrite                        : in std_logic
        ; pwdata                        ; in std_logic_vector (PWDATA_WIDTH - 1 downto 0)
        ; pready                        ; out std_logic := '0'
    );
end entity serial_led_ctrl_ambas;

architecture synthesis of serial_led_ctrl_ambas is

    component serial_led_ctrl_engine is
        generic (
              CLOCK_FREQ                :   natural 
    		; LED_DATA_WORD             :   natural          
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

    signal engine_busy                  : std_logic := '0';
    signal write_access                 : std_logic := '0';
    signal status_reg                   : std_logic_vector := (PWDATA_WIDTH - 1 downto 0) := (others => '0');
    signal led_data                     : std_logic_vector := (PWDATA_WIDTH - 1 downto 0) := (others => '0');
    signal wr_en_led_engine             : std_logic := '0';
    signal led_data_ack                 : std_logic := '0';

begin
    
    write_access <= psel and penable and psel(PSEL_ADDR) and not engine_busy;

    --
    -- Instantiate LED engine
    --
    serial_led: serial_led_ctrl_engine
        generic map (
              CLOCK_FREQ        => SYSCON_CLK_FREQ
            , LED_DATA_WORD     => WB_DATA_WIDTH 
        )
        port map (
              clk               => pclk
            , rst               => presetn
            , output_en         => status_reg(0)
            , wr_en             => wr_en_led_engine
            , led_data_in       => led_data
            , busy              => engine_busy 
            , led_data_ack      => led_data_ack
        );

    --
    -- Bus transaction complete process
    --
    trans_acc_compl_proc: process(pclk)
    begin
        if (rising_edge(pclk)) then
            if (presetn = '0') then
                pready <= '0';
            else
                if (write_access) then
                    pready <= '1';
                else
                    pready <= '0';
                end if;
            end if;
        end if;
    end process trans_acc_compl_proc;

    --
    -- Process for setting LED data or output enable staus
    --
    register_update_proc: process(pclk)
    begin
        if (rising_edge(pclk)) then
            if (presetn = '0') then 
                wr_en_led_engine <= '0';
                status_reg <= (others => '0');
                led_data <= (others => '0');
            else
                if (write_access = '1') then
                    if (unsigned(paddr) = 1) then
                        led_data <= pwdata;
                        wr_en_led_engine <= '1';
                        status_reg <= status_reg;
                    elsif (unsigned(paddr) = 0) then
                        led_data <= led_data;
                        wr_en_led_engine <= '0';
                        status_reg <= paddr;
                    else
                        led_data <= led_data;
                        wr_en_led_engine <= '0';
                        status_reg <= status_reg;
                    end if;
                else
                    led_data <= led_data;
                    wr_en_led_engine <= '1';
                    status_reg <= status_reg;
                end if;
            end if;
        end if;
    end process register_update_proc;

end architecture synthesis;
