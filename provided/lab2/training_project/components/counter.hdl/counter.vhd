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

-- THIS FILE WAS ORIGINALLY GENERATED ON Mon Nov 14 10:08:05 2016 EST
-- BASED ON THE FILE: counter.xml
-- YOU *ARE* EXPECTED TO EDIT IT
-- This file initially contains the architecture skeleton for worker: counter

library IEEE; use IEEE.std_logic_1164.all; use ieee.numeric_std.all;
library ocpi; use ocpi.types.all; -- remove this to avoid all ocpi name collisions
architecture rtl of counter_worker is
  signal enable          : std_logic;
  signal counter         : unsigned(15 downto 0) := (others => '0');
  -- finished becomes true when the counter reaches its "max" value 
  signal finished        : std_logic := '0';

begin

ctl_out.finished <= finished;

enable <= '1' when (its(ctl_in.is_operating)) else '0';  

count : process (ctl_in.clk)
begin

  if rising_edge(ctl_in.clk) then
-- Normal code - no debugging. Simple counter
    if ctl_in.reset = '1' then
      counter <= (others => '0');
      finished <= '0';
    elsif its(enable) then
      if (not finished) then
        if (counter < props_in.max) then
          counter <= counter + 2;
        else
          finished <= '1';
        end if;
      end if;
    end if;
  end if;
end process count;
-- output the counter value
props_out.counter <= counter;

end rtl;
