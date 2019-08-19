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
AGC Complex: Validate output data for AGC Complex (binary data file).

Validate args:
- amount to validate (number of complex signed 16-bit samples)
- output target file
- input file generated during the previous generate step

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
import numpy as np
import sys

if len(sys.argv) < 2:
    print ("Exit: Need to know how many input samples")
    sys.exit(1)
elif len(sys.argv) < 3:
    print("Exit: Enter an output filename")
    sys.exit(1)
elif len(sys.argv) < 4:
    print("Exit: Enter an input filename")
    sys.exit(1)

num_samples = int(sys.argv[1])

dt_iq_pair = np.dtype((np.uint32, {'real_idx':(np.int16,0), 'imag_idx':(np.int16,2)}))

# Read all of input data file as complex int16
print ("Input file to validate: ", sys.argv[3])
ifilename = open(sys.argv[3], 'rb')
idata = np.fromfile(ifilename, dtype=dt_iq_pair, count=-1)
ifilename.close()

# Read all of output data file as complex int16
print ("Output file to validate: ", sys.argv[2])
ofilename = open(sys.argv[2], 'rb')
odata = np.fromfile(ofilename, dtype=dt_iq_pair, count=-1)
ofilename.close()

# TEST #1: odata is not all zeros
if all(odata == 0):
    print ("Values are all zero")
    sys.exit(1)

# TEST #2: odata is the expected amount
if len(odata) != num_samples:
    print ("Output file length is unexpected")
    print ("Length ofilename = ", len(odata), "while expected length is = ", num_samples)
    sys.exit(1)

# Create complex arrays for both input and outputd data
i_complex_data = np.array(np.zeros(num_samples), dtype=np.complex64)
o_complex_data = np.array(np.zeros(num_samples), dtype=np.complex64)

# For AV v1.2: Start at 1 to have an extra 'zero' word at the beginning to align with o_complex_data
# For AV post-v1.2: Start at 0, but VHDL must be modified to skip first output sample (SOM and not VALID)
for i in range(1,num_samples):
    i_complex_data[i] = complex(idata['real_idx'][i-1], idata['imag_idx'][i-1])

for i in range(0,num_samples):
    o_complex_data[i] = complex(odata['real_idx'][i], odata['imag_idx'][i])

print ("Real Input Avg  =  ", np.mean(i_complex_data.real))
print ("Imag Input Avg  =  ", np.mean(i_complex_data.imag))
print ("Real Output Avg =  ", np.mean(o_complex_data.real))
print ("Imag Output Avg =  ", np.mean(o_complex_data.imag))

# Perform the AGC function on the input data
Navg   = 16
maxint = pow(2,Navg-1)-1
Ref    = 0.3*maxint/np.sqrt(2)
Mu     = 1/(4*(maxint-Ref))

# initial values
det_buf = np.array(np.zeros(Navg), dtype=np.complex64)          # buffer to measure output signal
gain    = np.array(np.ones(num_samples), dtype=np.complex64)    # loop gain
err     = np.array(np.zeros(num_samples), dtype=np.complex64)   # loop error
ydet    = np.array(np.zeros(num_samples), dtype=np.complex64)   # output detected
y       = np.array(np.zeros(num_samples+1), dtype=np.complex64) # output

for i in range(Navg-1,num_samples): # lagging by Navg samples
    # detecting output level
    det_buf.real = y.real[i+1-Navg:i+1] # buffering
    det_buf.imag = y.imag[i+1-Navg:i+1] # buffering
    ydet.real[i] = sum(abs(det_buf.real))/Navg
    ydet.imag[i] = sum(abs(det_buf.imag))/Navg

    # compare to reference
    err.real[i] = Ref - ydet.real[i]
    err.imag[i] = Ref - ydet.imag[i]

    # correct the gain to VGA
    gain.real[i] = gain.real[i-1] + err.real[i]*Mu
    if abs(gain.real[i]) > maxint: # limit to max
        gain.real[i] = (gain.real[i]>=maxint)*maxint + (gain.real[i]< maxint)*(-maxint)
    gain.imag[i] = gain.imag[i-1] + err.imag[i]*Mu
    if abs(gain.imag[i]) > maxint: # limit to max
        gain.imag[i] = (gain.imag[i]>=maxint)*maxint + (gain.imag[i]< maxint)*(-maxint)

    # VGA, variable gain amplifier
    y.real[i+1] = np.rint(gain.real[i] * i_complex_data.real[i])
    y.imag[i+1] = np.rint(gain.imag[i] * i_complex_data.imag[i])

# compare python AGC (y) to UUT output (o_complex_data)
for i in range(Navg-1+384,int(num_samples/4)):
    if abs(y.real[i+1] - o_complex_data.real[i+2]) > 2:
        print ("Real", i, y.real[i+1], o_complex_data.real[i+2], y.real[i+1]-o_complex_data.real[i+2])
        sys.exit(1)
    '''
    if abs(y.imag[i+1] - o_complex_data.imag[i+2]) > 2:
        print ("Imag", i, y.imag[i+1], o_complex_data.imag[i+2], y.imag[i+1]-o_complex_data.imag[i+2])
        sys.exit(1)
    '''
for i in range(int(num_samples/4+896),int(num_samples/2)):
    if abs(y.real[i+1] - o_complex_data.real[i+2]) > 2:
        print ("Real", i, y.real[i+1], o_complex_data.real[i+2], y.real[i+1]-o_complex_data.real[i+2])
        sys.exit(1)
    '''
    if abs(y.imag[i+1] - o_complex_data.imag[i+2]) > 2:
        print ("Imag" + color.END, i, y.imag[i+1], o_complex_data.imag[i+2], y.imag[i+1]-o_complex_data.imag[i+2])
        sys.exit(1)
    '''
for i in range(int(num_samples/2+384),int(num_samples*3/4)):
    if abs(y.real[i+1] - o_complex_data.real[i+2]) > 2:
        print ("Real", i, y.real[i+1], o_complex_data.real[i+2], y.real[i+1]-o_complex_data.real[i+2])
        sys.exit(1)
    '''
    if abs(y.imag[i+1] - o_complex_data.imag[i+2]) > 2:
       print ("Imag", i, y.imag[i+1], o_complex_data.imag[i+2], y.imag[i+1]-o_complex_data.imag[i+2])
       sys.exit(1)
    '''
for i in range(int(num_samples*3/4+256),num_samples-2):
    if abs(y.real[i+1] - o_complex_data.real[i+2]) > 2:
        print ("Real", i, y.real[i+1], o_complex_data.real[i+2], y.real[i+1]-o_complex_data.real[i+2])
        sys.exit(1)
    '''
    if abs(y.imag[i+1] - o_complex_data.imag[i+2]) > 2:
        print ("Imag", i, y.imag[i+1], o_complex_data.imag[i+2], y.imag[i+1]-o_complex_data.imag[i+2])
        sys.exit(1)
    '''
