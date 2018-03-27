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

// g++ -Wall --std=c++0x -o test_data_generator test_data_generator.cxx

// #include <boost/utility.hpp>
#include <stdexcept>
#include <vector>
#include <cstring>
#include <cassert>
#include <iostream>
#include <cstdlib>
#include <memory>
#include <limits>

// Copied from time_demux-worker.hh:
enum Iqstream_with_syncOpCodes {
  Iqstream_with_syncIq_OPERATION,
  Iqstream_with_syncSync_OPERATION,
  Iqstream_with_syncTime_OPERATION
};

class time_demux_data_gen /* : boost::noncopyable */ {
private:
  FILE *outfile_data, *outfile_gold_time, *outfile_gold_data;
  uint32_t hdr[2]; // length + opcode

public:
  // Push timestamp
  void push_timestamp(const uint64_t timestamp) {
    hdr[0] = sizeof(uint64_t);
    hdr[1] = Iqstream_with_syncTime_OPERATION;
    assert (1 == fwrite(hdr, sizeof(hdr), 1, outfile_data));
    assert (1 == fwrite(&timestamp, sizeof(uint64_t), 1, outfile_data));
    assert (1 == fwrite(&timestamp, sizeof(uint64_t), 1, outfile_gold_time));
  }

  // Push data block
  void push_data(const uint32_t *data, const size_t len) {
    hdr[0] = sizeof(uint32_t)*len;
    hdr[1] = Iqstream_with_syncIq_OPERATION;
    assert (1 == fwrite(hdr, sizeof(hdr), 1, outfile_data));
    if (!len) return;
    assert (1 == fwrite(data, sizeof(uint32_t)*len, 1, outfile_data));
    assert (1 == fwrite(data, sizeof(uint32_t)*len, 1, outfile_gold_data));
  }

  time_demux_data_gen(const std::string &outfilename,
                      const std::string &outfilename_gold_time,
                      const std::string &outfilename_gold_data
                     ) {
    outfile_data = fopen(outfilename.c_str(), "wb");
    if (!outfile_data) throw(std::runtime_error(strerror(errno)));
    outfile_gold_time = fopen(outfilename_gold_time.c_str(), "wb");
    if (!outfile_gold_time) throw(std::runtime_error(strerror(errno)));
    outfile_gold_data = fopen(outfilename_gold_data.c_str(), "wb");
    if (!outfile_gold_data) throw(std::runtime_error(strerror(errno)));
  }

  ~time_demux_data_gen() {
    fclose(outfile_data);
    fclose(outfile_gold_time);
    fclose(outfile_gold_data);
  }

private:  // noncopyable
  time_demux_data_gen() {}
  time_demux_data_gen( const time_demux_data_gen& );
  const time_demux_data_gen& operator=( const time_demux_data_gen& );
}; // time_demux_data_gen

const char *get_env(const char *var) {
  const char *val = getenv(var);
  if (val) return val;
  std::string emsg("Could not find required variable in environment: ");
  emsg.append(var);
  throw(std::invalid_argument(emsg));
}

int main(int argc, const char * const argv[]) {
  if (not (2 == argc or 4 == argc)) { // Must have one output minimum, or three.
    std::cerr << "Expected arguments are:\n"<<argv[0]<<" data_out_file [golden_time_out golden_data_out]\n";
    throw(std::invalid_argument("Invalid number of arguments"));
  }

  FILE *infile = fopen(get_env("OCPI_TEST_IFILE"), "rb");
  if (!infile) throw(std::runtime_error(strerror(errno)));

  const long long fake_time_in = atoll(get_env("OCPI_TEST_START"));
  if (fake_time_in < 0) throw(std::runtime_error("Invalid start_timestamp (too low)!"));
  if (fake_time_in > std::numeric_limits<uint32_t>::max()) throw(std::runtime_error("Invalid start_timestamp (too high)!"));
  uint32_t fake_time = static_cast<uint32_t>(fake_time_in);

  const int samples_per_second = atoi(get_env("OCPI_TEST_SAMPLES"));
  if (samples_per_second <= 0) throw(std::runtime_error("Invalid samples_per_second!"));

  std::string out_gold_time(argv[1]);
  std::string out_gold_data(argv[1]);
  if (4 == argc) {
    out_gold_time = argv[2];
    out_gold_data = argv[3];
  } else {
    out_gold_time.append("_gold_time");
    out_gold_data.append("_gold_data");
  }

  time_demux_data_gen gen(argv[1], out_gold_time, out_gold_data);

  std::cout << "Generating test data:\nInput File: " << get_env("OCPI_TEST_IFILE") << "\nStart Time: "
            << fake_time << "\nSamples per \"second\": " << samples_per_second
            << "\nOutput Files: " << argv[1] << ", " << out_gold_time << ", " << out_gold_data
            << std::endl;
  // Read samples in 32b chunks to represent a pair of 16-bit samples
  std::unique_ptr<uint32_t> buf(new uint32_t[samples_per_second]);
  ssize_t read;

  do {
    read = fread(buf.get(), sizeof(uint32_t), samples_per_second, infile);
    if (read) {
      if (read != samples_per_second and not feof(infile))
        std::cerr << "Tried to read " << samples_per_second << ", but only read " << read << std::endl;
      gen.push_timestamp((static_cast<uint64_t>(fake_time) << 32) | (fake_time+1));
      ++fake_time;
      assert(fake_time>0);
      gen.push_data(buf.get(), read);
    }
  } while (read > 0 and not feof(infile));

  // Insert a single ZLM into data stream
  gen.push_data(NULL, 0);

  fclose(infile);
  return 0;
};
