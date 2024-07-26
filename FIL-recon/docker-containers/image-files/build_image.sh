#!/bin/bash
# Build a FIL physics docker container image

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Stop on error
set -e

# Settings for deployment image
IMAGE_FORK=fil-physics
IMAGE_VERSION=V16

IMAGE_NAME=${IMAGE_FORK}:${IMAGE_VERSION}
BASE_NAME=${IMAGE_NAME}-base

MATLAB_CONTAINER_URL=https://github.com/mathworks-ref-arch/container-images.git
MATLAB_CONTAINER_CONTEXT_DIR=container-images/matlab-deps/r2022b/ubuntu20.04
MATLAB_IMAGE_NAME=mathworks/matlab-deps:r2022b-ubuntu20.04

FIL_EXTRAS_IMAGE_NAME=fil-extras

# gadgetron repo and commit
# dependency repos and commits are stored in gadgetron/docker/build_gadgetron_dependencies.sh

GADGETRON_URL=https://github.com/${IMAGE_FORK}/gadgetron
GADGETRON_BRANCH=master
GADGETRON_REV=0178603


# End of settings section


# Uncomment the next three lines to build the Mathworks base image for Matlab
rm -rf container-images
git clone ${MATLAB_CONTAINER_URL}
docker build -t ${MATLAB_IMAGE_NAME} ${MATLAB_CONTAINER_CONTEXT_DIR}
# Or pull the image from DockerHub
# sudo docker pull ${MATLAB_IMAGE_NAME}


# Checkout gadgetron to get Dockerfiles and as context for docker building

rm -rf gadgetron && \
git clone ${GADGETRON_URL} --branch ${GADGETRON_BRANCH} --single-branch && \
( cd gadgetron && git checkout ${GADGETRON_REV} )

# Build base image for Gadgetron
(
cd gadgetron/docker && \
docker build -t ${BASE_NAME} --no-cache --build-arg "BASE_IMAGE=${MATLAB_IMAGE_NAME}" -f ubuntu_base.Dockerfile .
)

# Build Bart (compiled with MKL). N.B. "- <" syntax allows a "docker build" without a context directory
docker build -t ${FIL_EXTRAS_IMAGE_NAME} --no-cache --build-arg "BASE_IMAGE=${BASE_NAME}" - < FIL-EXTRAS.Dockerfile 

# Build the final gadgetron image
# docker rmi ${IMAGE_NAME}
(
cd gadgetron && \
docker build -t ${IMAGE_NAME} --no-cache --build-arg "BASE_IMAGE=${FIL_EXTRAS_IMAGE_NAME}" .
)

# Uncomment next line to untag the intermediate base images so they don't appear in "docker images"
docker rmi ${MATLAB_IMAGE_NAME} ${BASE_NAME} ${FIL_EXTRAS_IMAGE_NAME}

# Print what to do next to create the container 
echo
echo "If image was built successfully, cd ../container-files, then configure and execute ./create_container.sh"

