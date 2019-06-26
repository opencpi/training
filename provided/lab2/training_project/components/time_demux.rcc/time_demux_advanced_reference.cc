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

// This source provides three solutions to the lab. Only choose one:

// This is the fastest approach; uses memcpy() directly by knowing ahead of time the EXACT memory layout of the struct matches:
// #define Try1

// This is the safest approach; explicitly individually copies I and Q data:
// #define Try2

// This is a combination of Try1 and Try2 using a templated function to do the Try 2 method.
// It can then be specialized with the knowledge from Try1 when available.
// This could be put in a user's "helper library" and defined by the protocol author.
#define Try3

using namespace OCPI::RCC; // for easy access to RCC data types and constants
using namespace Time_demuxWorkerTypes;

#ifdef Try3
namespace NS3 {
  // 1:1 copy (same type)
  template <typename T>
  void inline IQ_copy(const T* src, T* dst, const size_t len = 1) {
    // std::cerr << "Same struct NS3::IQ_copy called!\n";
    memcpy(dst, src, len*sizeof(T));
  }
  // Generalized "has I and Q"
  template <typename x, typename y>
  void inline IQ_copy(const x* src, y* dst, const size_t len = 1) {
    // std::cerr << "Generic NS3::IQ_copy called!\n";
    for (size_t i = 0; i < len; ++i) {
      (dst+i)->I = (src+i)->I;
      (dst+i)->Q = (src+i)->Q;
    }
  }
  // Take advantage of what we already know
  template <> void inline IQ_copy<>(const Iqstream_with_syncIqData *src, IqstreamIqData *dst, const size_t len) {
    // std::cerr << "Specialized NS3::IQ_copy called!\n";
    memcpy(dst, src, len*sizeof(IqstreamIqData));
  }
} // NS3
#endif

// Ensure nothing silly in protocols to use cheap memcpy later (Try1 and Try3)
static_assert(sizeof(Iqstream_with_syncIqData) == sizeof(IqstreamIqData), "Protocol mismatch");
static_assert(offsetof(Iqstream_with_syncIqData,I) == offsetof(IqstreamIqData,I), "Protocol mismatch (I offset)");
static_assert(offsetof(Iqstream_with_syncIqData,Q) == offsetof(IqstreamIqData,Q), "Protocol mismatch (Q offset)");

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
    // Determine opcode
    switch (Mux_In.opCode()) {
      case Iqstream_with_syncIq_OPERATION:
      {
        const size_t num_of_elements = Mux_In.iq().data().size();
        if (verbose) std::cerr << "Received " << num_of_elements << " " << sizeof(IqstreamIqData) << "-byte values." << std::endl;
        increment_counters(Mux_In.length());
        Data_Out.iq().data().resize(num_of_elements);
#ifdef Try1
        memcpy(Data_Out.iq().data().data(),
        /*     ^        ^    ^      ^------ The IqstreamIqData structs
         *     |        |    \------------- The argument of the IqOp (returns Data_OutPort::IqOp::DataArg object)
         *     |        \------------------ The opcode (returns Data_OutPort::IqOp object)
         *     \--------------------------- The port
         */
                Mux_In.iq().data().data(),
         /*     ^      ^    ^      ^------- The Iqstream_with_syncIqData structs
          *     |      |    \-------------- The argument of the IqOp (returns Mux_InPort::IqOp::DataArg object)
          *     |      \------------------- The opcode (returns Mux_InPort::IqOp object)
          *     \-------------------------- The port
          */
                num_of_elements*sizeof(IqstreamIqData));
                // Note: Above could be Mux_In.length() which is also the length in bytes, but this shows more what it is doing
#endif
#ifdef Try2
        auto *iptr = Mux_In.iq().data().data();
        auto *optr = Data_Out.iq().data().data();
        for (size_t i = 0; i < num_of_elements; ++i, ++iptr, ++optr) {
          //  *optr++ = *iptr++; // Does not work; structs are different type!
          optr->I = iptr->I;
          optr->Q = iptr->Q;
        }
#endif
#ifdef Try3
        NS3::IQ_copy(Mux_In.iq().data().data(), Data_Out.iq().data().data(), num_of_elements);
#endif
        Data_Out.advance();
      } // case statement anonymous block for stack variables
        break;
      case Iqstream_with_syncTime_OPERATION:
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
