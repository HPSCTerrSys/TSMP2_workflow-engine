#!/usr/bin/env bash
#
# function to configure tsmp2 cleanup

pre_cleanup(){

echo "Start Pre-processing cleanup"

####################
# CLM
####################
if [[ "${modelid}" == *clm* ]]; then

echo "clean-up clm forcing"

for idate in ${listfrcfile[@]}; do
  ifile=${pre_dir}/${idate}/${idate}.nc
  cp ${ifile} ${eclmfrc_dir}
done
unset ifile

fi

# move logs
mkdir -p ${eclmfrc_dir}/log/
mv ${log_dir}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}.{err,out} ${eclmfrc_dir}/log/.

# remove working directory
rm -rf ${pre_dir:?}

} # pre_cleanup
