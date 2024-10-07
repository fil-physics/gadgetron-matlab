# FIL Physics MORSE Image Reconstruction

This repository contains MATLAB code for use with Gadgetron that implements the MORSE algorithm for MRI image reconstruction described in the following manuscript: 

**"MORSE CODE: Multiple Orthogonal Reference Sensitivity Encoding Combined Over Dominant Eigencoils" by O. Josephs and B. Dymerska et al.**

If you use these scripts for your work, please cite this paper.

## Installation instructions
### Docker
This reconstruction is executed within a Docker container to isolate it and ensure reproducibility. To install Docker Engine for your specific environment, please refer to the official Docker website for instructions:
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
1. Edit `/gadgetron-matlab/FIL-recon/docker-containers/image-files/build_image.sh`

Specify a name for your image, by changing the following parameters:
```bash
IMAGE_FORK=fil-physics
IMAGE_VERSION=V16
```
IMAGE_FORK - specifies the fork of the gadgetron repository, we tested functionality based on the fil-physics fork #0178603, which is not up-to-date with the parent repository but can provide a starting point for use of the MORSE reconstruction.

IMAGE_VERSION - tested based on fil-physics:V16, but can be chosen arbitrarily by the user.

2. Execute the `build_image.sh` script.

### Creating Docker Container
1. Edit `/gadgetron-matlab/FIL-recon/docker-containers/container-files/create_container.sh`
Change the following parameters to match the created image (if changes made above):
```bash
IMAGE_FORK=fil-physics        # Docker image from which the container ...
IMAGE_VERSION=V16             # ... will be created
```
Define container version:
```bash
CONTAINER_SUFFIX=0_public_rc1				# container version
```
Specify `gadgetron-matlab` fork, commit and MATLAB version:
```bash
GAD_MAT_FORK=fil-physics        # GitHub fork (e.g. fil-physics or your GitHub username)
GAD_MAT_VERSION=cbcffff      # Commit of gadgetron_matlab
MATLAB_VERSION=R2022b        # Matlab application version
```
Specify via `-v` option:
- a mount point from where you will feed your data in and out of the container (example here `/hostshare` is the mounting point).
- where your MATLAB installation is.

Specify DISPLAY and number of CPUs available for recon.
```bash
sudo docker create --gpus all --name=${CONTAINER_NAME} --net=host \
	-v /hostshare:/hostshare \
	-v /usr/local/MATLAB:/usr/local/MATLAB \
	-e DISPLAY=:0.0 \
       --cpuset-cpus=0-23 \
```
**WARNING: within a container you will have root access to the `/hostshare` and `/usr/local/MATLAB` directories - use with care!**

2. Execute `create_container.sh` script.
The above example will create a container with the name: `fil-physics-V16.0_public_rc1`

## MORSE Image Reconstruction Usage
1. Put the raw k-space data in a directory accessible from within the container. In the above example that would be any directory within  `/hostshare`.
2. Convert your raw k-space data (e.g. *.dat on Siemens) into ismrmrd format (.h5). Here is an example of how to convert Siemens data on a Linux-based OS (Ubuntu):
```bash
sudo docker exec fil-physics-V16.0_public_rc1 bash -c "siemens_to_ismrmrd -f [input path to]/raw_kspace.dat -o [output path to]/raw_kspace.h5 -m code/github/fil-physics/gadgetron-matlab/FIL-recon/scanner_xml_xsl/parameter_map.xml -x code/github/fil-physics/gadgetron-matlab/FIL-recon/scanner_xml_xsl/parameter_stylesheet.xsl"
```
We provide examples of `parameter_map.xml` and `parameter_stylesheet.xsl` in the gadgetron-matlab/FIL-recon/scanner_xml_xsl folder:
- `IsmrmrdParameterMap_Siemens_MPM.xml` and `IsmrmrdParameterMap_Siemens_MPM.xsl` work with single or multi-echo gradient echo data, e.g. the Siemens product sequence for SWI or 3D FLASH for Multi-Parameter Mapping, which is publicly available for the VE11c software version [here](https://xip.uclb.com/product/mri-pulse-sequence-for-a-multi-echo-spoiled-gradient-echo).

- `IsmrmrdParameterMap_Siemens_BSS.xml` and `IsmrmrdParameterMap_Siemens_BSS.xsl` works with a Bloch-Siegert based B1+ mapping sequence. A sequence for the VE12u software version is publicly available [here](https://xip.uclb.com/product/mri-pulse-sequence-for-b1).


3. Start MORSE reconstruction using k-space data in ismrmrd format as input.

For MPM (SPGR) reconstruction:
```bash

sudo docker exec -it fil-physicsc-V16.0_public_rc1 bash -ic "export DISPLAY=${DISPLAY}; gadgetron -p9888 -s 9111 -D "/root/.gadgetron/storage/my-database" & (sleep 4; gadgetron_ismrmrd_client -f raw_kspace.h5 -o reconstructed_image.h5 -c ReconMPM.xml -G ima -p9888)"
 ```

For B1+ reconstruction:
```bash
sudo docker exec -it fil-physicsc-V16.0_public_rc1 bash -ic "export DISPLAY=${DISPLAY}; gadgetron -p9888 -s 9111 -D "/root/.gadgetron/storage/my-database" & (sleep 4; gadgetron_ismrmrd_client -f raw_kspace.h5 -o reconstructed_image.h5 -c BSS_matlab.xml -G ima -p9888)" 
 ```
`ReconMPM.xml` and `BSS_matlab.xml` provide a list of reconstruction steps including gadgetron readers and writers, gadgets such as noise adjustment and removing readout oversampling before the actual MORSE reconstruction, which is programmed in MATLAB.
Based on `ReconMPM.xml` or `BSS_matlab.xml` you can create your own reconstruction pipelines and put it in `gadgetron-matlab/FIL-recon` folder. Any xml file stored there will be added to gadgetron xml recon path during the process of container creation and you will be able to call it using `gadgetron_ismrmrd_client -c` option.

Your output `reconstructed_image.h5` will be a MORSE reconstructed image in ismrmrd format.
If you would like to have it in nifti format we provide an extra `h5_to_nifti.m` converter in the `gadgetron-matlab/FIL-recon` folder.
