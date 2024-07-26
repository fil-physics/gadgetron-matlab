#!/bin/bash
# run this within tested container to perform integration tests
# warning: test_dir is wiped out before and after testing !!!

# hint: to run this script from inside the test container
# e.g. ./run_tests_in_container.sh /hostshare/container_test_data/reconstructed_reference_images/fil-physicsc-V13.4 /hostshare/tests/tmp/ .

ref_dir=$1
tmp_dir=$2
cfg_dir=$3

# exit on error
set -e

echo "Using data from: ${ref_dir} as reference."
echo "Using ${tmp_dir} as temporary directory."
echo "Using cfg files from ${cfg_dir}."

/opt/code/gadgetron/test/integration/run_tests.py -d ${ref_dir} -t ${tmp_dir} ${cfg_dir}/*.cfg

echo "Cleaning up xprot and xml files from working directory"
rm -f *.x*

echo "Removing temporary directory."
rm -r ${tmp_dir}
