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
-- REFER TO THE gen/peak_detector-impl.vhd FILE FOR RECORD SIGNAL NAMES
--******************************************************************************************
--******************************************************************************************

library IEEE; use IEEE.std_logic_1164.all; use ieee.numeric_std.all;
library ocpi; use ocpi.types.all; -- remove this to avoid all ocpi name collisions

architecture rtl of worker is

  -- INITIALIZE THE CONSTANT TO THE CORRECT VALUE
  -- Examine the OCS to determine the data type of the min/max_peak properties
  constant c_data_width : integer := 16;  --TODO;

  signal s_valid        : std_logic;
  signal s_i            : signed(c_data_width-1 downto 0);
  signal s_q            : signed(c_data_width-1 downto 0);
  signal s_min_peak_rst : std_logic;
  signal s_max_peak_rst : std_logic;
  signal s_min_peak_iq  : signed(c_data_width-1 downto 0);
  signal s_max_peak_iq  : signed(c_data_width-1 downto 0);
  signal s_min_peak     : signed(c_data_width-1 downto 0);
  signal s_max_peak     : signed(c_data_width-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Enable circuitry when input valid and output ready
  -----------------------------------------------------------------------------

  s_valid <= in_in.valid and out_in.ready;  --TODO;

  -----------------------------------------------------------------------------
  -- Control Port Interface (WCI Port assignments)
  -----------------------------------------------------------------------------

  -- Volatile Properties: i.e the Worker "updates" the property values
  props_out.min_peak <= s_min_peak;     --TODO;
  props_out.max_peak <= s_max_peak;     --TODO;

  -- Reset property values when control plane reset active or property is read
  s_min_peak_rst <= ctl_in.reset or props_in.min_peak_read;  --TODO;
  s_max_peak_rst <= ctl_in.reset or props_in.max_peak_read;  --TODO;

  -----------------------------------------------------------------------------
  -- Data Port Interface (WSI Port assignments)
  -----------------------------------------------------------------------------

  -- Per the datasheet: Lower 16 bits of input data = i, Upper 16 bits of input data = q
  -- Examination of the gen/{worker}-impl.vhd, shows in_in.data to be of type
  -- "std_logic_vector", but s_idata_* are "signed".
  -- Therefore, type casting is required here: signed(in_in.data(x downto x))
  s_i <= signed(in_in.data(15 downto 0));   --TODO;
  s_q <= signed(in_in.data(31 downto 16));  -- TODO;

  -- Reference gen/{worker}-impl.vhd for signals within the in_in record
  -- and implement a simple "pass-thru" of the messaging signals.
  in_out.take   <= s_valid;  --TODO;  -- When circuit is processing valid data
  out_out.valid <= s_valid;  --TODO;  -- When circuit is processing valid data
  out_out.data  <= in_in.data;  --TODO;  -- Simply pass input -> output

  -- PROVIDED : Capture Max/Min peak values
  peak_detect : process (ctl_in.clk)
  begin
    if rising_edge(ctl_in.clk) then
      if s_min_peak_rst = '1' then
        s_min_peak_iq(c_data_width-1)          <= ('0');
        s_min_peak_iq(c_data_width-2 downto 0) <= (others => '1');
        s_min_peak(c_data_width-1)             <= ('0');
        s_min_peak(c_data_width-2 downto 0)    <= (others => '1');
      elsif s_valid = '1' then
        if (s_i < s_q) then
          s_min_peak_iq <= s_i;
        else
          s_min_peak_iq <= s_q;
        end if;
        if (s_min_peak_iq < s_min_peak) then
          s_min_peak <= s_min_peak_iq;
        end if;
      end if;
      if s_max_peak_rst = '1' then
        s_max_peak_iq(c_data_width-1)          <= ('1');
        s_max_peak_iq(c_data_width-2 downto 0) <= (others => '0');
        s_max_peak(c_data_width-1)             <= ('1');
        s_max_peak(c_data_width-2 downto 0)    <= (others => '0');
      elsif s_valid = '1' then
        if (s_i < s_q) then
          s_max_peak_iq <= s_q;
        else
          s_max_peak_iq <= s_i;
        end if;
        if (s_max_peak_iq > s_max_peak) then
          s_max_peak <= s_max_peak_iq;
        end if;
      end if;
    end if;
  end process peak_detect;

end rtl;
