#!/bin/bash
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

# Check for parameter / usage
if test -z "$1"; then
  echo "You did not provide a lab number you wanted to complete"
  echo "Usage: $0 lab_number_to_complete"
  echo "export BUILD_HDL=1 to build components and test assemblies for HDL (takes long!)"
  exit 99
fi

# Let it be run from one-above-provided or provided/scripts/
if [ '.' == "$(dirname $0)" ]; then
  cd ../..
fi

if [ ! -d 'provided' ]; then
  echo "Cannot determine location. Run from above 'provided' or within provided/scripts/."
  exit 99
fi

# Possible answer source locations
for dir in ~/.dist/training ~training/.dist/training ./training/ .dist/training/; do
  if test -d $dir; then
    export ANS_DIR=$(realpath ${dir})
  fi
done

if test -z "${ANS_DIR}"; then
  echo "Could not find answer source directory."
  exit 99
fi
echo "Using answer source dir: ${ANS_DIR}"

# Possible answer source locations
for dir in ~/provided ~training/provided ./provided/; do
  if test -d $dir; then
    export PRO_DIR=$(realpath ${dir})
  fi
done

if test -z "${PRO_DIR}"; then
  echo "Could not find provided source directory."
  exit 99
fi
echo "Using provided source dir: ${PRO_DIR}"
echo "Using target dir: $(realpath $(pwd))/training_project"

if test -d training_project; then
  echo "Please delete the existing 'training_project' directory"
  exit 99
fi

# Just in case... we can't do anything about the GUI
echo "Attempting to unregister any previous ocpi.training from the Project Registry"
ocpidev -f unregister project ocpi.training

set -e

####### UTILITY FUNCTIONS

# Copy a component spec from training answers
cp_spec() {
  echo "Copying $1 spec..."
  cp -r ${ANS_DIR}/components/specs/$1-spec.xml training_project/components/specs/
}

# Copy a worker from training answers
cp_worker() {
  echo "Copying $1..."
  rm -rf training_project/components/$1 || :
  cp -r ${ANS_DIR}/components/$1 training_project/components/
}

# Build an RCC Worker
build_workers_rcc() {
  echo "Building RCC workers..."
  ocpidev -d training_project build library components --build-rcc --build-rcc-platform centos7 --build-rcc-platform xilinx13_3
}

# Build an HDL Worker
build_workers_hdl() {
  if test -n "${BUILD_HDL}"; then
    echo "Building HDL workers..."
    ocpidev -d training_project build library components --build-hdl --build-no-assemblies --build-hdl-platform xsim --build-hdl-platform matchstiq_z1
  else
    echo "Skipping HDL worker build (set BUILD_HDL if you want them built)"
  fi
}

# Build a test
build_test() {
  echo "Building test for $1..."
  # This "clean" is needed to catch newly available HDL workers
  cd training_project/components/$1
  # BROKEN AV-3368: ocpidev -d training_project clean test $1
  make clean
  cd ${ORIG}
  if test -n "${BUILD_HDL}"; then
    ocpidev -d training_project build test $1 --build-rcc-platform centos7 --build-rcc-platform xilinx13_3 --build-hdl-platform xsim --build-hdl-platform matchstiq_z1
  else
    ocpidev -d training_project build test $1 --build-rcc-platform centos7 --build-rcc-platform xilinx13_3
  fi
}

# Run a test
run_test() {
  cd training_project/components/$1
  export OCPI_HDL_SIMULATOR="${OCPI_HDL_SIMULATOR}"
  make run
  cd ${ORIG}
}

ORIG=$(pwd)

####### START OF REAL WORK

# This concept doesn't really apply to these labs:
case $1 in
  1)
    echo "Lab $1 does not support restarting, sorry!"
    false
    ;;
esac

