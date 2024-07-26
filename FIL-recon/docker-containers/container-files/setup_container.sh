#!/bin/bash

user=$1			# gadgetron-matlab user e.g. fil-physics  # For github
gad_matV=$2		# e.g. 1900083a562b98a176658ebc741c1b8f247e8285
mV=$3			# e.g. R2022b 	  # Matlab version

# exit on error
set -e

# X Authority from bind mounted /home/mr
# Explicitly refernce /root so will fail if accidently executed as user on host
echo export XAUTHORITY=/mnt/.Xauthority >> /root/.bashrc

# Clone matlab gadget repo
mkdir -p /opt/code/github/${user}/
cd /opt/code/github/${user}/
git clone https://github.com/${user}/gadgetron-matlab.git 

# Rename remote to facilitate experimentation and checkout specific version
cd gadgetron-matlab
git remote rename origin gh_${user}_gad_mat
git checkout ${gad_matV}

# Path for Matlab to find gadgetron.external.main and FIL-recon
echo export MATLABPATH=$(pwd):$(pwd)/FIL-recon >> /root/.bashrc

# Link FIL-recon xml's to Gadgetron xml recon path
ln -sv $(pwd)/FIL-recon/*.xml /usr/local/share/gadgetron/config

# Update javaclasspath with gadgetron-matlab java class for socketwrapper
ln -s /usr/local/MATLAB/${mV}/bin/matlab /usr/local/bin/matlab
mkdir -p /root/.matlab/${mV}
cd /root/.matlab/${mV}
echo /opt/code/github/${user}/gadgetron-matlab/java > javaclasspath.txt

# Matlab Java heap and echo UI options
cat <<EOF > matlab.prf
JavaMemHeapMax=I4096
CurrentKeyBindingSet=SWindows
GeneralAntialiasDesktopFonts=Btrue
EOF
