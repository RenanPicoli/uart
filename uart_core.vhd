library ieee;
use ieee.std_logic_1164.all;-- declara os tipos std_logic, std_logic_vector e outros
use ieee.numeric_std.all;--to_unsigned
--use ieee.std_logic_arith.all;--convert to slv, '+' overload

entity uart_core is
	port (
		--interface com cpu
		rst: in std_logic;-- reset (assíncrono)
		clk: in std_logic;-- clock interno para amostragem, não faz parte da iterface UART
		D: in std_logic_vector(7 downto 0);-- uart serializa dados recebidos em paralelo (bytes)
		wren: in std_logic;-- marca o ciclo de clock em que a entrada D deve ser gravada e inicia a transmissão
		rden: in std_logic;-- lê o dado recebido e zera a flag data_received
		Q: out std_logic_vector(7 downto 0);-- uart paraleliza dados recebidos em serialmente (bytes)
		--INTERRUPT ACK
		iack: in std_logic;--resets all flags!
		---- flags
		data_sent: out std_logic;
		data_received: out std_logic;--buffrer em vez de out para permitir ser lido pela própria uart
		stop_error: out std_logic;--não recebeu o stop bit
		---- pinos da interface UART
		tx: out std_logic;
		rx: in std_logic-- a última porta não tem o ponto-e-vírgula
	);
end uart_core;

architecture bhv of uart_core is
--declare sinais internos da architecture aqui

signal receive_register: std_logic_vector(7 downto 0);

-- shift registers
-- 10 bits pois incluem o start e stop bit, sem bit the paridade
signal tx_shift_register: std_logic_vector(9 downto 0);
signal rx_shift_register: std_logic_vector(9 downto 0);

constant CLK_PER_BIT: natural := 8;

signal start_tx: std_logic;-- inicie a transmissão
signal tx_bit_count: std_logic_vector(3 downto 0);
signal tx_count: std_logic_vector(3 downto 0);

--para simulação apenas!
signal tx_state: string (1 to 5);

signal previous_rx: std_logic;-- estado de rx no ciclo anterior
signal start_rx: std_logic;-- inicie a recepção
signal rx_bit_count: std_logic_vector(3 downto 0);
signal rx_count: std_logic_vector(3 downto 0);

--para simulação apenas!
signal rx_state: string (1 to 5);
--preserving signals during synthesis for debugging
attribute preserve : boolean;
attribute preserve of start_rx: signal is true;
attribute preserve of start_tx: signal is true;
attribute preserve of tx_shift_register: signal is true;
attribute preserve of rx_shift_register: signal is true;
attribute preserve of receive_register: signal is true;
attribute preserve of data_received: signal is true;
attribute preserve of data_sent: signal is true;
attribute preserve of stop_error: signal is true;
attribute preserve of rx_count: signal is true;
attribute preserve of rx_bit_count: signal is true;
attribute preserve of tx_bit_count: signal is true;
attribute preserve of tx_count: signal is true;
attribute preserve of previous_rx: signal is true;

begin
-- a partir daqui ponha concurrent assignments

--########### transmissão ###########

--tx_shift_register carrega e começa a deslocar
process(rst,clk,wren,tx_count,tx_bit_count,iack)
begin
	if(rst='1')then
		tx_shift_register <= (others=>'0');
		start_tx <= '0';
		tx_bit_count <= (others=>'0');
	elsif(rising_edge(clk))then
		--carrega o shift register
		if(wren='1' and tx_bit_count=x"0")then
									-- stop & D(7 downto 0)    & start
			tx_shift_register <= '1' & D & '0';
			start_tx <= '1';
			tx_bit_count <= (others=>'0');
		--faz um deslocamento para a direita
		elsif(start_tx = '1' and  tx_count=std_logic_vector(to_unsigned(CLK_PER_BIT-1,4)))then
			tx_shift_register <= '1' & tx_shift_register(9 downto 1);
			tx_bit_count <= std_logic_vector(to_unsigned(to_integer(unsigned(tx_bit_count))+1,4));
		--encerra a transmissão
		elsif(start_tx = '1' and tx_bit_count=x"A")then--tx_bit_count=10
			start_tx <= '0';
			tx_bit_count <= (others=>'0');
		end if;
	end if;
end process;

process(rst,clk,wren,tx_count,tx_bit_count,iack)
begin
	if(rst='1' or iack='1')then
		data_sent <='0';
	elsif(rising_edge(clk))then
		--carrega o shift register
		if(wren='1' and tx_bit_count=x"0")then
			data_sent <='0';
		--encerra a transmissão
		elsif(start_tx = '1' and tx_bit_count=x"A")then--tx_bit_count=10
			data_sent <='1';
		end if;
	end if;
end process;

process(rst,clk,start_tx)
begin
	if(rst='1')then
	 tx_count <= (others=>'0');
	elsif(rising_edge(clk))then
		if(start_tx='1')then
			if(to_integer(unsigned(tx_count)) = CLK_PER_BIT-1)then
				tx_count <= (others=>'0');
			else
				tx_count <=std_logic_vector(to_unsigned(to_integer(unsigned(tx_count))+1,4));
			end if;
		else-- se start_tx='0'
			tx_count <= (others=>'0');
		end if;
	end if;
end process;

