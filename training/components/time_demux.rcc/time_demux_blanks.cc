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

// Note: This file uses C++11; you must add the proper compiler command line to the Makefile
//       for each target platform, e.g:
// RccExtraCompileOptionsCC_centos7+=--std=c++11

#include <cstring>
#include <iostream>
#include "time_demux-worker.hh"

using namespace OCPI::RCC; // for easy access to RCC data types and constants
using namespace Time_demuxWorkerTypes;

class Time_demuxWorker : public Time_demuxWorkerBase {
  static const bool verbose = true;

  RCCResult start() {
    // Guarantee that only Time opcode is sent on Time_Out port:
    Time_Out.setDefaultOpCode(Iqstream_with_syncTime_OPERATION);
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

  // Internal helper function to manipulate counters
  void increment_counters(size_t bytecount) {
    ++???; // Messages_Read property
    ??? += bytecount; // Bytes_Read property
  }

  RCCResult run(bool /*timedout*/) {
    // determine if end of file
    if (Mux_In.???) { // <---- if Mux_In ports gets a end of file 
      Data_Out.???;   // <---- pass on a end of file to Data_Out port
      Time_Out.???;   // <---- pass on a end of file to Time_Out port
      return RCC_DONE;
    }

    // Determine opcode
    switch (???) {
      case ???_OPERATION: // IQ (found in gen/time_demux-worker.hh)
      {
        const size_t num_of_elements = Mux_In.iq().data().???;
        // Insert IQ opcode logic here (update properties, allocate output, copy sequence, send)
        if (verbose) std::cerr << "Received " << num_of_elements << " " << sizeof(IqstreamIqData) << "-byte values." << std::endl; // How many elements were read?
        increment_counters(???);
        Data_Out.iq().data().resize(???); // Resize the output buffer to the size of the received buffer
        const Iqstream_with_syncIqData *iptr = ???; // Input buffer's data pointer
        /*                                     ^      ^    ^      ^------ The Iqstream_with_syncIqData structs
         *                                     |      |    \------------- The argument of the IqOp (returns Mux_InPort::IqOp::DataArg object)
         *                                     |      \------------------ The opcode (returns Mux_InPort::IqOp object)
         *                                     \------------------------- The port
         */

        IqstreamIqData *optr = ???; // Output buffer's data pointer
        /*                     ^        ^    ^      ^------ The IqstreamIqData structs
         *                     |        |    \------------- The argument of the IqOp (returns Data_OutPort::IqOp::DataArg object)
         *                     |        \------------------ The opcode (returns Data_OutPort::IqOp object)
         *                     \--------------------------- The port
         */
        for (size_t i = 0; i < num_of_elements; ++i, ++iptr, ++optr) {
          //  *optr++ = *iptr++; // Does not work; structs are different type!
          ???->I = ???->I;
          ???->Q = ???->Q;
        }
        Data_Out.???; // Advance output (Data) port
      } // case statement anonymous block for stack variables
        break;
      case ???_OPERATION: // Time (found in gen/time_demux-worker.hh)
        // Insert Time opcode logic here (update properties, copy scalar, send)
        increment_counters(sizeof(uint64_t));
        ???.Current_Second = static_cast<uint32_t>(Mux_In.??? >> 32); // Set Current_Second property to upper 32-bits of incoming time
        if (verbose) std::cerr << "Timestamp: " << ???.Current_Second << std::endl;
        ???                    = ???; // Set output value to input (scalar)
     /* ^        ^      ^------ The single uint64_t (no need for wrapper class providing length, etc.)
      * |        \------------- The opcode (returns Time_Out::TimeOp object)
      * \---------------------- The port
      */
        Time_Out.??? // Advance output (Time) port
        break;
      default: // Sync_OPERATION and any unknowns
        // do nothing (but record message received)
        increment_counters(0);
    } // opcode switch
    ???; // Advance input port
    return ???; // Cannot use RCC_ADVANCE because both output ports never used in a single cycle.
  }
}; // end class Time_demuxWorker

TIME_DEMUX_START_INFO
// Insert any static info assignments here (memSize, memSizes, portInfo)
// e.g.: info.memSize = sizeof(MyMemoryStruct);
TIME_DEMUX_END_INFO
