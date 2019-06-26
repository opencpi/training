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
 * THIS FILE WAS ORIGINALLY GENERATED ON Wed Mar 30 09:48:42 2016 EDT
 * BASED ON THE FILE: complex_mixer.xml
 * YOU *ARE* EXPECTED TO EDIT IT
 *
 * This file contains the implementation skeleton for the complex_mixer worker in C++
 */

#include "complex_mixer-worker.hh"
#include <liquid/liquid.h>
#include <cmath>
#include <iostream>
#include <climits>

using namespace OCPI::RCC; // for easy access to RCC data types and constants
using namespace Complex_mixerWorkerTypes;
using namespace std;

#define Uscale(x)  (float)((float)(x) / (pow(2,15) -1))
#define Scale(x)   (int16_t)((float)(x) * (pow(2,15) -1))

class Complex_mixerWorker : public Complex_mixerWorkerBase
{
  nco_crcf q;

  RCCResult initialize()
  {
    q = nco_crcf_create(LIQUID_NCO);
    nco_crcf_set_phase(q, 0.0f);

    return ???; // Comment out this line!
    // Always return Success (uncomment one)
    // return RCC_ADVANCE;
    // return RCC_ADVANCE_DONE;
    // return RCC_DONE;
    // return RCC_ERROR;
    // return RCC_FATAL;
    // return RCC_GOOD;
    // return RCC_NONE;
    // return RCC_OK;
  }

  RCCResult release()
  {
    nco_crcf_destroy(q);

    return ???; // Comment out this line!
    // Always return Success (uncomment one)
    // return RCC_ADVANCE;
    // return RCC_ADVANCE_DONE;
    // return RCC_DONE;
    // return RCC_ERROR;
    // return RCC_FATAL;
    // return RCC_GOOD;
    // return RCC_NONE;
    // return RCC_OK;
  }

  RCCResult run(bool /*timedout*/)
  {
    // get access to the input buffer: see slides, gen/complex_mixer-worker.hh, and iqstream protocol
    const IqstreamIqData* inData = ???;
                            /*     ^  ^    ^      ^------ The Iqstream structs
                             *     |  |    \------------- The argument of the IqOp (returns InPort::IqOp::DataArg object)
                             *     |  \------------------ The opcode (returns InPort::IqOp object)
                             *     \--------------------- The port
                             */

    // get access to the output buffer: see slides, gen/complex_mixer-worker.hh, and iqstream protocol
    IqstreamIqData* outData = ???;
                       /*     ^   ^    ^      ^------ The Iqstream structs
                        *     |   |    \------------- The argument of the opcode
                        *     |   \------------------ The opcode
                        *     \---------------------- The port
                        */

    // size in IqstreamIqData units
    const size_t num_of_elements = ???;

    // resize the output buffer to the size of the input buffer
    ???(num_of_elements);

    // set each time so that if the container changes it gets updated
    // read the phs_inc property and manipulate it:
    float phase_inc = ??? * ((2*M_PI)/(SHRT_MAX * 2));
    nco_crcf_set_frequency(q,phase_inc);

    liquid_float_complex out_sample;
    liquid_float_complex in_sample;

    // loop for each sample in the buffer
    for (unsigned int j = 0; j < num_of_elements; j++)
    {
      // check if the enable property is set to true
      if (???)
      {
       // convert the input samples from the input buffer to floating point numbers
        in_sample.real = Uscale(???);
        in_sample.imag = Uscale(???);

        nco_crcf_step(q);
        nco_crcf_mix_down(q, in_sample, &out_sample);

        // convert the samples to fixed point and put them into the output buffer
        ??? = Scale(out_sample.real);
        ??? = Scale(out_sample.imag);
      }
      else
      {
        // copy from input buffer to output buffer
        ??? // I
        ??? // Q
      }
      // increment pointers
      inData++;
      outData++;
    }

    // select the correct return value
    // remember: zero-length data has significant meaning
    return num_of_elements ? ??? : ???;
  }
};

COMPLEX_MIXER_START_INFO
// Insert any static info assignments here (memSize, memSizes, portInfo)
// e.g.: info.memSize = sizeof(MyMemoryStruct);
COMPLEX_MIXER_END_INFO
