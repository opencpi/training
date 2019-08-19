/*
 * This file is protected by Copyright. Please refer to the COPYRIGHT file
 * distributed with this source distribution.
 *
 * This file is part of OpenCPI <http://www.opencpi.org>
 *
 * OpenCPI is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * OpenCPI is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * THIS FILE WAS ORIGINALLY GENERATED ON Tue Mar 29 16:29:51 2016 EDT
 * BASED ON THE FILE: peak_detector.xml
 * YOU *ARE* EXPECTED TO EDIT IT
 *
 * This file contains the implementation skeleton for the peak_detector worker in C++
 */

#include <algorithm>
#include "peak_detector-worker.hh"

using namespace OCPI::RCC; // for easy access to RCC data types and constants
using namespace Peak_detectorWorkerTypes;

class Peak_detectorWorker : public Peak_detectorWorkerBase {

  int16_t max_buff, min_buff;
  
  RCCResult start(){
    max_buff = -32768;
    min_buff = 32767; 
    return RCC_OK;
    
    /* Other valid: */

    // max_buff = std::numeric_limits<int16_t>::min(); add #include <limits>
    // min_buff = std::numeric_limits<int16_t>::max(); add #include <limits>
    // max_buff = int16_t(pow(2,(double((sizeof(idata->I)*8)-1)))); add #include <cmath>
    // min_buff = (-1)*max_neg-1;

  }

  RCCResult run(bool /*timedout*/) {

    // determine if end of file
	if (in.eof()) {
	  out.setEOF();
	  return RCC_DONE;
	}

    // 1. Make sure there is room on the output port
    const size_t num_of_elements = in.iq().data().size();
    out.iq().data().resize(num_of_elements);
    out.setOpCode(in.opCode());  

    // 2. Do work
    const IqstreamIqData *idata = in.iq().data().data();
    IqstreamIqData *odata = out.iq().data().data();
    for (unsigned n = num_of_elements; n; n--) {// n is length in sequence elements of input
      max_buff = std::max(std::max(idata->I,idata->Q),max_buff);
      min_buff = std::min(std::min(idata->I,idata->Q),min_buff);

      *odata++ = *idata++; // copy this message to output buffer
    }
    properties().max_peak = max_buff;
    properties().min_peak = min_buff;

    // 3. Advance ports
    return num_of_elements ? RCC_ADVANCE : RCC_ADVANCE_DONE;
  }
};

PEAK_DETECTOR_START_INFO
// Insert any static info assignments here (memSize, memSizes, portInfo)
// e.g.: info.memSize = sizeof(MyMemoryStruct);
PEAK_DETECTOR_END_INFO
