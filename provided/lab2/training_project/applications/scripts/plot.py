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


import numpy as np
import matplotlib.pyplot as plt
import sys
import os.path
import itertools

def main():
    dataType = "real"
    numSamples = -1
    totalPlots = 0
    if len(sys.argv) < 2:
        print("NOPE! need a file to plot")
        return
    if len(sys.argv) <= 4:  #old version
        numSamples = -1
        if  len(sys.argv) >= 3:
            dataType = sys.argv[2].lower();
            if sys.argv[2] == "complex":
                totalPlots += 1
        if  len(sys.argv) == 4:
            numSamples = int(sys.argv[3])
        print sys.argv[1]
        plotList = zip(itertools.repeat(sys.argv[1],1),
                       itertools.repeat(dataType,1),
                       itertools.repeat(numSamples,1))
        totalPlots += 1
    elif ((len(sys.argv) -1) % 3) == 0:
        current = 1
        fnList = []
        dtList = []
        lenList = []
        while current < len(sys.argv):
            fnList.append (sys.argv[current])
            dtList.append (sys.argv[current + 1])
            lenList.append(sys.argv[current + 2])
            totalPlots += 1
            if sys.argv[current + 1] == "complex":
                totalPlots += 1
            current += 3
        plotList = zip(fnList, dtList, lenList)
    else :
        print("NOPE! Wrong number of arguments")
        return

    plotCount = 1
    fig = plt.figure(1)
    for f, dataType , numSamples in plotList:
        print "file is : " + f
        print "data is : " + dataType
        print "num samples is: " + str(numSamples)
        data = np.fromfile(f, dtype=np.short)

        print "dataLenth: " + str(len(data))

        ax1 = fig.add_subplot(totalPlots, 1, plotCount)
        plotCount += 1

        ax1.set_title(os.path.basename(sys.argv[1]), color='green')
        ax1.set_ylabel('Amplitude')

        if dataType == "complex":
           y1 = data[0::2]
           print "yLength: " + str(len(y1))
           if (int(numSamples) > 0):
              y1 = y1[:int(numSamples)]
           x1 = range(len(y1))

           ax2 = fig.add_subplot(totalPlots, 1, plotCount)
           plotCount += 1
           ax2.set_ylabel('Amplitude')

           y2 = data[1::2]
           if (int(numSamples) > 0):
              y2 = y2[:int(numSamples)]
           x2 = range(len(y2))
           ax1.plot(x1,y1, c='r', label='Q')
           ax2.plot(x2,y2, c='r', label='I')
           leg2 = ax2.legend()

           complex_data = np.array(np.zeros(len(data)/2), dtype=np.complex64)
           j=0
           for i in xrange(0,len(data)-1,2):
              complex_data[j] = complex(data[i], data[i+1])
              j+=1
           FFT = abs(np.fft.fft(complex_data))
           bins = np.fft.fftfreq(complex_data.size,0.01)
           fft_fig = plt.figure(2)
           ax3 = fft_fig.add_subplot(1, 1, 1)
           ax3.set_title(str(complex_data.size) + '-Point Complex FFT')
           ax3.set_xlabel('Frequency (Hz)')
           ax3.set_ylabel('Power (dBm)')
           ax3.plot(bins,20*np.log10(FFT))

        else:
           y = data
           if (int(numSamples) > 0):
              y = y[:int(numSamples)]
           x = range(len(y))
           ax1.plot(x,y, c='r', label='rData')

           FFT = abs(np.fft.fft(y))
           bins = np.fft.fftfreq(y.size,0.01)
           fft_fig = plt.figure(2)
           ax3 = fft_fig.add_subplot(1, 1, 1)
           ax3.set_title(str(y.size) + '-Point Real FFT')
           ax3.set_xlabel('Frequency (Hz)')
           ax3.set_ylabel('Power (dBm)')
           ax3.plot(bins,20*np.log10(FFT))


        leg = ax1.legend()

    plt.show()

if __name__ == '__main__':
    main()
