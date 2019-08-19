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
Complex Mixer: Verify Validate output data

Verify args:
1. sample frequency of output data file
2. number of samples used in validation
3. output data file used for validation
4. input data file used for comparison

To test the Complex Mixer, a binary data file is generated containing complex
signed 16-bit samples with a tone at a configurable center frequency and sample
frequency.
The Application XML sets the phase increment of the Mixer/NCO to output a 1 Hz tone,
sampled at 16 Hz. The output waveform's frequency is expected to +1 Hz greater than
the input waveform frequency. The validation of the test involves performing an FFT
of the output file to ensure the max tone is located at DC or 0 Hz.
"""
import struct
import numpy as np
import sys
import os.path

"""
Ex: python verify.py {sample-freq} {number_of_samples} {ofilename} {ifilename}
Validate:
TEST #1: Verify I & Q values are not all zeros
TEST #2: Output file matches expected size
TEST #3: Two possibilities: 1) NORMAL MODE - Target tone tuned to DC, 2) BYPASS MODE - idata = odata
"""

if len(sys.argv) != 5:
    print('Invalid arguments:  usage is: verify.py <sample-freq> <num-samples> <output-file> <input-file>')
    sys.exit(1)
dt_iq_pair = np.dtype((np.uint32, {'real_idx':(np.int16,0), 'imag_idx':(np.int16,2)}))
# Read all input data as complex int16
ifilename = open(sys.argv[4], 'rb')
idata = np.fromfile(ifilename, dtype=dt_iq_pair, count=-1)
ifilename.close()

# Read all output data as complex int16
ofilename = open(sys.argv[3], 'rb')
odata = np.fromfile(ofilename, dtype=dt_iq_pair, count=-1)
ofilename.close()

NUM_SAMPLES = int(sys.argv[2])
SAMPLE_RATE = float(sys.argv[1])
ENABLE = os.environ.get('OCPI_TEST_enable')
PHS_INC = float(os.environ.get('OCPI_TEST_phs_inc'))
DATA_SELECT = os.environ.get('OCPI_TEST_data_select')

# Test #1 - Check that output data is not all zeros
if all(odata == 0):
    print ('\tValues are all zero')
    sys.exit(1)

# Test #2 - Check that output data is the expected amount
# INCLUDES TRANSIENT and not FLUSHING of pipeline (USE THIS FOR v1.2)
if len(odata) != len(idata):
    print ('Output file length is unexpected')
    print ('Length = ', len(odata), 'while expected length is = ', len(idata))
    sys.exit(1)

# Test #3 - Check output data values
if(ENABLE == 'true'): # => NORMAL MODE
    complex_data = np.array(np.zeros(NUM_SAMPLES), dtype=np.complex)
    for i in range(0,NUM_SAMPLES):
        complex_data[i] = complex(odata['real_idx'][i], odata['imag_idx'][i])
    FFT = 1.0/NUM_SAMPLES * abs(np.fft.fft(complex_data,NUM_SAMPLES))
    Max_FFT_freq=np.argmax(FFT)*SAMPLE_RATE/NUM_SAMPLES
    if Max_FFT_freq != 0.0:
        print ('Fail: Max of FFT occurs at index: ',Max_FFT_freq, 'Hz (Should be 0)')
        sys.exit(1)
    print ('\tResults (Normal Mode): FFT occurs at expect index', Max_FFT_freq, 'Hz')

else: # => BYPASS MODE
    if (DATA_SELECT == 'false'):
        # INCLUDES TRANSIENT and not FLUSHING of pipeline (USE THIS FOR v1.2)
        if (idata != odata).all():
            print ('Fail - Bypass Mode: Input and output file do not match')
            sys.exit(1)
        print ("\tResults (Bypass Mode): Input and output file match")
"""
TODO: TEST IS ONLY VALID FOR HDL OUTPUT!
- NEED TO BLOCK WHEN VERIFYING RCC OUTPUT or NOT RUN CONFIGURATION AGAINST RCC.
    else:
        # Calculate NCO tone for mixing with input
        system_freq = SAMPLE_RATE
        phase_acc_width = 16 # Configuration of the Xilinx CORE Generator: DDS module
        nco_freq = ((system_freq * PHS_INC) / (2**phase_acc_width))
        #print '      NCO freq (calc) = ', nco_freq
        # Construct complex array of vectors for performing FFT
        # (PUT FFT INTO ITS OWN FUNCTION)
        data=np.zeros((len(odata)), dtype=complex)
        data.real = odata['real_idx']
        data.imag = odata['imag_idx']
        # Perform FFT
        w = np.fft.fft(data)
        freqs = np.fft.fftfreq(len(w))
        # Locate max Tone
        idx = np.argmax(np.abs(w))
        freq = freqs[idx]
        #print 'Measured freq \t= ', freq
        ofreq_hz = freq * system_freq
        #print '      NCO freq (measured) = ', ofreq_hz
        if (nco_freq != ofreq_hz):
            print 'Fail: Bypass Mode: NCO does not match expected freq: %.2f vs %.2f' % (nco_freq, ofreq_hz)
            sys.exit(1)
        else:
            print '      PASS - Bypass Mode: NCO output matches expected freq'
"""
