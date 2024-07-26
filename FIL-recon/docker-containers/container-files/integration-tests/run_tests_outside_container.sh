#!/bin/bash
# run this within tested container to perform integration tests
# warning: test_dir is wiped out before and after testing !!!

ref_container=fil-physicsc-V15.9_bkd_rc1
test_container=fil-physicsc-V15.9_bkd_MPM_B1_share

ref_dir=/hostshare/container_test_data/reconstructed_reference_images/${ref_container}

gadmat_fork=baskadym
run_dir=/opt/code/github/${gadmat_fork}/gadgetron-matlab-share/FIL-recon/integration-tests
tmp_dir=/hostshare/tmp/integration-tests

# stop on error
set -e

# Allow remote testing with ssh -X
#sudo xauth add $(xauth -f ~/.Xauthority list | tail -1)

sudo docker restart -t 0 ${test_container}

# 3T tests

cfg_dir=${run_dir}/3T

sudo docker exec -w ${run_dir} -it ${test_container} bash -ic "export DISPLAY=${DISPLAY}; ./run_tests_in_container.sh ${ref_dir} ${tmp_dir} ${cfg_dir}"

# 7T tests

cfg_dir=${run_dir}/7T

sudo docker exec -w ${run_dir} -it ${test_container} bash -ic "export DISPLAY=${DISPLAY}; ./run_tests_in_container.sh ${ref_dir} ${tmp_dir} ${cfg_dir}"

sudo docker stop ${test_container}

