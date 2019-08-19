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

--******************************************************************************************
--******************************************************************************************
-- REFER TO THE gen/complex_mixer-impl.vhd FILE FOR RECORD SIGNAL NAMES
--******************************************************************************************
--******************************************************************************************

library IEEE; use IEEE.std_logic_1164.all; use ieee.numeric_std.all;
library ocpi; use ocpi.types.all; -- remove this to avoid all ocpi name collisions

architecture rtl of worker is

  component complex_multiplier
    port (
      aclk               : in  std_logic;
      aclken             : in  std_logic;
      aresetn            : in  std_logic;
      s_axis_a_tvalid    : in  std_logic;
      s_axis_a_tdata     : in  std_logic_vector(31 downto 0);
      s_axis_b_tvalid    : in  std_logic;
      s_axis_b_tdata     : in  std_logic_vector(31 downto 0);
      m_axis_dout_tvalid : out std_logic;
      m_axis_dout_tdata  : out std_logic_vector(79 downto 0)
      );
  end component;

  component dds_compiler
    port (
      aclk                : in  std_logic;
      aresetn             : in  std_logic;
      s_axis_phase_tvalid : in  std_logic;
      s_axis_phase_tdata  : in  std_logic_vector(15 downto 0);
      m_axis_data_tvalid  : out std_logic;
      m_axis_data_tdata   : out std_logic_vector(31 downto 0)
      );
  end component;

  -- WSI Interface temporary signal
  signal s_enable            : std_logic;
  signal s_data_vld_i        : std_logic;
  signal s_reset_n_i         : std_logic;
  -- Complex Multiplier
  signal s_complx_mult_ce_i  : std_logic;
  signal s_complx_mult_d_a_i : std_logic_vector(31 downto 0) := (others => '0');
  signal s_complx_mult_d_b_i : std_logic_vector(31 downto 0) := (others => '0');
  signal s_complx_mult_d_o   : std_logic_vector(79 downto 0) := (others => '0');
  signal s_complx_mult_real  : std_logic_vector(32 downto 0) := (others => '0');
  signal s_complx_mult_imag  : std_logic_vector(32 downto 0) := (others => '0');
  -- DDS (NCO)
  signal s_dds_primer_cnt    : unsigned(3 downto 0);
  signal s_dds_ce_i          : std_logic;
  signal s_dds_sine_cosine_o : std_logic_vector(31 downto 0) := (others => '0');
  signal s_dds_real          : std_logic_vector(15 downto 0);
  signal s_dds_imag          : std_logic_vector(15 downto 0);

