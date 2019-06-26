#!/usr/bin/python
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

"""
Timestamper: Generate test data & Validate output
"""
import struct
import shutil
import numpy as np
import sys
import os.path
import random

class color:
    PURPLE = '\033[95m'
    CYAN = '\033[96m'
    DARKCYAN = '\033[36m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

def validate(argv):
    if len(argv) < 2:
        print("Exit: Enter input filename")
        return

    #Open input file and grab samples as int32
    input_file = open(argv[1], 'rb')
    input_file_samples = np.fromfile(input_file, dtype=np.uint32, count=-1)
    input_file.close()

    #Ensure dout is not all zeros
    if all(input_file_samples == 0):
        print color.RED + color.BOLD + 'FAILED, values are all zero' + color.END
        return
    else:
        print 'Pass: File is not all zeros'

    #Print out timestamps
    timestamp_list = list();
    a = 0
    while a < len(input_file_samples):
        timestamp_list.append(input_file_samples[a]+1.0*(input_file_samples[a+1])/0xFFFFFFFF)
        if(len(timestamp_list)>1):
            print "Timestamp is:", "{:10.7f}".format(timestamp_list[-1]), " ( Seconds:", "{0:#x}".format(input_file_samples[a]), " Fraction:", "{0:#x}".format(input_file_samples[a+1]),") Delta:","{:10.7f}".format(timestamp_list[-1]-timestamp_list[-2]) 
        else:
            print "Timestamp is:", "{:10.7f}".format(timestamp_list[-1]), " ( Seconds:", "{0:#x}".format(input_file_samples[a]), " Fraction:", "{0:#x}".format(input_file_samples[a+1]),")"
        a += 2

    print '*** End ***'
    print "*"*80

def main():
    print "\n","*"*80
    print "*** Python: Prints Timestamps ***"
    validate(sys.argv)

if __name__ == '__main__':
    main()
