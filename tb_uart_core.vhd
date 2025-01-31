-- Code your testbench here
library IEEE;
use IEEE.std_logic_1164.all;
use work.all;--includes uart_core

entity tb_uart_core is
end tb_uart_core;

architecture bhv of tb_uart_core is
	signal	uart_data_sent: std_logic;
	signal	uart_data_received: std_logic;
	signal	uart_stop_error: std_logic;
	
	signal	uart_wren: std_logic;
	signal	uart_rden: std_logic;
    signal	uart_data_out: std_logic_vector(7 downto 0);
    signal	uart_data_in: std_logic_vector(7 downto 0);
    
    signal tx: std_logic;
    signal rx: std_logic;
    
    signal rst: std_logic;
    signal iack: std_logic;--resets all flags!
    signal uart_phy_clk: std_logic;--bit clock (not transmitted)
begin

	uart_rden <= '1';
    -- Instantiation of UART Core
    dut: entity work.uart_core
        port map (
            rst => rst,
            clk => uart_phy_clk,
            D => uart_data_in,
            wren => uart_wren,
            rden => uart_rden,
            Q => uart_data_out,
			iack => iack,
            data_sent => uart_data_sent,
            data_received => uart_data_received,
            stop_error => uart_stop_error,
            tx => tx,
            rx => rx
        );
        
    clock: process
    begin
    	uart_phy_clk <='0';
        wait for 26 us;
    	uart_phy_clk <='1';
        wait for 26 us;        
    end process clock;
    
    rst<= '1', '0' after 52 us;
    --rx <= '1', '0' after 1 ms, '1' after 4800 us;
	 rx <=  '1', '0' after 10 ms, '1' after 11.23 ms, '0' after 11.665ms, '1' after 13.73ms, '0' after 14.153ms, '1' after 14.996ms, '0' after 15.405ms, '1' after 17.9ms;
  	iack <= '0';
end bhv;