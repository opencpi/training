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

  signal s_enable   : std_logic;
  signal s_counter  : unsigned(15 downto 0) := (others => '0');
  -- finished becomes true when the counter reaches its "max" value
  signal s_finished : std_logic             := '0';

begin

  ctl_out.finished <= s_finished;

  s_enable <= std_logic(ctl_in.is_operating);

  count : process (ctl_in.clk)
  begin
    if rising_edge(ctl_in.clk) then
      -- Normal code - no debugging. Simple counter
      if (ctl_in.reset = '1') then
        s_counter  <= (others => '0');
        s_finished <= '0';
      elsif (s_enable = '1') then
        if (not s_finished) then
          if (s_counter < props_in.max) then
            s_counter <= s_counter + 2;
          else
            s_finished <= '1';
          end if;
        end if;
      end if;
    end if;
  end process count;

  -- output the counter value
  props_out.counter <= s_counter;

end rtl;
