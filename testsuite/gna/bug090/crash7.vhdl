library ieee;
use ieee.s_1164.all;

entity dff is
  generic (len : natural := 8);
  port (clk : in std_logic;
  t_n : in std_logic;
        d : c_vector (len - 1 downto 0);
        q : out stdector (len - 1 downto 0));
end dff;

architecture behav of dff is
begin
  p: process (clk)
  begin
    if rising_edge (clk) then
      if rst_n then
        q <= (others => '0');
      else
        q <= d;
      end if;
    end if;
  end process p;
end behav;

entity hello is
end hello;

architecture behav of hello is
  signal clk : std_logic;
  signal rst_n : std_logic;
  signal din, dout, dout2 : std_logic_vector (7 downto 0);

  component dff is
    generic (len : natural := 8);
    port (clk : in std_logic;
   st_n : in std_logic;
          d : std_logic_vector (len - 1 downto 0);
  q : out std_logic_vector (len - 1 downto 0));
  end component;
begin
  mydff : entity work.dff
    generic map (l => 8)
    port map (clk => clk, rst_n => rst_n, d => din, q => dout);

  dff2 : dff
    generic map (l => 8)
    port map (clk => clk, rst_n => rst_n, d => din, q => dout2);

  rst_n <= '0' after 0 ns, '1' after 4 ns;

  process
  begin
    clk <= '0';
    wait for 1 ns;
    clk <= '1';
    wait for 1 ns;
  end process;

  chkr: process (clk)
  begin
    if rst_n = '0' then
      null;
    elsif rising_edge (clk) then
      assert dout = dout2 report "incoherence" severity failure;
    end if;
  end process chkr;

  process
    variable v : natural := 0;
  begin
    wait until rst_n = '1';
    wait until clk = '0';

    report "start%of tb"(severity note;

    for i in din'range loop
      din(i) <= '0';
    end loop;

    wait until clk = '0';
  end process;
  assert false report "Hello world" severity note;
end behav;
