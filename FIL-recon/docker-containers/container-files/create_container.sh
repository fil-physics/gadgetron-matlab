#!/bin/bash

# Stop on error
set -e

# Settings for deployment container
IMAGE_FORK=fil-physics				# Docker image from which the container
IMAGE_VERSION=V16				# will be created
CONTAINER_SUFFIX=0_public_rc1				# container version

# Settings for Matlab
GAD_MAT_FORK=baskadym 			# GitHub fork (e.g. fil-physics or your GitHub username)
GAD_MAT_VERSION=a21e3f4			# Commit of gadgetron_matlab_local
MATLAB_VERSION=R2022b				# Matlab application version

IMAGE_NAME=${IMAGE_FORK}:${IMAGE_VERSION}
CONTAINER_NAME=${IMAGE_FORK}c-${IMAGE_VERSION}.${CONTAINER_SUFFIX}

# End of settings section

# Create container
# /home/mr mounted onto /mnt to get .Xauthority
sudo docker create --name=${CONTAINER_NAME} --net=host \
	-v /hostshare:/hostshare \
	-v /usr/local/MATLAB:/usr/local/MATLAB \
	-e DISPLAY=:0.0 \
       --cpuset-cpus=0-23 \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-v $HOME:/mnt:ro --privileged \
	${IMAGE_NAME}


# Test container works
sudo docker start ${CONTAINER_NAME}
# Once manifest is re-instated uncomment the following
# sudo docker exec -it fil_physicsc_${cV} cat /opt/manifest.json

# Set up container
sudo docker cp setup_container.sh ${CONTAINER_NAME}:/root
sudo docker exec -it ${CONTAINER_NAME} /root/setup_container.sh ${GAD_MAT_FORK} ${GAD_MAT_VERSION} ${MATLAB_VERSION}

# Check X and matlab are working and javaclasspath has gadgetron directory
# N.B. bash -i to set X authority from .bashrc
# If X is not working will see warnings from matlab
sudo docker exec -it ${CONTAINER_NAME} bash -ic "matlab -batch javaclasspath\(\'-static\'\)"

# Show last created container (should be this one)
sudo docker ps -l