tx <= tx_shift_register(0) when start_tx='1' else '1';

--PARA SIMULAÇÃO APENAS!
-- synthesis translate_off
tx_state <=	"START"	when (start_tx='1' and tx_bit_count=x"0") else
				"D0   "	when (start_tx='1' and tx_bit_count=x"1") else
				"D1   "	when (start_tx='1' and tx_bit_count=x"2") else
				"D2   "	when (start_tx='1' and tx_bit_count=x"3") else
				"D3   "	when (start_tx='1' and tx_bit_count=x"4") else
				"D4   "	when (start_tx='1' and tx_bit_count=x"5") else
				"D5   "	when (start_tx='1' and tx_bit_count=x"6") else
				"D6   "	when (start_tx='1' and tx_bit_count=x"7") else
				"D7   "	when (start_tx='1' and tx_bit_count=x"8") else
				"STOP "	when (start_tx='1' and tx_bit_count=x"9") else
				"IDLE ";
-- synthesis translate_on


--########### recepção ###########
-- start_rx detecta o ínício de uma transmissão
process(rst,clk,tx_count,iack,start_rx,rx,previous_rx,rx_count,rx_bit_count,rx_shift_register)
begin
	if(rst='1')then
		start_rx <= '0';
		rx_bit_count <= (others=>'0');
		rx_shift_register <= (others=>'0');
		previous_rx <= '1';
	elsif(rising_edge(clk))then
		-- detecta a borda de descida do rx que incia a transmissão
		if(rx_bit_count=x"0" and rx='0' and previous_rx='1')then
			start_rx <= '1';
			rx_bit_count <= (others=>'0');
		--faz um deslocamento para a esquerda
		--rx_count=CLK_PER_BIT/2-1 faz amostrar no meio do período do bit
		elsif(start_rx = '1' and  rx_count=std_logic_vector(to_unsigned(CLK_PER_BIT/2-1,4)))then
			rx_shift_register <= rx & rx_shift_register(9 downto 1);
			--encerra a recepção se for o stop bit
			if(rx_bit_count=x"9")then
				start_rx <= '0';
				rx_bit_count <= (others=>'0');
			end if;
		elsif(start_rx = '1' and  rx_count=std_logic_vector(to_unsigned(CLK_PER_BIT-1,4)))then
			rx_bit_count <= std_logic_vector(to_unsigned(to_integer(unsigned(rx_bit_count))+1,4));
		end if;
		previous_rx <= rx;
	end if;
end process;

process(rst,clk,tx_count,iack,start_rx,rx,previous_rx,rx_count,rx_bit_count,rx_shift_register)
begin
	if(rst='1' or iack='1')then
	--if(rst='1')then
		stop_error <= '0';
		data_received <='0';
	elsif(rising_edge(clk))then
		--encerra a recepção
		if(start_rx = '1' and rx_bit_count=x"9" and rx_count=x"3")then
			data_received <='1';
			--confere se o stop bit foi recebido corretamente
			if(rx='1')then
				stop_error <= '0';
			else
				stop_error <= '1';
			end if;
		-- detecta a borda de descida do rx que incia a transmissão
		elsif(rx_bit_count=x"0" and rx='0' and previous_rx='1')then
			data_received <='0';
			stop_error <= '0';
		end if;
	end if;
end process;

process(rst,clk,rx_count)
begin
	if(rst='1')then
		rx_count <= (others=>'0');
	elsif(rising_edge(clk))then
		if(start_rx='1')then
			if(to_integer(unsigned(rx_count)) = CLK_PER_BIT-1)then
				rx_count <=(others=>'0');
			else
				rx_count <= std_logic_vector(to_unsigned(to_integer(unsigned(rx_count))+1,4));
			end if;
		else-- se start_rx='0'
			rx_count <= (others=>'0');
		end if;
	end if;
end process;

--carrega o dado no receive_register
process(rst,clk,start_rx,rx_bit_count,rx_count)
begin
	if(rst='1')then
		receive_register <= (others=>'0');
	elsif(rising_edge(clk) and start_rx = '1' and rx_bit_count=x"9" and rx_count=x"3")then--rx_bit_count=10
		--estou gravando antes de shiftar para receber o stop bit!
		receive_register <= rx_shift_register(9 downto 2);
	end if;
end process;

Q <= receive_register when rden='1' else (others=>'0');

--PARA sIMULAÇÃO APENAS!
-- synthesis translate_off
rx_state <=	"START"	when (start_rx='1' and rx_bit_count=x"0") else
				"D0   "	when (start_rx='1' and rx_bit_count=x"1") else
				"D1   "	when (start_rx='1' and rx_bit_count=x"2") else
				"D2   "	when (start_rx='1' and rx_bit_count=x"3") else
				"D3   "	when (start_rx='1' and rx_bit_count=x"4") else
				"D4   "	when (start_rx='1' and rx_bit_count=x"5") else
				"D5   "	when (start_rx='1' and rx_bit_count=x"6") else
				"D6   "	when (start_rx='1' and rx_bit_count=x"7") else
				"D7   "	when (start_rx='1' and rx_bit_count=x"8") else
				"STOP "	when (start_rx='1' and rx_bit_count=x"9") else
				"IDLE ";
-- synthesis translate_on
end bhv;