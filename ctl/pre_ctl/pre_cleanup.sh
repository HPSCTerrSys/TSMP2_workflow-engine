#!/usr/bin/env bash
#
# function to configure tsmp2 cleanup

pre_cleanup(){

echo "Start Pre-processing cleanup"

job_id=$(sched_job_id)
job_name=$(sched_job_name)

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
if [[ "${scheduler}" == "pbs" ]]; then
  mv ${log_dir}/${job_name}.{e,o}${job_id} ${eclmfrc_dir}/log/${job_name}_${job_id}.out
else
  mv ${log_dir}/${job_name}_${job_id}.{err,out} ${eclmfrc_dir}/log/.
fi

# remove working directory
rm -rf ${pre_dir:?}

} # pre_cleanup
