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

"""
AGC Complex: Generate test input data (binary data file).

Generate args:
- amount to generate (number of complex signed 16-bit samples)
- target file

To test the AGC Complex component, a binary data file is generated containing
complex signed 16-bit samples with a tone at Fs/16 where the first 1/4 of the
file is at 20% max amplitude, the second 1/4 of the file at 90% max amplitude,
the third 1/4 of the file at 20% max amplitude, and the last 1/4 of the file at
30% max amplitude. The output file is also a binary file containing complex
signed 16-bit samples where the amplitude has been smoothed by the AGC circuit
to the REF amplitude property setting and the tone is still present and of
sufficient power. The input file produced during the generate phase is also fed
to the validation phase where a python implementation of the agc is compared to
the UUT output.

"""
import struct
import numpy as np
import sys

if len(sys.argv) < 2:
    print("Exit: Enter number of input samples (int:1 to ?)")
    sys.exit(1)
elif len(sys.argv) < 3:
    print("Exit: Enter an input filename")
    sys.exit(1)

num_samples = int(sys.argv[1])
filename = sys.argv[2]

#Create an input file with a single tone at Fs/16
Fs = 16
Ts = 1.0/float(Fs)
t = np.arange(0,num_samples*Ts,Ts,dtype=np.float)
real = np.cos(2*np.pi*t)
imag = np.sin(2*np.pi*t)
out_data = np.array(np.zeros(num_samples), dtype=np.dtype((np.uint32, {'real_idx':(np.int16,0), 'imag_idx':(np.int16,2)})))

#must use same gain on both rails to avoid I/Q spectral image
gain_pt_2 = 32767*0.2 / max(abs(real))
gain_pt_3 = 32767*0.3 / max(abs(real))
gain_pt_9 = 32767*0.9 / max(abs(real))

for i in range(0,int(num_samples/4)):
    out_data['real_idx'][i] = np.rint(real[i] * gain_pt_2)
    out_data['imag_idx'][i] = np.rint(imag[i] * gain_pt_2)
for i in range(int(num_samples/4),int(num_samples/2)):
    out_data['real_idx'][i] = np.rint(real[i] * gain_pt_9)
    out_data['imag_idx'][i] = np.rint(imag[i] * gain_pt_9)
for i in range(int(num_samples/2),int(num_samples*3/4)):
    out_data['real_idx'][i] = np.rint(real[i] * gain_pt_2)
    out_data['imag_idx'][i] = np.rint(imag[i] * gain_pt_2)
for i in range(int(num_samples*3/4),int(num_samples)):
    out_data['real_idx'][i] = np.rint(real[i] * gain_pt_3)
    out_data['imag_idx'][i] = np.rint(imag[i] * gain_pt_3)

#Save data file
f = open(filename, 'wb')
for i in range(0,num_samples):
    f.write(out_data[i])
f.close()

print ("Output filename: ", filename)
print ("Number of samples: ", num_samples)
