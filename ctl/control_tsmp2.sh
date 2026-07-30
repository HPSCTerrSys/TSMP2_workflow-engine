#!/usr/bin/env bash
# Control-script and starter for TSMP2 Workflow engine (TSMP2-WFE)
# for preprocessing, simulation, postprocessing, monitoring, cleaning/archiving
#
# Author(s): Stefan Poll (s.poll@fz-juelich.de)

# exit with error, export variables
set -aeo pipefail

###########################################

echo "#####"
echo "## Start TSMP WFE"
echo "#####"

# set control directory
ctl_dir=$(dirname $(realpath ${BASH_SOURCE:-$0}))

# Import function
source ${ctl_dir}/utils_tsmp2.sh

###
# Master-settings
###

# load master conf
parse_config_file "master.conf"

# config file
conf_file=${conf_file:-${ctl_dir}/expid.conf}

echo "Conf_file: ${conf_file}"

###########################################

###
# Start of script
###

# set modelid, caseid and expid
modelid=$(echo ${MODEL_ID//"-"/} | tr '[:upper:]' '[:lower:]')
if [ -n "${CASE_ID}" ]; then caseid+=${CASE_ID,,}"_"; fi
expid=${EXP_ID,,}

# set path (not run-dir)
nml_dir=$(realpath ${ctl_dir}/../nml/)
geo_dir=$(realpath ${ctl_dir}/../dta/geo/)
frc_dir=$(realpath ${ctl_dir}/../dta/forcing/)
out_dir=$(realpath ${ctl_dir}/../dta/simres/)
rst_dir=$(realpath ${ctl_dir}/../dta/restart/)
log_dir=$(realpath ${ctl_dir}/logs/)
echo "ctl_dir: "${ctl_dir}
echo "nml_dir: "${nml_dir}
echo "geo_dir: "${geo_dir}

# select machine defaults, if not set by user
if [ "${SYSTEMNAME}" == "juwels" ]; then
check_var_def npnode 48 "Taking user setting for npnode "
check_var_def partition batch "Taking user setting and partition "
elif [ "${SYSTEMNAME}" == "jurecadc" ]; then
check_var_def npnode 128 "Taking user setting for npnode "
check_var_def partition dc-cpu "Taking user setting and partition "
elif [ "${SYSTEMNAME}" == "jusuf" ]; then
check_var_def npnode 128 "Taking user setting for npnode "
check_var_def partition batch "Taking user setting and partition "
elif [ "${SYSTEMNAME}" == "jupiter" ]; then
check_var_def npnode 288 "Taking user setting for npnode "
check_var_def partition booster "Taking user setting and partition "
else
if [ -z "$npnode" ]; then
echo "No npnode for machine '$SYSTEMNAME'. Please set npnode manually in master.conf. Valid machine defaults for juwels/jurecadc/jusuf/jupiter."
fi
if [ -z "$partition" ] && [ "${scheduler:-slurm}" != "local" ]; then
echo "No partition/queue for machine '$SYSTEMNAME'. Please set partition manually in master.conf. Valid machine defaults for juwels/jurecadc/jusuf/jupiter."
fi
fi
account_def=${BUDGET_ACCOUNTS:-slts}
check_var_def account ${account_def} "WARNING: No account is set. Using account="
check_var_def tsmp2_dir $(realpath  ${ctl_dir}/../src/TSMP2) "Taking TSMP2 default dir at "
check_var_def tsmp2_install_dir ${tsmp2_dir}/bin/${SYSTEMNAME^^}_${MODEL_ID} \
              "Taking TSMP2 component binaries from default dir at "
check_var_def tsmp2_env $(find ${tsmp2_install_dir}/ -type f -name "*mpi") "Using environment file "
check_var_def scheduler slurm "Using job scheduler="

# generic job-submission string (scheduler-specific: sbatch or qsub options)
if [[ "${scheduler}" == "pbs" ]]; then
  jobgenstring="-A ${account} \
                -q ${partition} \
                -m $(sched_pbs_mailcode) \
                ${mailaddress:+-M ${mailaddress}} \
                -V"
elif [[ "${scheduler}" == "local" ]]; then
  # no queue, no account/partition/mail options: sched_submit runs jobs directly
  jobgenstring=""
else
  jobgenstring="--export=ALL \
                --account=${account} \
                --partition=${partition} \
                --mail-type=${mailtype} \
                --mail-user=${mailaddress} \
                ${reservation:+--reservation=${reservation}}"
fi

# convert arrays to string for job script
lprestr="${lpre[@]}"
lsimstr="${lsim[@]}"
lposstr="${lpos[@]}"
lvisstr="${lvis[@]}"

# check for oasis active
run_oasis=$(check_run_oasis)

###
# Loop over time period
###

icounter=0
while [ $icounter -lt $numsimstep ]
do

# time information
datep1=$(date -u -d -I "+${startdate} + ${simlength}")
datem1=$(date -u -d -I "+${startdate} - ${simlength}")
simlensec=$(( $(date -u -d "${datep1}" +%s)-$(date -u -d "${startdate}" +%s) ))
simlenhr=$(($simlensec/3600 | bc -l))
simlenmon=$(( (10#$(date -u -d "${datep1}" +%Y)-10#$(date -u -d "${startdate}" +%Y))*12 + \
               10#$(date -u -d "${datep1}" +%m)-10#$(date -u -d "${startdate}" +%m) ))
dateymd=$(date -u -d "${startdate}" +%Y%m%d)
dateshort=$(date -u -d "${startdate}" +%Y%m%d%H%M%S)

# set run path
sim_dir=$(realpath ${ctl_dir}/../run/sim_${caseid}${modelid}_${dateymd}/)
#sim_dir=$(realpath ${ctl_dir}/../run/${SYSTEMNAME}_${modelid}_${dateymd}/)
pre_dir=$(realpath ${ctl_dir}/../run/pre_${caseid}${modelid}_${dateymd}/)

echo "==="
echo "Date: $dateshort"
echo "==="

#####
## Preprocessing
#####

# check if any is true
if [[ ${lpre[*]} =~ true ]]; then

jobname_pre="${expid}_${caseid}pre_${dateshort}"
jobprestring="${jobgenstring} $(sched_step_opts "${jobname_pre}" "${pre_wallclock}" 1 "${npnode}")"

# Submit to pre.job
if (! ${debugmode}) ; then
  # Submit to sim.job
  submit_pre=$(sched_submit "${jobname_pre}" "${jobprestring}" "${ctl_dir}/pre_ctl/pre.job")
  echo $submit_pre" for preprocessing"
else
  # Set lpre run & cleanup to false and source pre.job
  lpre[1]=false
  lpre[2]=false
  lprestr="${lpre[@]}"
  source ${ctl_dir}/pre_ctl/pre.job
fi

# get jobid
pre_id=$(sched_parse_jobid "$submit_pre")

fi # $lpre

######
## Simulations
######

# check if any is true
if [[ ${lsim[*]} =~ true ]]; then

# Calculate number of procs for TSMP2 simulation (utils)
sim_calc_numberofproc

# set dependency
if ${lpre[2]} ; then
  dependencystring="afterok:${pre_id}"
  if [[ $icounter -gt 0 ]] ; then
    dependencystring="${dependencystring}:${sim_id}"
  fi
else
  if [[ $icounter -gt 0 ]] ; then
    dependencystring="afterok:${sim_id}"
  else
    dependencystring=$prevjobid
  fi
fi # lpre

#
jobname_sim="${expid}_${caseid}sim_${dateshort}"
jobsimstring="${jobgenstring} $(sched_step_opts "${jobname_sim}" "${sim_wallclock}" "${tot_node}" "${tot_proc}") \
              $(sched_dependency_opt "${dependencystring}")"

if (! ${debugmode}) ; then
  # Submit to sim.job
  submit_sim=$(sched_submit "${jobname_sim}" "${jobsimstring}" "${ctl_dir}/sim_ctl/sim.job")
  echo $submit_sim" for simulation"
else
  # Set lsim run & cleanup to false and source sim.job
  lsim[1]=false
  lsim[2]=false
  lsimstr="${lsim[@]}"
  source ${ctl_dir}/sim_ctl/sim.job
fi

# get jobid
sim_id=$(sched_parse_jobid "$submit_sim")

fi # $lsim

######
## Postprocessing
######

# check if any is true
if [[ ${lpos[*]} =~ true ]]; then

# set dependency
if ${lsim[2]} ; then
  dependencystring="afterok:${sim_id}"
else
  dependencystring=$prevjobid
fi

# Configure TSMP2 Postprocessing
jobname_pos="${expid}_${caseid}pos_${dateshort}"
jobposstring="${jobgenstring} $(sched_step_opts "${jobname_pos}" "${pos_wallclock}" 1 "${npnode}") \
              $(sched_dependency_opt "${dependencystring}")"

# Submit to pos.job
submit_pos=$(sched_submit "${jobname_pos}" "${jobposstring}" "${ctl_dir}/pos_ctl/pos.job")
echo $submit_pos" for postprocessing"

# get jobid
pos_id=$(sched_parse_jobid "$submit_pos")

fi # $lpos

######
## Visualization
######

# check if any is true
if [[ ${lvis[*]} =~ true ]]; then

# set dependency
if ${lpos[2]} ; then
  dependencystring="afterok:${pos_id}"
else
  dependencystring=$prevjobid
fi

# Configure TSMP2 Postprocessing
jobname_vis="${expid}_${caseid}vis_${dateshort}"
jobvisstring="${jobgenstring} $(sched_step_opts "${jobname_vis}" "${vis_wallclock}" 1 "${npnode}") \
              $(sched_dependency_opt "${dependencystring}")"

# Submit to vis.job
submit_vis=$(sched_submit "${jobname_vis}" "${jobvisstring}" "${ctl_dir}/vis_ctl/vis.job")
echo $submit_vis" for visualization"

# get jobid
vis_id=$(sched_parse_jobid "$submit_vis")

fi # $lvis

###
# Loop increment
###

startdate=$(date -u -d "${startdate} +${simlength}" "+%Y-%m-%dT%H:%MZ")
icounter=$((icounter+1))
#(( icounter++ ))

done # icounter

exit 0
