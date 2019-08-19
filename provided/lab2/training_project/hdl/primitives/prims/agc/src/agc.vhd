-- This file is protected by Copyright. Please refer to the COPYRIGHT file
-- distributed with this source distribution.
--
-- This file is part of OpenCPI <http://www.opencpi.org>
--
-- OpenCPI is free software: you can redistribute it and/or modify it under the
-- terms of the GNU Lesser General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option) any
-- later version.
--
-- OpenCPI is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
-- A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
-- details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program. If not, see <http://www.gnu.org/licenses/>.

-------------------------------------------------------------------------------
-- Automatic Gain Control
-------------------------------------------------------------------------------
--
-- File: agc.vhd
--
-- Description:
--
-- This is an implemenation of a simple automatic gain control (AGC) with fixed feedback
-- coefficient i_mu. Given an input signal with varying amplitude envelope, the AGC provides
-- a relatively constant amplitude output at the desired value i_ref.
--
-- The output signal is sampled and average over N samples, which is compared to a reference
-- level i_ref to measure the difference between the output and the desired value.
--   PeakDetector:
--                                  sN.15
--                            <------------------------<
--           s0.15            |                        |                s0.15
--   y(n) >----(abs)(R)------(+)-----(R)-------->(+)---(R)--(X)---(>>)(R)----> y_avg(n)
--                       |               sN.15    |-         |
--                       |                        |         1/N
--                       >-------(R[1:N+1])------>
--                         s0.15           s0.15
--
-- The gain is adjusted inversely proportional to the compared differences. The control
-- parameter i_mu is used to control AGC time constant which determines how fast the gain
-- changes take effect. The system latency is 3 clks via the main path or 9 clks via the
-- feedback path.
--   AGC:
--           s0.15          ss4.42                  s0.15          s0.15
--   x(n) >---(R)---(X)(R)----------------(>>)----------------------(R)----> y(n)
--                   |                                         |
--                   -------->         i_mu         i_ref      [PeakDet]
--                   |       |          |          |  _        |
--                   <---(R)(+)<----(R)(X)<----(R)(+)<----------
--                   s4.27     ss0.30     s0.15       s0.15
--
-- The following generic parameters define the AGC structure, these values must be set
-- before synthesis.
--   DATA_WIDTH : Width of the input and output data
--   NAVG       : Number of samples to average, can be same as sample freq
-- The following values control the AGC operation, these values are programmable thus can
-- be changed during operation.
--   i_ref : Desired output express in % of fullscale expected peak value in rms
--   i_mu  : Feedback coefficient, scale factor to the gain changes, express as mu*fullscale
--
-- This AGC implementation is a nonlinear, signal dependent feedback system. Users should
-- perform an empirical analysis using the Matlab model 'agc.m' to obtain the proper
-- parameters and control values.
--
-------------------------------------------------------------------------------
-- Revision Log:
-------------------------------------------------------------------------------
-- 02/22/16:
-- File Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity agc is
  generic (
    g_data_width : integer := 16;       -- data width
    g_navg       : integer := 16        -- number of samples to average
    );
  port (
    i_clk   : in  std_logic;
    i_rst   : in  std_logic;
    i_write : in  std_logic;            -- program control values
    i_ref   : in  std_logic_vector(g_data_width-1 downto 0);  -- desired output
    i_mu    : in  std_logic_vector(g_data_width-1 downto 0);  -- feedback error scale factor
    i_valid : in  std_logic;            -- indicates valid input data
    i_hold  : in  std_logic;            -- maintain the current gain
    i_data  : in  std_logic_vector(g_data_width-1 downto 0);
    o_data  : out std_logic_vector(g_data_width-1 downto 0)
    );
end agc;

architecture Structural of agc is

  constant c_vga_width  : integer := 3*g_data_width;  -- ss4.42 [ss4.3*(g_data_width-6)]
  constant c_pdet_width : integer := g_data_width;  -- s0.15  [s0.(g_data_width-1)]
  constant c_mu_width   : integer := g_data_width;  -- s0.15, precision of error scale factor
  constant c_gain_width : integer := c_pdet_width+c_mu_width;  -- s4.27 [s(c_gain_size).(g_data_width-5)]
  constant c_gain_size  : integer := 4;             -- range 0..15
  constant c_gain_unity : integer := 2**(g_data_width-(c_gain_size+1));  -- VGA gain=1 in s4.27

  -- variable gain amplifier
  signal s_agc_in  : signed(g_data_width-1 downto 0);
  signal s_vga_out : signed(c_vga_width-1 downto 0);
  signal s_agc_out : signed(g_data_width-1 downto 0);

  -- peak detector
  type t_det_dly is array(0 to g_navg) of signed(c_pdet_width-1 downto 0);
  signal s_loop_in            : signed(g_data_width-1 downto 0);
  signal s_pk_abs             : signed(c_pdet_width-1 downto 0);
  signal s_pk_acc             : signed(c_pdet_width+g_navg-1 downto 0);
  signal s_pk_sum, s_pk_sum_p : signed(c_pdet_width+g_navg-1 downto 0);
  signal s_delay              : t_det_dly := (others => (others => '0'));
  signal s_pk_avg_f           : signed(c_pdet_width+g_navg-1 downto 0);
  signal s_pk_avg             : signed(c_pdet_width-1 downto 0);

  -- gain calculation
  signal s_mu_coef    : signed(c_mu_width-1 downto 0);
  signal s_pk_ref     : signed(c_pdet_width-1 downto 0);
  signal s_err        : signed(c_pdet_width-1 downto 0);
  signal s_delta_gain : signed(c_pdet_width+c_mu_width-1 downto 0);
  signal s_gain       : signed(c_gain_width-1 downto 0);
  signal s_gain_d     : signed(c_gain_width-1 downto 0);

