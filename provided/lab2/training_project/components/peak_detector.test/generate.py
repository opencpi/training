#!/usr/bin/env python3
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

"""Generate idata for Peak Detector (binary data file).

Generate args:
- amount to generate (number of complex signed 16-bit samples)
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

def generate(argv):

    if len(argv) < 2:
        print("Exit: Enter number of input samples (int:1 to ?)")
        return
    elif len(argv) < 3:
        print("Exit: Enter an input filename")
        return

    filename = argv[2]
    num_samples = int(argv[1])

    #Create an input file with a single tone at 13 Hz; Fs=100 Hz
    Tone13 = 13
    Fs = 100
    Ts = 1.0/float(Fs)
    t = np.arange(0,num_samples*Ts,Ts,dtype=np.float)
    real = np.cos(Tone13*2*np.pi*t)
    imag = np.sin(Tone13*2*np.pi*t)
    out_data = np.array(np.zeros(num_samples), dtype=np.dtype((np.uint32, {'real_idx':(np.int16,0), 'imag_idx':(np.int16,2)})))

    #pick a gain at 95% max value - i.e. back off a little to avoid file
    #generation overflow. This results in complex amplitudes that swing between
    #+31k and -31k within an int16. We must use the same gain on both rails to
    #avoid I/Q spectral image
    gain = 32768*0.95 / max(abs(real))
    out_data['real_idx'] = np.int16(real * gain)
    out_data['imag_idx'] = np.int16(imag * gain)

    #Save data file
    f = open(filename, 'wb')
    for i in range(0,num_samples):
        f.write(out_data[i])
    f.close()

    print ("\tOutput filename: ", filename)
    print ("\tNumber of samples: ", num_samples)

def main():
    generate(sys.argv)

if __name__ == '__main__':
    main()
