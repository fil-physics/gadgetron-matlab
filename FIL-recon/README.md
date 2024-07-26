# FIL Physics MORSE Image Reconstruction

This repository contains MATLAB scripts for MRI image reconstruction using the MORSE method, as described in the following manuscript: 

**"MORSE CODE: Multiple Orthogonal Reference Sensitivity Encoding Combined Over Dominant Eigencoils" by O. Josephs et al.**

If you use these scripts for your work, please make sure to cite the paper.

## Installation instructions
### Docker
This reconstruction is executed within a Docker container, which includes all the necessary elements to run the image reconstruction in any environment. To install Docker Engine for your specific environment, please refer to the official Docker website for instructions:
https://docs.docker.com/engine/install/

Below, we provide an example for Ubuntu:

```bash
sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
 
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo docker run hello-world
```

### Creating Docker Image 
1. Edit `/gadgetron-matlab-share/FIL-recon/docker-containers/image-files/build_image.sh`

Choose a name for your image, for instance fil-physics-V1, by changing the following parameters:
```bash
IMAGE_FORK=fil-physics
IMAGE_VERSION=V1
```
2. Execute `build_image.sh` script.

### Creating Docker Container
1. Edit `/gadgetron-matlab-share/FIL-recon/docker-containers/container-files/create_container.sh`
Change the following parameters to match the just created image:
```bash
IMAGE_FORK=fil-physics        # Docker image from which the container ...
IMAGE_VERSION=V1             # ... will be created
```
Define container version:
```bash
CONTAINER_SUFFIX=1_my_container				# container version
```
Specify `gadgetron-matlab-share` fork, commit and MATLAB version:
```bash
GAD_MAT_FORK=fil-physics        # GitHub fork (e.g. fil-physics or your GitHub username)
GAD_MAT_VERSION=80b7393      # Commit of gadgetron_matlab_share
MATLAB_VERSION=R2022b        # Matlab application version
```
Specify a mount point from where you will feed your data in and out of the container via `-v` option (example here `/hostshare` is the mounting point).
Specify where your MATLAB installation is also via -v option.
Specify DISPLAY and number of CPUs available for recon.
```bash
sudo docker create --gpus all --name=${CONTAINER_NAME} --net=host \
	-v /hostshare:/hostshare \
	-v /usr/local/MATLAB:/usr/local/MATLAB \
	-e DISPLAY=:0.0 \
       --cpuset-cpus=0-23 \
```
**WARNING: within a container you will have root access to the `/hostshare` directory - use with care!**

2. Execute `create_container.sh` script.
In the above example this will create container with the name: `fil-physics-V1.1_my_container`

## MORSE Image Reconstruction - How to Use
1. Put the raw k-space data in the directory accessible from within the container. In above example it is  `/hostshare`.
2. Convert your raw k-space data (.dat) into ismrmrd format (.h5). Here is an example how to convert Siemens data on Linux-based OS (Ubuntu):
```bash
sudo docker exec fil-physics-V1.1_my_container bash -c " \
	siemens_to_ismrmrd -f raw_kspace.dat		-o raw_kspace.h5 		-m parameter_map.xml -x parameter_stylesheet.xsl"
```
We provide example `parameter_map.xml` and `parameter_stylesheet.xsl`, which works with our in-house SPGR sequence at 3T and 7T and Siemens SWI product sequence at 7T: .....add path....

3. Start MORSE reconstruction using k-space data in ismrmrd format as input:
```bash
sudo docker exec -it fil-physics-V1.1_my_container bash -ic "export DISPLAY=${DISPLAY}; gadgetron -p9888 -s 9111 -D \"/root/.gadgetron/storage/database-FIL\" & (sleep 4; \
	gadgetron_ismrmrd_client -f raw_kspace.h5 -o reconstructed_image.h5 -c ReconMPM.xml -G ima -p9888"
 ```
`ReconMPM.xml` provides a list of reconstruction steps including gadgetron readers and writers, gadgets such as noise adjustment and removing readout oversampling before the actual MORSE reconstruction, which is programmed in MATLAB.
Based on `ReconMPM.xml` you can create your own reconstruction pipelines and put it in `gadgetron-matlab-share/FIL-recon` folder. Any xml file stored there will be added to gadgetron xml recon path during the process of container creation and you will be able to call it using `gadgetron_ismrmrd_client -c` option.

Your output `reconstructed_image.h5` will be MORSE reconstructed image in ismrmrd format.
If you would like to have it in nifti format we provide an extra `h5_to_nifti.m` converter in `gadgetron-matlab-share/FIL-recon folder`.