# Lab 2 is unique; it already has the entire project done. Not sure this would ever be done...
if test $1 -eq 2; then
  export PROCESSED=1
  # Copy provided
  if test -n "${KEEP_LAB_TWO}"; then
        cp -r ${PRO_DIR}/lab2/training_project/ .
	ocpidev register project ./training_project/  
	cp ${ANS_DIR}/applications/lab2_app.xml training_project/applications/
	mkdir -p training_project/applications/idata
	cp ${ANS_DIR}/applications/idata/lab2_input_file.bin training_project/applications/idata/
	# Not sure if these are actually needed...
	ocpidev -d training_project create hdl assembly lab2_most_rcc_assy
	cp training/hdl/assemblies/lab2_most_rcc_assy/*xml training_project/hdl/assemblies/lab2_most_rcc_assy/
	ocpidev -d training_project create hdl assembly lab2_most_hdl_assy
	cp training/hdl/assemblies/lab2_most_hdl_assy/*xml training_project/hdl/assemblies/lab2_most_hdl_assy/
	if test -n "${BUILD_HDL}"; then
	    ocpidev -d training_project build --build-rcc-platform xilinx13_3 --build-hdl-platform matchstiq_z1
	else
	    echo "Skipping HDL worker build (set BUILD_HDL if you want them built)"
	fi
  else
    echo "The last step in Lab 2 is to delete the created project (Set KEEP_LAB_TWO if you don't want it deleted)"
  fi
fi

# Being the first "regular" one, we do basic setup here too
if test $1 -ge 3; then
  export PROCESSED=1
  echo "Setting up training_project..."
  ocpidev create project training_project -N training -F ocpi -D ocpi.assets -y util_comps
  ocpidev -d training_project create library components
  mkdir -p training_project/components/specs
  cp -r ${ANS_DIR}/scripts training_project/
  echo "Copying Lab 3 files..."
  cp_spec peak_detector
  cp_worker peak_detector.rcc
  cp_worker peak_detector.test
  build_workers_rcc
  build_test peak_detector.test
  run_test peak_detector.test
fi

if test $1 -ge 4; then
  export PROCESSED=1
  echo "Copying Lab 4 files..."
  cp_spec complex_mixer
  cp_worker complex_mixer.rcc
  cp_worker complex_mixer.test
  # Remove the "data_select" line which is HDL-only:
  sed -i '/data_select/d' training_project/components/complex_mixer.test/complex_mixer-test.xml
  build_workers_rcc
  build_test complex_mixer.test
  run_test complex_mixer.test
fi

if test $1 -ge 5; then
  export PROCESSED=1
  echo "Copying Lab 5 files..."
  cp_spec time_demux
  cp_worker time_demux.rcc
  cp_worker time_demux.test
  build_workers_rcc
  build_test time_demux.test

  version=$(ocpirun --version)
  if [[ "$version" == *"1.4"* ]]; then
    echo "Fixing a generated Lab 5 test in version 1.4"
    # Fixup for bug in 1.4, where the connections from time_demux are not correct in a generated test.
    # When going through the labs manually, users have to fix this. Now we automate, if they use this script.
    # The cause of this issue is fixed in 1.5.
    echo '<application done="file_write_from_Data_Out">
    <instance component="ocpi.core.file_read" connect="time_demux_ms_Mux_In" Name="file_read">
      <property name="filename" value="../../gen/inputs/case00.00.Mux_In"/>
      <property name="messagesInFile" value="true"/>
    </instance>
    <instance component="ocpi.core.metadata_stressor" name="time_demux_ms_Mux_In" connect="time_demux">
    </instance>
    <instance component="ocpi.training.time_demux" name="time_demux"/>
    <instance component="ocpi.core.backpressure" name="bp_from_Data_Out" connect="file_write_from_Data_Out">
      <property name="enable_select" value="true"/>
    </instance>
    <instance component="ocpi.core.file_write" name="file_write_from_Data_Out"/>
    <instance component="ocpi.core.backpressure" name="bp_from_Time_Out" connect="file_write_from_Time_Out">
      <property name="enable_select" value="true"/>
    </instance>
    <instance component="ocpi.core.file_write" name="file_write_from_Time_Out"/>
      <Connection>
          <Port Instance="time_demux" Name="Time_Out"></Port>
          <Port Instance="bp_from_Time_Out" Name="in"></Port>
      </Connection>
      <Connection>
          <Port Instance="time_demux" Name="Data_Out"></Port>
          <Port Instance="bp_from_Data_Out" Name="in"></Port>
      </Connection>
    </application>
    ' > training_project/components/time_demux.test/gen/applications/case00.00.xml
  fi
  run_test time_demux.test
fi

if test $1 -ge 6; then
  export PROCESSED=1
  # After this point, we want tests to run in xsim as well as Centos7
  if test -n "${BUILD_HDL}"; then
    export OCPI_HDL_SIMULATOR='xsim'
  fi
  echo "Copying Lab 6 files..."
  cp_worker peak_detector.hdl
  build_workers_hdl
  build_test peak_detector.test
  run_test peak_detector.test
fi

if test $1 -ge 7; then
  export PROCESSED=1
  echo "Copying Lab 7 files..."
  cp_spec agc_complex
  cp_worker agc_complex.hdl
  cp_worker agc_complex.test
  ocpidev -d training_project create hdl primitive library prims -O prims_pkg.vhd -O agc/src/agc.vhd
  cp ${ANS_DIR}/hdl/primitives/prims/prims_pkg.vhd training_project/hdl/primitives/prims/
  cp -r ${ANS_DIR}/hdl/primitives/prims/agc training_project/hdl/primitives/prims/
  # We will ALWAYS build these primitives even without BUILD_HDL because end user could get confused with the Project.mk hack
  ocpidev -d training_project build hdl primitives --build-hdl-platform xsim --build-hdl-platform matchstiq_z1
  cp ${ANS_DIR}/components/Library.mk training_project/components/
  build_workers_hdl
  if test -n "${BUILD_HDL}"; then
    # If no workers at all, ocpigen will fail with "There are currently no valid workers implementing ocpi.training.agc_complex"
    build_test agc_complex.test
    run_test agc_complex.test
  fi
fi

if test $1 -ge 8; then
  export PROCESSED=1
  echo "Copying Lab 8 files..."
  cp_worker complex_mixer.hdl
  cp_worker complex_mixer.test
  build_workers_hdl
  if test -n "${BUILD_HDL}"; then
    # If no HDL worker to impement data_select, the test will fail here
    build_test complex_mixer.test
    run_test complex_mixer.test
  fi
fi

if test $1 -ge 9; then
  export PROCESSED=1
  echo "Copying Lab 9 files..."
  cp_spec counter
  cp_worker counter.hdl
  cp_worker counter.test
  build_workers_hdl
  if test -n "${BUILD_HDL}"; then
    # If no workers at all, ocpigen will fail
    build_test counter.test
    run_test counter.test
  fi
fi

if test $1 -ge 10; then
  echo "Up to Lab 9 succeeded, but you asked for $1, which is invalid."
  false
fi

if test -z "${PROCESSED}"; then
  echo "I don't believe I did anything...? Did you put a valid lab number?"
  false
fi
