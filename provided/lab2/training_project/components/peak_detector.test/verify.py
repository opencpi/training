#!/usr/bin/env python2
# This file is protected by Copyright. Please refer to the COPYRIGHT file
# distributed with this source distribution.
#
# This file is part of OpenCPI <http://www.opencpi.org>
#
# OpenCPI is free software: you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# OpenCPI is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

"""Validate odata for Peak Detector (binary data file).

Validate args:
- amount to validate (number of complex signed 16-bit samples)
- target file

To test the Peak Detector, a binary data file is generated containing complex
signed 16-bit samples with a tone at 13 Hz. The input data is passed through
the worker, so the output file should be identical to the input file. The
worker measures the minimum and maximum amplitudes found within the complex
data stream. These values, reported as properties, are compared with min/max
calculations performed within the script.

"""
import struct
import shutil
import numpy as np
import sys
import os.path
import os
import re

def validation(argv):

    if len(argv) < 2:
        print ("Exit: Need to know how many samples")
        return
    elif len(argv) < 3:
        print ("Exit: Enter an output filename")
        return

    num_samples = int(argv[1])

    # strip off output extension and replace with 'log' ('.out.out'=>'.log')
    logname = os.path.splitext(argv[2])[0]
    logname = os.path.splitext(logname)[0] + ".log"
    if not os.path.isfile(logname):
        logname = os.path.splitext(logname)[0] + ".remote_log"
    # Parse the logfile for the final values of max/min peaks
    # Normally, we would access these via environment variables:
    #   OCPI_TEST_max_peak, OCPI_TEST_min_peak
    # Due to an inconsistency in the unit test framework, the final values of
    #   these properties are captured correctly in the environment variables
    #   for RCC workers, but not HDL.
    with open(logname, 'rb') as log:
        for line in log:
            max_obj = re.search("Property \d+: peak_detector.max_peak = \"(-?\d+)\".*", line)
            if max_obj: #max_obj[1]:
                max_peak = int(max_obj.group(1))
            min_obj = re.search("Property \d+: peak_detector.min_peak = \"(-?\d+)\".*", line)
            if min_obj: #[1]:
                min_peak = int(min_obj.group(1))

    if not min_peak or not max_peak:
        print("Exit: log file does not contain max/min peak final values")
        return
    #Read all of input data file as complex int16
    print ("File to validate: ", argv[2])

    ofile = open(argv[2], 'rb')
    dout = np.fromfile(ofile, dtype=np.dtype((np.uint32, {'real_idx':(np.int16,0), 'imag_idx':(np.int16,2)})), count=-1)
    ofile.close()

    # TEST #1: odata is not all zeros
    if all(dout == 0):
        print ("Values are all zero")
        sys.exit(1)

    # TEST #2: odata is the expected amount
    if len(dout) != num_samples:
        print ("Input file length is unexpected")
        print ("Length dout = ", len(dout), "while expected length is = ", num_samples)
        sys.exit(1)

   # Calculate the maximum in python for verification
    pymin = min(min(dout['real_idx']), min(dout['imag_idx']))
    pymax = max(max(dout['real_idx']), max(dout['imag_idx']))

    print ("uut_min_peak = ", min_peak)
    print ("uut_max_peak = ", max_peak)
    print ("file_min_peak = ", pymin)
    print ("file_max_peak = ", pymax)

    if (min_peak != pymin) or (max_peak != pymax):
        print ("min/max values do not match")
        sys.exit(1)

def main():
    validation(sys.argv)

if __name__ == '__main__':
    main()
