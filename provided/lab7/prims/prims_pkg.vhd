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

-- This package enables VHDL code to instantiate all entities and modules in this library
library ieee; use IEEE.std_logic_1164.all; use ieee.numeric_std.all;
package prims is

  component agc
    generic (
      g_data_width : integer := 16;
      g_navg       : integer := 16);
    port (
      i_clk   : in  std_logic;
      i_rst   : in  std_logic;
      i_write : in  std_logic;
      i_ref   : in  std_logic_vector(g_data_width-1 downto 0);
      i_mu    : in  std_logic_vector(g_data_width-1 downto 0);
      i_hold  : in  std_logic;
      i_valid : in  std_logic;
      i_data  : in  std_logic_vector(g_data_width-1 downto 0);
      o_data  : out std_logic_vector(g_data_width-1 downto 0));
  end component agc;

end package prims;
