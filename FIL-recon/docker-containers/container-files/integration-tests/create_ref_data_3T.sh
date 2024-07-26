#!/bin/bash
# this script creates reference reconstructed datasets for integration testing

# Reference container full name
ref_container=fil-physicsc-V15.9_bkd_rc1

# list of user parameter maps and stylesheets
epi_xml=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens.xml
epi_xsl=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_EPI_wip_VE.xsl
mpm_xml=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_MPM.xml
mpm_xsl=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_MPM.xsl

# list of reference directories 
data_dir=/hostshare/container_test_data
epi_dir=MP03553_221109
mpm_dir=MP03553_221109

#list of reference dat files excluding the "dat" extension
epi_fmri_file=meas_MID00034_FID11887_nc_epi3d_v3e_3mm_48slices_1x2
mpm_pdw_highres_file=meas_MID00056_FID11876_pdw_mfc_3dflash_v3j_R4_64ch_gad
mpm_mtw_file=meas_MID00059_FID11874_mtw_mfc_3dflash_v3j_R4_64ch_gad
mpm_pdw_lowres_file=meas_MID00069_FID11880_pdw_mfc_3dflash_v3j_R4_64ch_gad


epi_refdir=${data_dir}/reconstructed_reference_images/${ref_container}/${epi_dir}
mpm_refdir=${data_dir}/reconstructed_reference_images/${ref_container}/${mpm_dir}

# to avoid appending reference .h5 files, the script exits if the reference data exist
if [ "$(ls -A ${epi_refdir} | grep -i \\.h5\$)" ] || [ "$(ls -A ${mpm_refdir} | grep -i \\.h5\$)" ]; then  
echo "reference data already exist, move or delete them before running";
exit
fi

# creating output folder structure
mkdir -p ${epi_refdir}
mkdir -p ${mpm_refdir}

# full paths to the data
epi_fmri_dat=${data_dir}/dats/${epi_dir}/${epi_fmri_file}.dat
epi_fmri_h5=${epi_refdir}/${epi_fmri_file}.h5
epi_fmri_ima_h5=${epi_refdir}/ima_${epi_fmri_file}.h5

mpm_pdw_highres_dat=${data_dir}/dats/${mpm_dir}/${mpm_pdw_highres_file}.dat
mpm_pdw_highres_h5=${mpm_refdir}/${mpm_pdw_highres_file}.h5
mpm_pdw_highres_ima_h5=${mpm_refdir}/ima_${mpm_pdw_highres_file}.h5

mpm_mtw_dat=${data_dir}/dats/${mpm_dir}/${mpm_mtw_file}.dat
mpm_mtw_h5=${mpm_refdir}/${mpm_mtw_file}.h5
mpm_mtw_ima_h5=${mpm_refdir}/ima_${mpm_mtw_file}.h5

mpm_pdw_lowres_dat=${data_dir}/dats/${mpm_dir}/${mpm_pdw_lowres_file}.dat
mpm_pdw_lowres_h5=${mpm_refdir}/${mpm_pdw_lowres_file}.h5
mpm_pdw_lowres_ima_h5=${mpm_refdir}/ima_${mpm_pdw_lowres_file}.h5

# Allow root over ssh -X
sudo xauth add $(xauth -f ~/.Xauthority list | tail -1)

# Starting/restarting the container:
sudo docker restart -t 0 ${ref_container}

# Conversion of the raw datasets to h5 format:
sudo docker exec ${ref_container} bash -c " \
	siemens_to_ismrmrd -f ${epi_fmri_dat}		-o ${epi_fmri_h5} 		-m ${epi_xml} -x ${epi_xsl}; \
	siemens_to_ismrmrd -f ${mpm_pdw_highres_dat}	-o ${mpm_pdw_highres_h5}	-m ${mpm_xml} -x ${mpm_xsl}; \
	siemens_to_ismrmrd -f ${mpm_mtw_dat} 		-o ${mpm_mtw_h5}		-m ${mpm_xml} -x ${mpm_xsl}; \
	siemens_to_ismrmrd -f ${mpm_pdw_lowres_dat}	-o ${mpm_pdw_lowres_h5}	-m ${mpm_xml} -x ${mpm_xsl};"


# Image reconstruction:
sudo docker exec -it ${ref_container} bash -ic "export DISPLAY=${DISPLAY}; gadgetron -p9888 -s 9111 -D \"/root/.gadgetron/storage/database-FIL\" & (sleep 4; \
	gadgetron_ismrmrd_client -f ${epi_fmri_h5} -o ${epi_fmri_ima_h5} -c fMRI_3DEPI.xml -G ima -p9888; \
	gadgetron_ismrmrd_client -f ${mpm_pdw_highres_h5} -o ${mpm_pdw_highres_ima_h5} -c ReconMPM.xml -G ima -p9888; \
	gadgetron_ismrmrd_client -f ${mpm_mtw_h5} -o ${mpm_mtw_ima_h5} -c ReconMPM.xml -G ima -p9888; \
	gadgetron_ismrmrd_client -f ${mpm_pdw_lowres_h5} -o ${mpm_pdw_lowres_ima_h5} -c ReconMPM.xml -G ima -p9888)"


# Stopping the reference container
sudo docker stop ${ref_container}

