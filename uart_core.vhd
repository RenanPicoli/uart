library ieee;
use ieee.std_logic_1164.all;-- declara os tipos std_logic, std_logic_vector e outros

entity uart_core is
	port (
		--interface com cpu
		rst: in std_logic;-- reset (assíncrono)
		clk: in std_logic;-- clock interno para amostragem, não faz parte da iterface UART
		D: in std_logic_vector(7 downto 0);-- uart serializa dados recebidos em paralelo (bytes)
		wren: in std_logic;-- marca o ciclo de clock em que a entrada D deve ser gravada e inicia a transmissão
		rden: in std_logic;-- lê o dado recebido e zera a flag data_received
		Q: out std_logic_vector(7 downto 0);-- uart paraleliza dados recebidos em serialmente (bytes)
		---- flags
		data_sent: out std_logic;
		data_received: buffer std_logic;--buffrer em vez de out para permitir ser lido pela própria uart
		stop_error: out std_logic;--não recebeu o stop bit
		---- pinos da interface UART
		tx: out std_logic;
		rx: in std_logic-- a última porta não tem o ponto-e-vírgula
	);
end uart_core;

architecture bhv of uart_core is
--declare sinais internos da architecture aqui

signal transmit_register: std_logic_vector(7 downto 0);
signal receive_register: std_logic_vector(7 downto 0);

-- shift registers
-- 10 bits pois incluem o start e stop bit, sem bit the paridade
signal tx_shift_register: std_logic_vector(9 downto 0);
signal rx_shift_register: std_logic_vector(9 downto 0);

constant CLK_PER_BIT: natural := 8;

signal start_tx: std_logic;-- inicie a transmissão
signal tx_bit_count: natural;
signal tx_count: natural;
signal load_tx_shift_reg: std_logic;-- inicie o deslocamento do tx_shift_register

--para simulação apenas!
signal tx_state: string (1 to 5);

signal previous_rx: std_logic;-- estado de rx no ciclo anterior
signal start_rx: std_logic;-- inicie a recepção
signal rx_bit_count: natural;
signal rx_count: natural;

--para simulação apenas!
signal rx_state: string (1 to 5);

begin
-- a partir daqui ponha concurrent assignments

--########### transmissão ###########

--carrega o dado no transmit_register
process(rst,clk,wren,D)
begin
	if(rst='1')then
		transmit_register <= (others=>'0');
	elsif(rising_edge(clk) and wren='1')then
		transmit_register <= D;
	end if;
end process;

--tx_shift_register carrega e começa a deslocar
process(rst,clk,wren,tx_count)
begin
	if(rst='1')then
		tx_shift_register <= (others=>'0');
		start_tx <= '0';
		tx_bit_count <= 0;
		load_tx_shift_reg <= '0';
		data_sent <='0';
	elsif(rising_edge(clk))then
		load_tx_shift_reg<= wren;--atrasa um clock o wren
		--carrega o shift register
		if(load_tx_shift_reg='1' and start_tx='0')then
									-- stop & D(7 downto 0)    & start
			tx_shift_register <= '1' & transmit_register & '0';
			start_tx <= '1';
			tx_bit_count <= 0;
			data_sent <='0';
		--faz um deslocamento para a direita
		elsif(start_tx = '1' and  tx_count=CLK_PER_BIT-1)then
			tx_shift_register <= '1' & tx_shift_register(9 downto 1);
			tx_bit_count <= tx_bit_count+1;
		--encerra a transmissão
		elsif(start_tx = '1' and tx_bit_count=10)then
			start_tx <= '0';
			tx_bit_count <= 0;
			data_sent <='1';
		end if;
	end if;
end process;

process(rst,clk,start_tx)
begin
	if(rst='1')then
	 tx_count <= 0;
	elsif(rising_edge(clk))then
		if(start_tx='1')then
			if(tx_count = CLK_PER_BIT-1)then
				tx_count <= 0;
			else
				tx_count <= tx_count+1;
			end if;
		else-- se start_tx='0'
			tx_count <= 0;
		end if;
	end if;
