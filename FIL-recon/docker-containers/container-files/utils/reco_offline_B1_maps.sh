# this is a script for retro-recon of B1 maps
# it runs with remote connection to the server and for retro-recon without Siemens console
# to enable remote reconstruction it overwrites the display variable in container, which is currently set to run correctly when you use X-server on the hostmachine (the actual physical display on the host machine), but not remotely and not as root

#### USER variables ####
# specify a container with change in BSS_classic_or_GLM_B1map.m
# 	from
#	lname={header.userParameters.userParameterLong.name};
#	lvalue=[header.userParameters.userParameterLong.value];
#	to
# 	lname={header.userParameters.userParameterDouble.name};
# 	lvalue=[header.userParameters.userParameterDouble.value]; 
ref_container=fil-physicsc-V13.3_bkd
b1_files=`ls /hostshare/barbara/retro_recon/BSS_twix2proc/???/*.dat`
b1_xml=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_BSS.xml
# specify xsl file with lines 908 & 913 & 915 & 920 changed from userParameterLong to userParameterDouble  --> this refers to variables BSPulseDuration and NbchoesBeforeBSPulse
b1_xsl=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_BSS.xsl
b1_reco_xml=BSS_matlab.xml

#### END of user variables ####


# allow root over ssh -X
sudo xauth add $(xauth -f ~/.Xauthority list | tail -1)
sudo docker restart -t 0 ${ref_container}


for dat_file in $b1_files
do

	if [[ -f ${dat_file%%[.]*}.h5  ]]; then  
		rm -f ${dat_file%%[.]*}.h5
		rm -f ${dat_file%%[.]*}_ima.h5
	fi

	sudo docker exec ${ref_container} bash -c "siemens_to_ismrmrd -f ${dat_file} -o ${dat_file%%[.]*}.h5 -m ${b1_xml} -x ${b1_xsl}"
	
# export DISPLAY=${DISPLAY} --> redirect graphics to ssh -X tunnel
# bash -i --> ensure .bashrc is run for MATLAB environmental settup
	sudo docker exec ${ref_container} bash -ic "export DISPLAY=${DISPLAY}; gadgetron -p9880 -E1.2.3.4 & (sleep 4; \
	gadgetron_ismrmrd_client -f ${dat_file%%[.]*}.h5 -o ${dat_file%%[.]*}_ima.h5  -p9880 -c ${b1_reco_xml} -G img) ; pkill gadgetron"

done





