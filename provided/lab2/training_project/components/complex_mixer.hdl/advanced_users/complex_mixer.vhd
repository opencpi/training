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
      aclk : in std_logic;
      aclken : in std_logic;
      aresetn : in std_logic;
      s_axis_a_tvalid : in std_logic;
      s_axis_a_tdata : in std_logic_vector(31 downto 0);
      s_axis_b_tvalid : in std_logic;
      s_axis_b_tdata : in std_logic_vector(31 downto 0);
      m_axis_dout_tvalid : out std_logic;
      m_axis_dout_tdata : out std_logic_vector(79 downto 0)
    );
  end component;

  component dds_compiler
    port (
      aclk : in std_logic;
      aresetn : in std_logic;
      s_axis_phase_tvalid : in std_logic;
      s_axis_phase_tdata : in std_logic_vector(15 downto 0);
      m_axis_data_tvalid : out std_logic;
      m_axis_data_tdata : out std_logic_vector(31 downto 0)
    );
  end component;

  constant PIPELINE_DELAY_C : integer := 6;
  -- WSI Interface temporary signal
  signal enable             : std_logic;
  signal idata_vld          : std_logic;
  signal not_reset          : std_logic;
  signal transient_data_cnt : std_logic_vector(5 downto 0);
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
  -- Flush pipeline
  signal flush_msg_cnt      : integer range 0 to PIPELINE_DELAY_C;
  signal flush_som          : std_logic;
  signal flush_eom          : std_logic;
  signal flush_valid        : std_logic;
  -- Zero-Length-Message (ZLM) Event
  signal zlm_detected       : std_logic;
  signal zlm_take           : std_logic;

