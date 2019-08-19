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
  static const bool verbose = false;

  RCCResult start() {
    // Guarantee that only Time opcode is sent on Time_Out port:
    Time_Out.setDefaultOpCode(Iqstream_with_syncTime_OPERATION);
    return RCC_OK;
  }

  // Internal helper function to manipulate counters
  void increment_counters(size_t bytecount) {
    ++properties().Messages_Read;
    properties().Bytes_Read += bytecount;
  }

  RCCResult run(bool /*timedout*/) {
	// determine if end of file
	if (Mux_In.eof()) {
	  Data_Out.setEOF();
	  Time_Out.setEOF();
	  return RCC_DONE;
	}
    // Determine opcode
    switch (Mux_In.opCode()) {
      case Iqstream_with_syncIq_OPERATION:
      {
        const size_t num_of_elements = Mux_In.iq().data().size();
        // Insert IQ opcode logic here (update properties, allocate output, copy sequence, send)
        if (verbose) std::cerr << "Received " << num_of_elements << " " << sizeof(IqstreamIqData) << "-byte values." << std::endl;
        increment_counters(Mux_In.length());
        Data_Out.iq().data().resize(num_of_elements);
        const auto *iptr = Mux_In.iq().data().data();
                    /*     ^      ^    ^      ^------ The Iqstream_with_syncIqData structs
                     *     |      |    \------------- The argument of the IqOp (returns Mux_InPort::IqOp::DataArg object)
                     *     |      \------------------ The opcode (returns Mux_InPort::IqOp object)
                     *     \------------------------- The port
                     */
        auto *optr = Data_Out.iq().data().data();
              /*     ^        ^    ^      ^------ The IqstreamIqData structs
               *     |        |    \------------- The argument of the IqOp (returns Data_OutPort::IqOp::DataArg object)
               *     |        \------------------ The opcode (returns Data_OutPort::IqOp object)
               *     \--------------------------- The port
               */
        for (size_t i = 0; i < num_of_elements; ++i, ++iptr, ++optr) {
          //  *optr++ = *iptr++; // Does not work; structs are different type!
          optr->I = iptr->I;
          optr->Q = iptr->Q;
        }
        Data_Out.advance();
      } // case statement anonymous block for stack variables
        break;
      case Iqstream_with_syncTime_OPERATION:
        // Insert Time opcode logic here (update properties, copy scalar, send)
        increment_counters(sizeof(uint64_t));
        properties().Current_Second = static_cast<uint32_t>(Mux_In.Time().time() >> 32);
        if (verbose) std::cerr << "Timestamp: " << properties().Current_Second << std::endl;
        Time_Out.Time().time() = Mux_In.Time().time();
     /* ^        ^      ^------ The single uint64_t (no need for wrapper class providing length, etc.)
      * |        \------------- The opcode (returns Time_Out::TimeOp object)
      * \---------------------- The port
      */
        Time_Out.advance();
        break;
      default: // Iqstream_with_syncSync_OPERATION and any unknowns
        // do nothing (but record message received)
        increment_counters(0);
    } // opcode switch
    Mux_In.advance();
    return RCC_OK; // Cannot use RCC_ADVANCE because both output ports never used in a single cycle.
  }
}; // end class Time_demuxWorker

TIME_DEMUX_START_INFO
// Insert any static info assignments here (memSize, memSizes, portInfo)
// e.g.: info.memSize = sizeof(MyMemoryStruct);
TIME_DEMUX_END_INFO