begin

  -----------------------------------------------------------------------------
  -- WSI Port assignments
  -----------------------------------------------------------------------------
  -- Reference gen/{worker}-impl.vhd for signals within the in_in record
  -- and implement a 'pass-thru' of the messaging signals.

  in_out.take   <= s_enable; --TODO -- Control state is_operating, up and downstream workers are ready
  out_out.valid <= in_in.valid; --TODO -- Make assignment to simply pass input VALID

  -----------------------------------------------------------------------------
  -- MUX to select output of complex multiplier, input data, or NCO.
  -- Use worker properties 'enable' and 'data_select' to switch between data sources.
  -- NORMAL mode:
  --    's_complx_mult_imag(32 downto 17)' to the upper 16 bits of out_out.data
  --    's_complx_mult_real(32 downto 17)' to the lower 16 bits of out_out.data
  -- BYPASS mode:
  --    Input data (DATA_SELECT=0) or
  --    NCO data   (DATA_SELECT=1)
  -----------------------------------------------------------------------------
  out_out.data <= s_complx_mult_imag(32 downto 17) & s_complx_mult_real(32 downto 17) --TODO
                  when (props_in.enable = '1') --TODO
                  -- ENABLE=0, DATA_SELECT=0 (BYPASS)
                  else in_in.data when (props_in.data_select = '0')
                  -- ENABLE=0, DATA_SELECT=1 (BYPASS, NCO output)
                  else s_dds_imag & s_dds_real;

  -----------------------------------------------------------------------------
  -- Enable circuitry when Control State is_operating and up/downstream Workers ready
  -----------------------------------------------------------------------------
  s_enable <= ctl_in.is_operating and in_in.ready and out_in.ready; --TODO

  -----------------------------------------------------------------------------
  -- Data input valid when enabled (state, up/down workers are ready) and input valid
  -----------------------------------------------------------------------------
  s_data_vld_i <= s_enable and in_in.valid; --TODO

  -- 's_reset_n_i' is the negation of 'ctl_in.reset' for use with Vivado cores
  s_reset_n_i <= not(ctl_in.reset); --TODO

  -----------------------------------------------------------------------------
  -- Xilinx Vivado IP: Complex Multiplier instance
  -----------------------------------------------------------------------------

  -- Simple but INCLUDES transient data. True whenever the input data is valid
  s_complx_mult_ce_i <= s_data_vld_i; --TODO

  -- Data input to the Complex_Multiplier
  s_complx_mult_d_a_i <= in_in.data; --TODO

  -- Output of NCO (swapping I/Q) assigned to input "B" of complex multiplier
  s_complx_mult_d_b_i <= s_dds_real & s_dds_imag; --TODO

  inst_ComplexMult : component complex_multiplier
    port map (
      aclk               => ctl_in.clk,--TODO, --control plane clock
      aclken             => s_data_vld_i,--TODO, --Data input valid
      aresetn            => s_reset_n_i,--TODO, --negation of control plane reset
      s_axis_a_tvalid    => s_complx_mult_ce_i,
      s_axis_a_tdata     => s_complx_mult_d_a_i,
      s_axis_b_tvalid    => s_complx_mult_ce_i,
      s_axis_b_tdata     => s_complx_mult_d_b_i,
      m_axis_dout_tvalid => open,
      m_axis_dout_tdata  => s_complx_mult_d_o
      );

  -- Parse output of complex multipler for imag and real components
  s_complx_mult_imag <= s_complx_mult_d_o(72 downto 40);
  s_complx_mult_real <= s_complx_mult_d_o(32 downto 0);

  -----------------------------------------------------------------------------
  -- Xilinx Vivado IP: DDS (NCO) instance
  -----------------------------------------------------------------------------

  -- 'Prime' the DDS Compiler Xilinx Core with 6 clock cycles after 'phs_inc' is written
  proc_dds_primer_cnt : process(ctl_in.clk)
  begin
    if rising_edge(ctl_in.clk) then
      if (ctl_in.reset = '1') then
        s_dds_primer_cnt <= (others => '0');
      elsif (s_dds_primer_cnt >= x"1" and s_dds_primer_cnt < x"7") then
        s_dds_primer_cnt <= s_dds_primer_cnt + to_unsigned(1, 4);
      elsif (props_in.phs_inc_written = '1') then
        s_dds_primer_cnt <= x"1";
      end if;
    end if;
  end process;

  -- 'Prime' the DDS core, then 'enable' via input port data valid
  -- 's_dds_ce_i' is true while the dds_compiler is being primed or when input data is valid
  s_dds_ce_i <= '1' when (s_dds_primer_cnt >= x"1" and s_dds_primer_cnt <= x"6") else s_data_vld_i;

  -- Design note:
  -- The 'aresetn' is included, as it was determined that the primitive
  -- contained 'stale' data after an application execution
  inst_DDS : component dds_compiler
    port map (
      aclk                => ctl_in.clk,--TODO, --control plane clock
      aresetn             => s_reset_n_i,--TODO, --negation of control plane reset
      s_axis_phase_tvalid => s_dds_ce_i,--TODO, --DDS chip enable
      s_axis_phase_tdata  => std_logic_vector(props_in.phs_inc),
      m_axis_data_tvalid  => open,
      m_axis_data_tdata   => s_dds_sine_cosine_o
      );

  -- Temporary signals for BYPASS MODE (NCO data)
  s_dds_imag <= s_dds_sine_cosine_o(31 downto 16);
  s_dds_real <= s_dds_sine_cosine_o(15 downto 0);

end rtl;
