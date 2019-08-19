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

--*****************************************************************************
--*****************************************************************************
-- REFER TO THE gen/agc_complex-impl.vhd FILE FOR RECORD SIGNAL NAMES
--*****************************************************************************
--*****************************************************************************

library IEEE; use IEEE.std_logic_1164.all; use ieee.numeric_std.all;
use ieee.math_real.all;
library ocpi; use ocpi.types.all; -- remove this to avoid all ocpi name collisions

architecture rtl of worker is

  -- INITIALIZE THE CONSTANTS TO THE CORRECT VALUES
  -- HINT: Examine the OWD to determine the PARAMETERS
  constant c_data_width : integer := to_integer(data_width);  --to_integer(TODO);
  constant c_avg_window : integer := to_integer(avg_window);  --to_integer(TODO);

  signal s_valid : std_logic;
  signal s_i_o   : std_logic_vector(c_data_width-1 downto 0);
  signal s_q_o   : std_logic_vector(c_data_width-1 downto 0);
  signal s_write : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Enable circuitry when input valid and output ready
  -----------------------------------------------------------------------------

  s_valid <= in_in.valid and out_in.ready;  --TODO;

  -----------------------------------------------------------------------------
  -- Data Port Interface (WSI Port assignments)
  -----------------------------------------------------------------------------

  -- Reference gen/{worker}-impl.vhd for signals within the in_in record
  -- and implement a simple "pass-thru" of the messaging signals.
  in_out.take   <= s_valid;  --TODO;  -- When circuit is processing valid data
  out_out.valid <= s_valid;  --TODO;  -- When circuit is processing valid data

  out_out.data <= std_logic_vector(resize(signed(s_q_o), 16)) &
                  std_logic_vector(resize(signed(s_i_o), 16));

  -----------------------------------------------------------------------------
  -- AGC Primitive Instantation
  -----------------------------------------------------------------------------
  s_write <= props_in.ref_written or props_in.mu_written;

  i_agc : prims.prims.agc
    generic map (
      g_data_width => c_data_width,
      g_navg       => c_avg_window)
    port map (
      i_clk   => ctl_in.clk,  --TODO, -- control plane clock
      i_rst   => ctl_in.reset,  --TODO, -- control plane reset
      i_write => s_write,               --TODO,
      i_ref   => std_logic_vector(props_in.ref),  --TODO), -- REF property
      i_mu    => std_logic_vector(props_in.mu),  --TODO), -- MU property
      i_hold  => props_in.hold,  --TODO, -- HOLD property
      i_valid => s_valid,  --TODO, -- s_data_vld_i
      i_data  => in_in.data(c_data_width-1 downto 0),  -- TODO(c_data_width-1 downto 0)), -- input data
      o_data  => s_i_o);

  q_agc : prims.prims.agc
    generic map (
      g_data_width => c_data_width,
      g_navg       => c_avg_window)
    port map (
      i_clk   => ctl_in.clk,  --TODO, -- control plane clock
      i_rst   => ctl_in.reset,  --TODO, -- control plane reset
      i_write => s_write,               --TODO,
      i_ref   => std_logic_vector(props_in.ref),  --TODO), -- REF property
      i_mu    => std_logic_vector(props_in.mu),  --TODO), -- MU property
      i_hold  => props_in.hold,  --TODO, -- HOLD property
      i_valid => s_valid,  --TODO, -- s_data_vld_i
      i_data  => in_in.data(c_data_width-1+16 downto 16),  -- TODO(c_data_width-1+16 downto 16), -- input data
      o_data  => s_q_o);

end rtl;