begin

  -- data registers
  data_regs : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_agc_in <= (others => '0');
        o_data   <= (others => '0');
      elsif (i_valid = '1') then
        s_agc_in <= signed(i_data);
        o_data   <= std_logic_vector(s_agc_out);
      end if;
    end if;
  end process;

  -- control registers
  ctrl_reg : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_pk_ref  <= (others => '0');
        s_mu_coef <= (others => '0');
      elsif (i_write = '1') then
        s_pk_ref  <= signed(i_ref);     -- s0.15
        s_mu_coef <= signed(i_mu);      -- s0.15
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- measuring the output, average over N at every cycle,

  -- abs(x) register
  s_loop_in <= s_agc_out;
  pdet_abs : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_pk_abs <= (others => '0');
      elsif (i_valid = '1') then
        s_pk_abs <= abs(s_loop_in);     -- s0.15
      end if;
    end if;
  end process;

  -- sum of abs(x)
  pdet_accum : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_pk_acc <= (others => '0');
      elsif (i_valid = '1') then
        s_pk_acc <= s_pk_abs + s_pk_sum;  -- s0.15+sN.15
      end if;
    end if;
  end process;

  -- peak detector N+1 s_delay line
  -- WARNING: Attempts to force this into a SRL, by removing the reset
  --          resulted in 'stale' data between executions.
  delay_line : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_delay <= (others => (others => '0'));
      elsif (i_valid = '1') then
        s_delay(0)           <= s_pk_abs;
        s_delay(1 to g_navg) <= s_delay(0 to g_navg-1);
      end if;
    end if;
  end process;

  -- remove the oldest sample
  s_pk_sum <= s_pk_acc - s_delay(g_navg);  -- sN.15-s0.15

  -- extra pipeline to reduce setup time
  psum_pipe : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_pk_sum_p <= (others => '0');
      elsif (i_valid = '1') then
        s_pk_sum_p <= s_pk_sum;
      end if;
    end if;
  end process;

  -- peak detector output register, divide by N then resize to s0.15
  s_pk_avg_f <= s_pk_sum_p / g_navg;
  pdet_out : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_pk_avg <= (others => '0');
      elsif (i_valid = '1') then        -- sign+15msb
        s_pk_avg <= s_pk_avg_f(c_pdet_width+g_navg-1) & s_pk_avg_f(c_pdet_width-2 downto 0);
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- computing loop gain, changes in gain are very small so precision must be maintained

  -- loop error, s_err < s_pk_ref or s_pk_avg
  looperr : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_err <= (others => '0');
      elsif (i_valid = '1') then
        s_err <= s_pk_ref - s_pk_avg;   -- s0.15-s0.15
      end if;
    end if;
  end process;

  -- calculate the delta gain, mu << 1 therefore s_delta_gain << s_err
  gaindelta : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_delta_gain <= (others => '0');
      elsif (i_valid = '1') then
        s_delta_gain <= s_err * s_mu_coef;  -- s0.15*s0.15=ss0.30,
      end if;
    end if;
  end process;

  -- new loop gain
  previous_gain : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_gain_d <= to_signed(c_gain_unity, c_gain_width);
      elsif (i_valid = '1') then
        s_gain_d <= s_gain;             -- s4.27
      end if;
    end if;
  end process;

  -- adaptive gain control
  gain_sel : process (s_delta_gain, s_gain_d, i_hold)
  begin
    if (i_hold = '1') then              -- maintain the gain value
      s_gain <= s_gain_d;
    else                                -- keep adjusting the gain
      s_gain <= s_gain_d + shift_right(s_delta_gain, (c_gain_size-1));  -- s4.27+sssss0.27=s4.27
    end if;
  end process;

  -------------------------------------------------------------------------------
  -- variable gain amplifier
  vga_mult : process (i_clk)
  begin
    if rising_edge(i_clk) then
      if (i_rst = '1') then
        s_vga_out <= (others => '0');
      elsif (i_valid = '1') then
        s_vga_out <= s_gain_d * s_agc_in;  -- s4.27*s0.15=ss4.42
      end if;
    end if;
  end process;

  -- scaling ss4.42 back to s0.15, ?? will it over/underflow ??
  -- sign-bit & msb's of fractional part
  s_agc_out(g_data_width-1) <= s_vga_out(c_vga_width-1);
  s_agc_out(g_data_width-2 downto 0) <= s_vga_out(c_vga_width-(c_gain_size+3)
                                                  downto c_vga_width-(c_gain_size+g_data_width+1));

end Structural;
