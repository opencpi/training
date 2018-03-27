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
component AGC
  generic (
    DATA_WIDTH : integer := 16;
    NAVG       : integer := 16);
  port (
    CLK     : in  std_logic;
    RST     : in  std_logic;
    REG_WR  : in  std_logic;
    REF     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    MU      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    DIN_VLD : in  std_logic;
    HOLD    : in  std_logic;
    DIN     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    DOUT    : out std_logic_vector(DATA_WIDTH-1 downto 0));
end component AGC;
end package prims;
