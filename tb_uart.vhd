library ieee;
use ieee.std_logic_1164.all;-- declara os tipos std_logic, std_logic_vector e outros
use work.all;

entity tb is
end tb;

architecture bhv of tb is
		--interface com cpu
signal		rst: std_logic;-- reset (assíncrono)
signal		clk: std_logic;-- clock interno para amostragem, não faz parte da iterface UART
signal		D: std_logic_vector(7 downto 0);-- uart serializa dados recebidos em paralelo (bytes)
signal		wren: std_logic;-- marca o ciclo de clock em que a entrada D deve ser gravada e inicia a transmissão
signal		rden: std_logic;-- lê o dado recebido e zera a flag data_received
signal		Q: std_logic_vector(7 downto 0);-- uart paraleliza dados recebidos em serialmente (bytes)
		---- flags
signal		data_sent: std_logic;
signal		data_received: std_logic;
signal		stop_error: std_logic;

		---- pinos da interface UART
signal		tx: std_logic;
signal		rx: std_logic;

--sinais da segunda uart
signal		D_2: std_logic_vector(7 downto 0);-- uart serializa dados recebidos em paralelo (bytes)
signal		wren_2: std_logic;-- marca o ciclo de clock em que a entrada D deve ser gravada e inicia a transmissão
signal		tx_2: std_logic;
signal		rx_2: std_logic;
 
begin

	uut: entity work.uart
	port map(
		--interface com cpu
		rst => rst,-- reset (assíncrono)
		clk => clk,-- clock interno para amostragem, não faz parte da iterface UART
		D => D,-- uart serializa dados recebidos em paralelo (bytes)
		wren => wren,-- marca o ciclo de clock em que a entrada D deve ser gravada e inicia a transmissão
		rden => rden,-- lê o dado recebido e zera a flag data_received
		Q => Q,-- dados recebidos são lidos em paralelo
		---- flags
		data_sent => data_sent,
		data_received => data_received,
		stop_error => stop_error,
		---- pinos da interface UART
		tx => tx,
		rx => rx-- a última porta não tem vírgula!
	);
	
	rst <= '1', '0' after 1ms;
	
	--clock de 10kHz
	process
	begin
		clk <= '0';
		wait for 0.05ms;
		clk <= '1';
		wait for 0.05ms;
	end process;
	
	D <= (others=>'0'), x"AB" after 2ms, (others=>'0') after 2.1ms;
	wren <= '0', '1' after 2ms, '0' after 2.1ms;
	
	rx <= tx_2;
	rx_2 <= tx;
	
	rden <= '0';
	
	uart_2: entity work.uart
	port map(
		--interface com cpu
		rst => rst,-- reset (assíncrono)
		clk => clk,-- clock interno para amostragem, não faz parte da iterface UART
		D => D_2,-- uart serializa dados recebidos em paralelo (bytes)
		wren => wren_2,-- marca o ciclo de clock em que a entrada D deve ser gravada e inicia a transmissão
		rden => '0',-- lê o dado recebido e zera a flag data_received
		Q => open,-- dados recebidos são lidos em paralelo
		---- flags
		data_sent => open,
		data_received => open,
		stop_error => open,
		---- pinos da interface UART
		tx => tx_2,
		rx => rx_2-- a última porta não tem vírgula!
	);
	
	D_2 <= (others=>'0'), x"AA" after 5ms, (others=>'0') after 5.1ms;
	wren_2 <= '0', '1' after 5ms, '0' after 5.1ms;
end bhv;