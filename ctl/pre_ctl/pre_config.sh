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

} # pre_config

