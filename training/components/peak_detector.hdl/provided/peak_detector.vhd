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

architecture rtl of peak_detector_worker is

  -- INITIALIZE THE CONSTANT TO THE CORRECT VALUE
  -- HINT: Examine the OCS to determine the data type of the min/max_peak properties
  constant DATA_WIDTH_c : integer := TODO;

  signal enable         : std_logic;
  signal idata_vld      : std_logic;
  signal min_peak_rst   : std_logic;
  signal max_peak_rst   : std_logic;
  signal i_idata        : signed(DATA_WIDTH_c-1 downto 0);
  signal q_idata        : signed(DATA_WIDTH_c-1 downto 0);
  signal iq_min_peak    : signed(DATA_WIDTH_c-1 downto 0);
  signal iq_max_peak    : signed(DATA_WIDTH_c-1 downto 0);
  signal min_peak       : signed(DATA_WIDTH_c-1 downto 0);
  signal max_peak       : signed(DATA_WIDTH_c-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- 'enable' when Control State is_operating and up/downstream Workers ready
  -----------------------------------------------------------------------------
  enable <= TODO

  -----------------------------------------------------------------------------
  -- 'idata_vld' enable primitives when enabled and input valid
  -----------------------------------------------------------------------------
  idata_vld <= TODO

  -- upper 16 bits of input data (note the signal declaration type: signed vs unsigned?)
  i_idata      <= TODO;
  -- lower 16 bits of input data (note the signal declaration type: signed vs unsigned?)
  q_idata      <= TODO;

  -- PROVIDED
  peak_detect : process (ctl_in.clk)
  begin
    if rising_edge(ctl_in.clk) then
      if min_peak_rst = '1' then
        iq_min_peak(DATA_WIDTH_c-1)          <= ('0');
        iq_min_peak(DATA_WIDTH_c-2 downto 0) <= (others => '1');
        min_peak(DATA_WIDTH_c-1)             <= ('0');
        min_peak(DATA_WIDTH_c-2 downto 0)    <= (others => '1');
      elsif idata_vld = '1' then
        if (i_idata < q_idata) then
          iq_min_peak <= i_idata;
        else
          iq_min_peak <= q_idata;
        end if;
        if (iq_min_peak < min_peak) then
          min_peak <= iq_min_peak;
        end if;
      end if;
      if max_peak_rst = '1' then
        iq_max_peak(DATA_WIDTH_c-1)          <= ('1');
        iq_max_peak(DATA_WIDTH_c-2 downto 0) <= (others => '0');
        max_peak(DATA_WIDTH_c-1)             <= ('1');
        max_peak(DATA_WIDTH_c-2 downto 0)    <= (others => '0');
      elsif idata_vld = '1' then
        if (i_idata < q_idata) then
          iq_max_peak <= q_idata;
        else
          iq_max_peak <= i_idata;
        end if;
        if (iq_max_peak > max_peak) then
          max_peak <= iq_max_peak;
        end if;
      end if;
    end if;
  end process peak_detect;

  -----------------------------------------------------------------------------
  -- WSI Port assignments
  -----------------------------------------------------------------------------
  -- Reference gen/{worker}-impl.vhd for signals within the in_in record
  -- and implement a 'pass-thru' of the messaging signals.

  in_out.take         <= TODO;  -- Control state is_operating, up and downstream workers are ready
  out_out.give        <= TODO;  -- Control state is_operating, up and downstream workers are ready
  out_out.som         <= TODO;  -- Make assignment to simply pass input SOM
  out_out.eom         <= TODO;  -- Make assignment to simply pass input EOM
  out_out.valid       <= TODO;  -- Make assignment to simply pass input VALID
  out_out.data        <= TODO;  -- Make assignment to simply pass input DATA
  out_out.byte_enable <= TODO;  -- Make assignment to simply pass input BYTE_ENABLE

  -----------------------------------------------------------------------------
  -- Reset property values when the property is read by control plane
  -----------------------------------------------------------------------------  
  min_peak_rst <= TODO;  -- control plane reset or property min_peak_read
  max_peak_rst <= TODO;  -- control plane reset or property max_peak_read

  -----------------------------------------------------------------------------
  -- Volatile Properties: i.e worker 'updates' the property values
  -----------------------------------------------------------------------------
  props_out.min_peak <= TODO;
  props_out.max_peak <= TODO;
  
end rtl;