end process;

tx <= tx_shift_register(0) when start_tx='1' else '1';

--PARA sIMULAÇÃO APENAS!
-- synthesis translate_off
tx_state <=	"START"	when (start_tx='1' and tx_bit_count=0) else
				"D0   "	when (start_tx='1' and tx_bit_count=1) else
				"D1   "	when (start_tx='1' and tx_bit_count=2) else
				"D2   "	when (start_tx='1' and tx_bit_count=3) else
				"D3   "	when (start_tx='1' and tx_bit_count=4) else
				"D4   "	when (start_tx='1' and tx_bit_count=5) else
				"D5   "	when (start_tx='1' and tx_bit_count=6) else
				"D6   "	when (start_tx='1' and tx_bit_count=7) else
				"D7   "	when (start_tx='1' and tx_bit_count=8) else
				"STOP "	when (start_tx='1' and tx_bit_count=9) else
				"IDLE ";
-- synthesis translate_on


--########### recepção ###########
-- start_rx detecta o ínício de uma transmissão
process(rst,clk,wren,tx_count)
begin
	if(rst='1')then
		start_rx <= '0';
		rx_bit_count <= 0;
		data_received <='0';
		rx_shift_register <= (others=>'0');
		previous_rx <= '1';
		stop_error <= '0';
	elsif(rising_edge(clk))then
		previous_rx <= rx;
		-- detecta a borda de descida do rx que incia a transmissão
		if(start_rx='0' and rx='0' and previous_rx='1')then
			start_rx <= '1';
			rx_bit_count <= 0;
			data_received <='0';
		--faz um deslocamento para a esquerda
		--rx_count=CLK_PER_BIT/2-1 faz amostrar no meio do período do bit
		elsif(start_rx = '1' and  rx_count=CLK_PER_BIT/2-1)then
			rx_shift_register <= rx & rx_shift_register(9 downto 1);
		elsif(start_rx = '1' and  rx_count=CLK_PER_BIT-1)then
			rx_bit_count <= rx_bit_count+1;
		--encerra a recepção
		elsif(start_rx = '1' and rx_bit_count=10)then
			start_rx <= '0';
			rx_bit_count <= 0;
			data_received <='1';
			--confere se o stop bit foi recebido corretamente
			if(rx_shift_register(9)='1')then
				stop_error <= '0';
			else
				stop_error <= '1';
			end if;
		end if;
	end if;
end process;

process(rst,clk,rx_count)
begin
	if(rst='1')then
		rx_count <= 0;
	elsif(rising_edge(clk))then
		if(start_rx='1')then
			if(rx_count = CLK_PER_BIT-1)then
				rx_count <= 0;
			else
				rx_count <= rx_count+1;
			end if;
		else-- se start_rx='0'
			rx_count <= 0;
		end if;
	end if;
end process;

--carrega o dado no receive_register
process(rst,clk,data_received)
begin
	if(rst='1')then
		receive_register <= (others=>'0');
	elsif(rising_edge(clk) and data_received='1')then
		receive_register <= rx_shift_register(8 downto 1);
	end if;
end process;

Q <= receive_register when rden='1' else (others=>'0');

--PARA sIMULAÇÃO APENAS!
-- synthesis translate_off
rx_state <=	"START"	when (start_rx='1' and rx_bit_count=0) else
				"D0   "	when (start_rx='1' and rx_bit_count=1) else
				"D1   "	when (start_rx='1' and rx_bit_count=2) else
				"D2   "	when (start_rx='1' and rx_bit_count=3) else
				"D3   "	when (start_rx='1' and rx_bit_count=4) else
				"D4   "	when (start_rx='1' and rx_bit_count=5) else
				"D5   "	when (start_rx='1' and rx_bit_count=6) else
				"D6   "	when (start_rx='1' and rx_bit_count=7) else
				"D7   "	when (start_rx='1' and rx_bit_count=8) else
				"STOP "	when (start_rx='1' and rx_bit_count=9) else
				"IDLE ";
-- synthesis translate_on
end bhv;