begin

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- 'GOLDEN' VHDL SECTION
  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- 'enable' circuit (when control state 'is_operating' and up/downstream Workers ready)
  -----------------------------------------------------------------------------
  enable <= ctl_in.is_operating and out_in.ready and in_in.ready;

  -----------------------------------------------------------------------------
  -- 'idata_vld' enable 'data' flow (when enabled and input valid)
  -----------------------------------------------------------------------------
  idata_vld <= enable and in_in.valid;

  not_reset <= not(ctl_in.reset);

  s_axis_a_tdata <= in_in.data(15 downto 0) & in_in.data(31 downto 16);

  -----------------------------------------------------------------------------
  -- Xilinx Vivado IP: Complex Multiplier instance
  -----------------------------------------------------------------------------
  -- Simple but INCLUDES transient data
  --complex_mult_ce <= idata_vld;

  -- EXCLUDES transient data
  complex_mult_ce <= idata_vld when (zlm_detected = '0') else flush_valid;

  inst_ComplexMult : component complex_multiplier
  PORT MAP (
    aclk               => ctl_in.clk,
    aclken             => idata_vld,
    aresetn            => not_reset,
    s_axis_a_tvalid    => complex_mult_ce,
    s_axis_a_tdata     => s_axis_a_tdata,
    s_axis_b_tvalid    => complex_mult_ce,
    s_axis_b_tdata     => sinecosine,
    m_axis_dout_tvalid => open,
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

  -- Simple but INCLUDES transient data
  -- 'Prime' the DDS core, then enable via input port data valid
  --dds_ce <= '1' when (dds_primer_cnt >= x"1" and dds_primer_cnt <= x"7") else idata_vld;

  -- EXCLUDES transient data and performs flush of pipeline
  -- 'Prime' the DDS core, then enable via input port data valid and the flushing circuit
  dds_ce <= '1' when (dds_primer_cnt >= x"1" and dds_primer_cnt <= x"7")
            else idata_vld when (zlm_detected = '0')
            else flush_valid;

  -- Design note:
  -- The 'aresetn' is included, as it was determined that the primitive
  -- contained 'stale' data after an application execution
  inst_DDS : component dds_compiler
  PORT MAP (
    aclk                => ctl_in.clk,
    aresetn             => not_reset,
    s_axis_phase_tvalid => dds_ce,
    s_axis_phase_tdata  => std_logic_vector(props_in.phs_inc),
    m_axis_data_tvalid  => open,
    m_axis_data_tdata   => sinecosine
  );

  -- Temporary signals for BYPASS MODE (NCO data)
  sine   <= sinecosine(31 downto 16);
  cosine <= sinecosine(15 downto 0);

  -----------------------------------------------------------------------------
  -- WSI Port assignments
  -----------------------------------------------------------------------------
  -- Simpliest Messaging (pass-thru)
  --in_out.take   <= enable;
  --out_out.give  <= enable;
  --out_out.som   <= in_in.som;
  --out_out.eom   <= in_in.eom;
  --out_out.valid <= in_in.valid;
  --out_out.byte_enable <= in_in.byte_enable;

  -- (WORKS FOR v1.2)
  -- Messaging which INCLUDES the transient data and flushes the pipeline
  in_out.take   <= (enable and not zlm_detected) or zlm_take;
  out_out.give  <= (enable and not zlm_detected) or flush_valid or zlm_take;
  out_out.som   <= (in_in.som and not zlm_detected) or flush_som or zlm_take;
  out_out.eom   <= (in_in.eom and not zlm_detected) or flush_eom or zlm_take;
  out_out.valid <= (in_in.valid and not zlm_detected) or (flush_valid and not zlm_take);
  out_out.byte_enable <= in_in.byte_enable when (zlm_detected = '0') else (others => '1');

  -- (WORKS FOR Post-v1.2)
  -- Messaging which EXCLUDES the transient data, but flushes the pipeline
  --in_out.take   <= (enable and not zlm_detected) or zlm_take;
  --out_out.give  <= (enable and (not transient_data_cnt(0) or transient_data_cnt(5)) and not zlm_detected)
  --                    or flush_valid or zlm_take;
  --out_out.som   <= (in_in.som and not zlm_detected) or flush_som or zlm_take;
  --out_out.eom   <= (in_in.eom and not zlm_detected) or flush_eom or zlm_take;
  --out_out.valid <= (in_in.valid and transient_data_cnt(5) and not zlm_detected) or (flush_valid and not zlm_take);
  --out_out.byte_enable <= in_in.byte_enable when (zlm_detected = '0') else (others => '1');

  -- NORMAL mode
  -- BYPASS mode: Input data
  -- BYPASS mode: NCO data
  out_out.data <= pr(32 downto 17) & pi(32 downto 17) when (props_in.enable = '1')
                  else in_in.data when (props_in.data_select = '0')
                  else cosine & sine;

  -----------------------------------------------------------------------------
  -- Tikker for excluding the transient output data of the complex_multiplier
  -----------------------------------------------------------------------------
  proc_transient_cnt : process(ctl_in.clk)
  begin
    if rising_edge(ctl_in.clk) then
      if (ctl_in.reset = '1') then
        transient_data_cnt <= (others => '0');
      elsif (idata_vld = '1') then
         transient_data_cnt <= transient_data_cnt(4 downto 0) & '1';
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------
  -- Manage ZLM Event and Flushing of the pipeline
  -----------------------------------------------------------------------------
  -----------------------------------------------------------------------------

  -- Detect presence of ZLM, but do not 'take' immediately
  zlm_detected <= ctl_in.is_operating and out_in.ready and in_in.ready and in_in.som and in_in.eom and (not in_in.valid);

  -----------------------------------------------------------------------------
  -- Tikker for 'flushing' data within the pipeline delay of complex_multiplier
  -- (Defines the length of the last data message)
  -----------------------------------------------------------------------------
  proc_flush_msg_cnt : process(ctl_in.clk)
  begin
    if rising_edge(ctl_in.clk) then
      if (ctl_in.reset = '1') then
        flush_msg_cnt <= 0;
      elsif (zlm_detected = '1' and flush_msg_cnt /= PIPELINE_DELAY_C) then
        flush_msg_cnt <= flush_msg_cnt + 1;
      end if;
    end if;
  end process;

  flush_som <= '1'   when zlm_detected = '1' and flush_msg_cnt = 0 else '0';
  flush_eom <= '1'   when zlm_detected = '1' and flush_msg_cnt = PIPELINE_DELAY_C-1 else '0';
  flush_valid <= '1' when zlm_detected = '1' and flush_msg_cnt <= PIPELINE_DELAY_C-1 else '0';

  -----------------------------------------------------------------------------
  -- Delay the 'take' of the ZLM, to allow all of the input data to be processed
  -- and flushing of the pipeline
  -----------------------------------------------------------------------------
  zlm_take <= '1'    when zlm_detected = '1' and flush_msg_cnt = PIPELINE_DELAY_C else '0';

end rtl;
