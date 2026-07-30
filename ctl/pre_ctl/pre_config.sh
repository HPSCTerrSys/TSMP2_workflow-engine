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

parse_config_file ${conf_file} "pre_config_clm"

# directories
lsmforcgensrc_dir=${lsmforcgensrc_dir:-${ctl_dir}/../src/eCLM_atmforcing/mkforcing}
eclmfrc_dir=${eclmfrc_dir:-${frc_dir}/eclm/forcing/}
cdsapi_dtadir=${cdsapi_dtadir:-${ctl_dir}/../src/eCLM_atmforcing/mkforcing/cdsapidwn}

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
if [ ${#listfrcfile[@]} -eq 0 ]; then
   echo "No Forcing needs to be processed. " && exit 1
fi
#unset listfrcfile[-1]

echo "List of forcing files: "${listfrcfile[@]}

fi

####################
# PDAF
####################
if [[ "${modelid}" == *pdaf* ]]; then

parse_config_file ${conf_file} "pre_config_pdaf"

# ---------------------------------------------------------------------------
# Perturb atmospheric forcing
# ---------------------------------------------------------------------------
num_ensemble=${num_ensemble:-50}

if [[ "${modelid}" == *clm* ]]; then

lsmforcpertsrc_dir=${lsmforcpertsrc_dir:-${ctl_dir}/../src/eCLM_atmforcing/mkperturb}
eclmfrc_dir=${eclmfrc_dir:-${frc_dir}/eclm/forcing/}
pdaffrc_dir=${pdaffrc_dir:-${eclmfrc_dir}}

check_var_def pre_config_pdaf_env $(find ${lsmforcpertsrc_dir}/../ -type f -name "*sh") "Using environment file "

pyvenv_pre_config_pdaf=${pyvenv_pre_config_pdaf:-${ctl_dir}/virtualenvs/pyenv_pre_config_pdaf}

# load environment
source ${pre_config_pdaf_env}

# create virtual env if it does not exist yet
if [ ! -d "${pyvenv_pre_config_pdaf}" ]; then
   echo "Virtual env not found at ${pyvenv_pre_config_pdaf}, installing "
   python -m venv ${pyvenv_pre_config_pdaf}
   source ${pyvenv_pre_config_pdaf}/bin/activate
   pip install ${ctl_dir}/../src/eCLM_atmforcing/
   deactivate
fi

fi # clm
fi # pdaf

if ${debugmode}; then

# create job submission script (pre.job)
echo "#!/usr/bin/env bash" > pre.job
echo "$(sched_directive_prefix) ${jobprestring//[$'\t\r\n']}" >> pre.job

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

