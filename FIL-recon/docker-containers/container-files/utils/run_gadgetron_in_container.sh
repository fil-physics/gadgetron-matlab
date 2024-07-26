#!/bin/bash
# run gadgetron in a fil gadgetron container as root
# launcher must specify FULL path to this script for polkit action to allow without further authentication

container_name=$1

# Strip off the end of the container name, from the first occurence of "c-" (e.g. fil-physicsc-V15.0 becomes fil-physics)
#gad_mat_fork=${container_name%%c-*}

# docker restart -t0 $container_name
docker container stop -t0 $(sudo docker container ls -q --filter name=physics)
docker start $container_name

# For debugging open an xterm in the container
#(docker exec $container_name xterm -geometry 80x24+150-380 -e bash) &

# Note the wildcard (*) in the path to cope with fil-physics or, e.g., ojosephs, at that level
docker exec $container_name xterm -geometry 160x24-100-0 -T ${container_name} -e "cd /opt/code/github/*/gadgetron-matlab-local/FIL-recon; bash -ic './run_gadgetron.sh'"
