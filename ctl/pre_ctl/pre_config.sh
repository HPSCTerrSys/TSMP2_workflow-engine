#!/usr/bin/env bash
#
# function to configure tsmp2 preprocessing

pre_config(){

echo "Start Pre-processing Config"

####################
# General
####################

# create a new simulation run directory
echo "pre_dir: "$pre_dir
if [ -e "${pre_dir}" ]; then
  mv ${pre_dir} ${pre_dir}_bku$(date '+%Y%m%d%H%M%S')
fi
mkdir -p $pre_dir

# change to run directory
cd ${pre_dir}

####################
# CLM
####################
if [[ "${modelid}" == *clm* ]]; then

echo "start create clm forcing"

# directories
lsmforcgensrc_dir=${ctl_dir}/../src/eCLM_atmforcing/mkforcing
eclmfrc_dir=${frc_dir}/eclm/forcing/
cdsapi_dtadir=${ctl_dir}/../src/eCLM_atmforcing/mkforcing/cdsapidwn

# check if forcing files already exists
unset listfrcfile
if [ ! -e "${eclmfrc_dir}/$(date -u -d "${startdate}" +%Y-%m).nc" ]; then
   listfrcfile+=("$(date -u -d "${startdate}" +%Y-%m)")
fi
if [[ "${simlenmon}" -ge 1 ]]; then
   for imon in $(seq 1 $simlenmon);do
      dateloop=$(date -u -d "${startdate} +${imon} month" +%Y-%m)
      if [ ! -e "${eclmfrc_dir}/${dateloop}.nc" ]; then
	  listfrcfile+=("${dateloop}")
      fi
   done
fi

echo "List of forcing files: "${listfrcfile[@]}

fi


if ${debugmode}; then

# create job submission script (pre.job)
echo "#!/usr/bin/env bash" > pre.job
echo "#SBATCH ${jobprestring//[$'\t\r\n']}" >> pre.job

# add modelid, which is needed
echo "" >> pre.job
echo "modelid=${modelid}" >> pre.job
echo "lsmforcgensrc_dir=${lsmforcgensrc_dir}" >> pre.job
echo "cdsapi_dtadir=${cdsapi_dtadir}" >> pre.job
echo "listfrcfile=(${listfrcfile[*]})" >> pre.job

# cat pre run script into submission script
cat ${ctl_dir}/pre_ctl/pre_run.sh | tail -n +2 >> pre.job # start from line 2

sed -i "s/pre_run(){//" pre.job
sed -i "s/} # pre_run//" pre.job
sed -i "s#${log_dir}#${pre_dir}#g" pre.job

fi # debugmode

} # pre_config

