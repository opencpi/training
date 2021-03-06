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
-- Automatic Gain Control Complex
-------------------------------------------------------------------------------
--
-- Description:
--
-- The Automatic Gain Control (AGC) Complex worker inputs complex signed samples
-- and applies an AGC circuit independently on each I/Q input rail. The response
-- time of the AGC is programmable, as is the ability to update/hold the current
-- gain setting.
--
-- The REF property defines the desired output amplitude, while the MU property
-- defines the fixed feedback coefficient that is multiplied by the difference
-- in the feedback voltage and thus controls the response time of the circuit.
--
-- The circuit gain may be held constant by asserting the HOLD input. Build-time
-- parameters include the width of the data and the length of the averaging
-- window. The circuit has a latency of three DIN_VLD clock cycles.
-------------------------------------------------------------------------------

library IEEE; use IEEE.std_logic_1164.all; use ieee.numeric_std.all;
use ieee.math_real.all;
library ocpi; use ocpi.types.all; -- remove this to avoid all ocpi name collisions

architecture rtl of agc_complex_worker is

  constant DATA_WIDTH_c         : integer := to_integer(unsigned(DATA_WIDTH_p));
  constant AVG_WINDOW_c         : integer := to_integer(unsigned(AVG_WINDOW_p));
  constant MAX_MESSAGE_VALUES_c : integer := 4096;  -- from iqstream_protocol

  signal i_odata          : std_logic_vector(DATA_WIDTH_c-1 downto 0);
  signal q_odata          : std_logic_vector(DATA_WIDTH_c-1 downto 0);
  signal idata_vld        : std_logic;
  signal odata_vld        : std_logic;
  signal missed_odata_vld : std_logic := '0';
  signal reg_wr_en        : std_logic;
  signal msg_cnt          : unsigned(integer(ceil(log2(real(MAX_MESSAGE_VALUES_c))))-1 downto 0);
  signal max_sample_cnt   : unsigned(integer(ceil(log2(real(MAX_MESSAGE_VALUES_c))))-1 downto 0);
  signal enable           : std_logic;
  signal zlm              : std_logic;

begin

  -----------------------------------------------------------------------------
  -- 'enable' when Control State is_operating and up/downstream Workers ready
  -----------------------------------------------------------------------------
  enable <= ctl_in.is_operating and in_in.ready and out_in.ready;

  -----------------------------------------------------------------------------
  -- 'idata_vld' enable primitives when enabled and input valid
  -----------------------------------------------------------------------------
  idata_vld <= enable and in_in.valid;

  -----------------------------------------------------------------------------
  -- AGC Primitive Instantation
  -----------------------------------------------------------------------------
  reg_wr_en <= props_in.ref_written or props_in.mu_written;

  i_agc : prims.prims.agc
    generic map (
      DATA_WIDTH => DATA_WIDTH_c,
      NAVG       => AVG_WINDOW_c)
    port map (
      CLK     => ctl_in.clk,
      RST     => ctl_in.reset,
      REG_WR  => reg_wr_en,
      REF     => std_logic_vector(props_in.ref),
      MU      => std_logic_vector(props_in.mu),
      DIN_VLD => idata_vld,
      HOLD    => props_in.hold,
      DIN     => in_in.data(DATA_WIDTH_c-1+16 downto 16),
      DOUT    => i_odata);

  q_agc : prims.prims.agc
    generic map (
      DATA_WIDTH => DATA_WIDTH_c,
      NAVG       => AVG_WINDOW_c)
    port map (
      CLK     => ctl_in.clk,
      RST     => ctl_in.reset,
      REG_WR  => reg_wr_en,
      REF     => std_logic_vector(props_in.ref),
      MU      => std_logic_vector(props_in.mu),
      DIN_VLD => idata_vld,
      HOLD    => props_in.hold,
      DIN     => in_in.data(DATA_WIDTH_c-1 downto 0),
      DOUT    => q_odata);

  -----------------------------------------------------------------------------
  -- WSI Port assignments
  -----------------------------------------------------------------------------
  out_out.data <= std_logic_vector(resize(signed(i_odata),16)) &
                  std_logic_vector(resize(signed(q_odata),16));

  in_out.take   <= enable;

  out_out.give  <= ctl_in.is_operating and out_in.ready and in_in.ready;
  out_out.som   <= in_in.som;
  out_out.eom   <= in_in.eom;
  out_out.valid <= in_in.valid;
  out_out.byte_enable <= in_in.byte_enable;

end rtl;
