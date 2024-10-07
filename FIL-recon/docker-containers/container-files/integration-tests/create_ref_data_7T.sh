#!/bin/bash
# this script creates reference reconstructed datasets for integration testing

# Reference container full name
ref_container=fil-physicsc-V15.9_bkd_rc1

# list of user parameter maps and stylesheets
epi_xml=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens.xml
epi_xsl=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_EPI_wip_VE12_FIRE.xsl
mpm_xml=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_MPM.xml
mpm_xsl=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_MPM.xsl
bss_xml=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_BSS.xml
bss_xsl=/hostshare/Gadgetron_XML/IsmrmrdParameterMap_Siemens_BSS.xsl

# list of reference directories 
data_dir=/hostshare/container_test_data
epi_dir=M700298_20211203
mpm_dir=M700213_20210714

#list of reference dat files excluding the "dat" extension
epi_fmri_file=meas_MID00093_FID19170_nc_epi3d_v2q_0p92mm_PAT4x2_PF68
epi_wb_file=meas_MID00095_FID19172_nc_epi3d_v2q_0p92mm_PAT4_WB_Fermi
mpm_pdw_file=meas_MID00064_FID10787_pdw_mfc_3dflash_v1k
mpm_mtw_file=meas_MID00070_FID10793_mtw_mfc_3dflash_v1k_180deg
bss_b1_file=meas_MID00067_FID10790_mfc_bloch_siegert_v1b_190deg_2ms_Classic

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

epi_wb_dat=${data_dir}/dats/${epi_dir}/${epi_wb_file}.dat
epi_wb_h5=${epi_refdir}/${epi_wb_file}.h5
epi_wb_ima_h5=${epi_refdir}/ima_${epi_wb_file}.h5

mpm_pdw_dat=${data_dir}/dats/${mpm_dir}/${mpm_pdw_file}.dat
mpm_pdw_h5=${mpm_refdir}/${mpm_pdw_file}.h5
mpm_pdw_ima_h5=${mpm_refdir}/ima_${mpm_pdw_file}.h5

mpm_mtw_dat=${data_dir}/dats/${mpm_dir}/${mpm_mtw_file}.dat
mpm_mtw_h5=${mpm_refdir}/${mpm_mtw_file}.h5
mpm_mtw_ima_h5=${mpm_refdir}/ima_${mpm_mtw_file}.h5

bss_b1_dat=${data_dir}/dats/${mpm_dir}/${bss_b1_file}.dat
bss_b1_h5=${mpm_refdir}/${bss_b1_file}.h5
bss_b1_ima_h5=${mpm_refdir}/ima_${bss_b1_file}.h5

# Allow root over ssh -X
sudo xauth add $(xauth -f ~/.Xauthority list | tail -1)

# Starting/restarting the container:
sudo docker restart -t 0 ${ref_container}

# Conversion of the raw datasets to h5 format:
sudo docker exec ${ref_container} bash -c " \
	siemens_to_ismrmrd -f ${epi_fmri_dat}		-o ${epi_fmri_h5}		-m ${epi_xml} -x ${epi_xsl}; \
	siemens_to_ismrmrd -f ${epi_wb_dat} 		-o ${epi_wb_h5}		-m ${epi_xml} -x ${epi_xsl}; \
	siemens_to_ismrmrd -f ${mpm_pdw_dat}		-o ${mpm_pdw_h5}		-m ${mpm_xml} -x ${mpm_xsl}; \
	siemens_to_ismrmrd -f ${mpm_mtw_dat}		-o ${mpm_mtw_h5}		-m ${mpm_xml} -x ${mpm_xsl}; \
	siemens_to_ismrmrd -f ${bss_b1_dat}		-o ${bss_b1_h5}		-m ${bss_xml} -x ${bss_xsl}"


# Image reconstruction:
sudo docker exec -it ${ref_container} bash -ic "export DISPLAY=${DISPLAY}; gadgetron -p9888 -s 9111 -D \"/root/.gadgetron/storage/database-FIL\" & (sleep 4; \
	gadgetron_ismrmrd_client -f ${epi_fmri_h5} -o ${epi_fmri_ima_h5} -c fMRI_3DEPI.xml -G ima -p9888; \
	gadgetron_ismrmrd_client -f ${epi_wb_h5} -o ${epi_wb_ima_h5} -c fMRI_3DEPI.xml -G ima -p9888; \
	gadgetron_ismrmrd_client -f ${mpm_pdw_h5} -o ${mpm_pdw_ima_h5} -c ReconMPM.xml -G ima -p9888; \
	gadgetron_ismrmrd_client -f ${mpm_mtw_h5} -o ${mpm_mtw_ima_h5} -c ReconMPM.xml -G ima -p9888; \
	gadgetron_ismrmrd_client -f ${bss_b1_h5} -o ${bss_b1_ima_h5} -c BSS_matlab.xml -G ima -p9888)"


# Stopping the reference container
sudo docker stop ${ref_container}

