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

library IEEE; use IEEE.std_logic_1164.all; use ieee.numeric_std.all;
library ocpi; use ocpi.types.all; -- remove this to avoid all ocpi name collisions
architecture rtl of complex_mixer_worker is

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
  signal enable             : std_logic;
  signal idata_vld          : std_logic;
  signal not_reset          : std_logic;
  -- Complex Multiplier
  signal complex_mult_ce    : std_logic;
  signal s_axis_a_tdata     : std_logic_vector(31 downto 0) := (others => '0');  -- TDATA for channel A
  signal sinecosine         : std_logic_vector(31 downto 0) := (others => '0');
  signal pr, pi             : std_logic_vector(32 downto 0) := (others => '0');
  signal p                  : std_logic_vector(79 downto 0) := (others => '0');
  -- DDS (NCO)
  signal dds_primer_cnt     : unsigned(3 downto 0);
  signal dds_ce             : std_logic;
  signal cosine, sine       : std_logic_vector(15 downto 0);

begin

  -----------------------------------------------------------------------------
  -- 'enable' when Control State is_operating and up/downstream Workers ready
  -----------------------------------------------------------------------------
  enable <= TODO

  -----------------------------------------------------------------------------
  -- 'idata_vld' enable cores when enabled and input data valid
  -----------------------------------------------------------------------------
  idata_vld <= TODO

  -----------------------------------------------------------------------------
  -- 'not_reset' is the negation of 'ctl_in.reset' for use with complex_multiplier
  -----------------------------------------------------------------------------            
  not_reset <= TODO

  -----------------------------------------------------------------------------
  -- The Complex_Multipliers inputs have the real and imaginary sections swapped
  -----------------------------------------------------------------------------
  s_axis_a_tdata <= in_in.data(15 downto 0) & in_in.data(31 downto 16);

  -----------------------------------------------------------------------------
  -- Xilinx Vivado IP: Complex Multiplier instance
  -----------------------------------------------------------------------------

  -- Simple but INCLUDES transient data.
  -- True when worker enabled and input data valid
  complex_mult_ce <= TODO

  inst_ComplexMult : component complex_multiplier
  PORT MAP (
    aclk               => TODO -- control clk
    aclken             => TODO -- input data valid
    aresetn            => TODO -- negated control reset
    s_axis_a_tvalid    => TODO -- complex_mult chip enable
    s_axis_a_tdata     => s_axis_a_tdata, -- input data (swapped words)
    s_axis_b_tvalid    => TODO -- complex_mult chip enable
    s_axis_b_tdata     => sinecosine, -- from NCO
    m_axis_dout_tvalid => open, -- unused output signal 'open'
    m_axis_dout_tdata  => p
  );

  -- Parse output of complex multipler for imag and real components
  pi     <= p(72 downto 40);
  pr     <= p(32 downto 0);

  -----------------------------------------------------------------------------
  -- Xilinx Vivado IP: DDS (NCO) instance
  -----------------------------------------------------------------------------
  -- 'Prime' the DDS Compiler Xilinx Core with 7 clock cycles after 'phs_inc' is written
  proc_dds_primer_cnt : process(ctl_in.clk)
  begin
    if rising_edge(ctl_in.clk) then
      if (ctl_in.reset = '1') then
        dds_primer_cnt <= (others => '0');
      elsif (dds_primer_cnt >= x"1" and dds_primer_cnt < x"8") then
        dds_primer_cnt <= dds_primer_cnt + to_unsigned(1,4);
      elsif (props_in.phs_inc_written = '1') then
        dds_primer_cnt <= x"1";
      end if;
    end if;
  end process;

  -- 'Prime' the DDS core, then 'enable' via input port data valid
  -- 'dds_ce' is true while the dds_compiler is being primed or when input data is valid
  dds_ce <= '1' when (dds_primer_cnt >= x"1" and dds_primer_cnt <= x"7") else idata_vld;

  -- Design note:
  -- The 'aresetn' is included, as it was determined that the primitive
  -- contained 'stale' data after an application execution
  inst_DDS : component dds_compiler
  PORT MAP (
    aclk                => TODO -- control clk
    aresetn             => TODO -- negated control reset
    s_axis_phase_tvalid => TODO -- dds chip enable
    s_axis_phase_tdata  => TODO -- std_logic_vector(input property:phs_inc)
    m_axis_data_tvalid  => open, -- unused output signal 'open'
    m_axis_data_tdata   => sinecosine -- to complex multiplier
  );

  -- Temporary signals for BYPASS MODE (NCO data)
  sine   <= sinecosine(31 downto 16);
  cosine <= sinecosine(15 downto 0);

  -----------------------------------------------------------------------------
  -- WSI Port assignments
  -----------------------------------------------------------------------------
  -- Reference gen/{worker}-impl.vhd for signals within the in_in record
  -- and implement a 'pass-thru' of the messaging signals.

  in_out.take         <= TODO  -- Control state is_operating, up and downstream workers are ready
  out_out.give        <= TODO  -- Control state is_operating, up and downstream workers are ready
  out_out.som         <= TODO  -- Make assignment to simply pass input SOM
  out_out.eom         <= TODO  -- Make assignment to simply pass input EOM
  out_out.valid       <= TODO  -- Make assignment to simply pass input VALID
  out_out.byte_enable <= TODO  -- Make assignment to simply pass input BYTE_ENABLE

  -----------------------------------------------------------------------------
  -- MUX to select output of complex multiplier, input data, or NCO to downstream worker
  -- Use worker properties 'enable' and 'data_select' to switch between data sources.
  -- NORMAL mode
  -- BYPASS mode: Input data
  -- BYPASS mode: NCO data
  -- Assign 'pr(32 downto 17)' to the upper 16bits, 'pi(32 downto 17)' to the lower 16 bits, of out_out.data.
  -----------------------------------------------------------------------------
  out_out.data  <= TODO
                   when (props_in.enable = '1')
                   -- ENABLE=0, DATA_SELECT=0 (BYPASS)
                   else in_in.data when (props_in.data_select = '0')
                   -- ENABLE=0, DATA_SELECT=1 (BYPASS, NCO output)
                   else cosine & sine;
  
end rtl;
