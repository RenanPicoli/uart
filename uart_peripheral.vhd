library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.my_types.all;--array32, boundaries

entity uart_peripheral is
    port (
        clk: in std_logic;
        rst: in std_logic;
		ADDR: in std_logic_vector(0 downto 0);--address offset of registers relative to peripheral base address		
        wren: in std_logic;
        rden: in std_logic;
        D: in std_logic_vector(31 downto 0);-- only bits 7..0 used
        Q: out std_logic_vector(31 downto 0);--for register read, only bits 7..0 used
		IACK: in std_logic;--interrupt acknowledgement
		IRQ: out std_logic;--interrupt request
		---------PHY-----------
        rx: in std_logic;
        tx: out std_logic
    );
end uart_peripheral;

architecture Behavioral of uart_peripheral is
    -- Declaração do componente UART Core
    component uart_core
        port (
            rst: in std_logic;
            clk: in std_logic;
            D: in std_logic_vector(7 downto 0);
            wren: in std_logic;
            rden: in std_logic;
            Q: out std_logic_vector(7 downto 0);
            data_sent: out std_logic;
            data_received: buffer std_logic;
            stop_error: out std_logic;
            tx: out std_logic;
            rx: in std_logic
        );
    end component;
	
	component address_decoder_memory_map
	--N: word address width in bits
	--B boundaries: list of values of the form (starting address,final address) of all peripherals, written as integers,
	--list MUST BE "SORTED" (start address(i) < final address(i) < start address (i+1)),
	--values OF THE FORM: "(b1 b2..bN 0..0),(b1 b2..bN 1..1)"
	generic	(N: natural; B: boundaries);
	port(	ADDR: in std_logic_vector(N-1 downto 0);-- input, it is a word address
			RDEN: in std_logic;-- input
			WREN: in std_logic;-- input
			data_in: in array32;-- input: outputs of all peripheral
			ready_in: in std_logic_vector(B'length-1 downto 0);-- input: ready signals of all peripheral
			RDEN_OUT: out std_logic_vector;-- output
			WREN_OUT: out std_logic_vector;-- output
			ready_out: out std_logic;-- output
			data_out: out std_logic_vector(31 downto 0)-- data read
	);
    end component;
	
	-----------signals for memory map interfacing----------------
	constant ranges: boundaries := 	(--notation: base#value#
												(16#00#,16#00#),--DR
												(16#01#,16#01#) --SR
												);
	signal all_periphs_output: array32 (1 downto 0);
	signal all_periphs_rden: std_logic_vector(1 downto 0);
	signal all_periphs_wren: std_logic_vector(1 downto 0);
	
    -- Registradores para armazenar dados e status
    signal status_reg: std_logic_vector(31 downto 0); -- 0: data_sent, 1: data_received, 2: stop_error
	
	signal	uart_data_sent: std_logic;
	signal	uart_data_received: std_logic;
	signal	uart_stop_error: std_logic;
	
	signal	uart_wren: std_logic;
	signal	uart_rden: std_logic;
    signal	uart_data_out: std_logic_vector(7 downto 0);
    signal	uart_data_in: std_logic_vector(7 downto 0);
	
	signal status_wren:	std_logic;
	signal status_rden:	std_logic;

begin
    -- Instanciação do UART Core
    uart_inst: uart_core
        port map (
            rst => rst,
            clk => clk,
            D => uart_data_in,
            wren => uart_wren,
            rden => uart_rden,
            Q => uart_data_out,
            data_sent => uart_data_sent,
            data_received => uart_data_received,
            stop_error => uart_stop_error,
            tx => tx,
            rx => rx
        );
	uart_data_in <= D(7 downto 0);

    -- Registrador de Status
    process(clk, rst)
    begin
        if (rst = '1') then
            status_reg <= (others => '0');
        elsif (rising_edge(clk)) then
            status_reg(0) <= uart_data_sent;
            status_reg(1) <= uart_data_received;
            status_reg(2) <= uart_stop_error;
        end if;
    end process;
	
-------------------------- address decoder ---------------------------------------------------
	all_periphs_output	<= (1 => status_reg,	0 => (31 downto 8=>'0')&uart_data_out);

	status_rden			<= all_periphs_rden(1);
	uart_rden			<= all_periphs_rden(0);

	status_wren			<= all_periphs_wren(1);
	uart_wren			<= all_periphs_wren(0);
	
	memory_map: address_decoder_memory_map
	--N: word address width in bits
	--B boundaries: list of values of the form (starting address,final address) of all peripherals, written as integers,
	--list MUST BE "SORTED" (start address(i) < final address(i) < start address (i+1)),
	--values OF THE FORM: "(b1 b2..bN 0..0),(b1 b2..bN 1..1)"
	generic map (N => 1, B => ranges)
	port map (	ADDR => ADDR,-- input, it is a word address
			RDEN => RDEN,-- input
			WREN => WREN,-- input
			data_in => all_periphs_output,-- input: outputs of all peripheral
			ready_in => (others=>'1'),
			RDEN_OUT => all_periphs_rden,-- output
			WREN_OUT => all_periphs_wren,-- output
			data_out => Q-- data read
	);

	---------------IRQ--------------------------------
	---------new sample arrived-----------------------
	irq_0: process(CLK,IACK,RST)
	begin
		if(RST='1') then
			IRQ <= '0';
		elsif (IACK ='1') then
			IRQ <= '0';
		elsif rising_edge(CLK) then
			IRQ <= uart_data_sent or uart_data_received or uart_stop_error;
		end if;
	end process;	

end Behavioral;
