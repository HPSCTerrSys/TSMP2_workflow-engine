#!/usr/bin/env bash

sim_cleanup(){

echo "###"
echo "# Cleanup Simulation"
echo "###"

job_id=$(sched_job_id)
job_name=$(sched_job_name)

parse_config_file ${conf_file} "sim_clean_general"

file_op_mode=${file_op_mode:-"copy"}

file_op() {
    if [ "$file_op_mode" = "move" ]; then
        mv -v "$@"
    else
        cp -v "$@"
    fi
}

simout_dir=${out_dir}/${caseid}${modelid}_${dateymd}
simrst_dir=${rst_dir}/${caseid}${dateymd}

# create a new simulation output directory
if [ -e "${simout_dir}" ]; then
  mv ${simout_dir} ${simout_dir}_bku$(date '+%Y%m%d%H%M%S')
fi
mkdir -p "${simout_dir}"

echo "Moving model output to simout and storing restart files"

mkdir -p "${simout_dir}/log" "${simout_dir}/nml" "${simout_dir}/rst" "${simout_dir}/bin"

file_op ${tsmp2_env} ${simout_dir}/bin/

if [[ "${MODEL_ID}" == *-* ]]; then
  file_op ${sim_dir}/namcouple ${simout_dir}/nml/
fi # MODEL_ID oasis

if [[ "${modelid}" == *icon* ]]; then
  # Namelist
  file_op ${sim_dir}/NAMELIST_icon ${simout_dir}/nml/
  file_op ${sim_dir}/icon_master.namelist ${simout_dir}/nml/

  # Model output
  mkdir -p ${simout_dir}/out/icon
  file_op ${sim_dir}/ICON_out_* ${simout_dir}/out/icon

  # Model log
  file_op ${sim_dir}/nml.atmo.log ${simout_dir}/log/
  file_op ${sim_dir}/*.dat ${simout_dir}/log/

  # Restart
  mkdir -p ${simout_dir}/rst/icon ${simrst_dir}/icon
  file_op ${sim_dir}/${expid}_restart_ATMO_*.nc  ${simout_dir}/rst/icon
  file_op ${sim_dir}/${expid}_restart_ATMO_*.nc  ${simrst_dir}/icon # save twice as simout is archived

  # copy binary
  file_op icon ${simout_dir}/bin/

fi # icon

if [[ "${modelid}" == *clm* ]]; then
  # Namelist
  file_op ${sim_dir}/*_in ${simout_dir}/nml/
  file_op ${sim_dir}/datm.* ${simout_dir}/nml/

  # Model output
  mkdir -p ${simout_dir}/out/eclm
  file_op ${sim_dir}/eCLM_*.clm2.h* ${simout_dir}/out/eclm

  # Model log
  file_op ${sim_dir}/logs/${job_id}.comp_*.log ${simout_dir}/log/
  file_op ${sim_dir}/timing/model_timing_stats ${simout_dir}/log/

  # Restart
  mkdir -p ${simout_dir}/rst/eclm ${simrst_dir}/eclm
  file_op ${sim_dir}/eCLM_*.clm2.r* ${simout_dir}/rst/eclm
  file_op ${sim_dir}/eCLM_*.clm2.r* ${simrst_dir}/eclm # save twice as simout is archived

  # Copy binary
  file_op eclm ${simout_dir}/bin/

fi # clm

if [[ "${modelid}" == *parflow* ]]; then

  # Namelist
  file_op ${sim_dir}/coup_oas.tcl ${simout_dir}/nml/

  # Model output
  mkdir -p ${simout_dir}/out/parflow
  file_op ${sim_dir}/*.out.?????.nc ${simout_dir}/out/parflow

  # Model log
  file_op ${sim_dir}/*out.kinsol.log ${simout_dir}/log/
  file_op ${sim_dir}/*out.log ${simout_dir}/log/
  file_op ${sim_dir}/*out.timing* ${simout_dir}/log/

  # Restart
  mkdir -p ${simout_dir}/rst/parflow ${simrst_dir}/parflow
  pflnout=$(echo "( ((${simlenhr}/${pfloutfrq}) + ${pfloutmfilt} -1) / ${pfloutmfilt})" | bc)
  pflnlast=$(printf "%05d" $(echo "1 + (${pflnout} -1) * ${pfloutmfilt}" | bc))
#  cp -v $(ls -1 ${sim_dir}/*.out.?????.nc | tail -1) ${simout_dir}/rst/parflow
  # save twice as simout is archived
  file_op ${sim_dir}/${EXP_ID}.out.${pflnlast}.nc ${simout_dir}/rst/parflow
  file_op ${sim_dir}/${EXP_ID}.out.${pflnlast}.nc ${simrst_dir}/parflow/${EXP_ID}.out.$(date -u -d "${datep1}" +%Y%m%d%H%M%S).nc # 2nd copy

  # Copy binary
  file_op parflow ${simout_dir}/bin/

fi # parflow

file_op ${sim_dir}/${mpmd_mapping_file} ${simout_dir}/log/

# sim logs
if [[ "${scheduler}" == "pbs" ]]; then
  mv ${log_dir}/${job_name}.{e,o}${job_id} ${simout_dir}/log/${job_name}_${job_id}.out
else
  mv ${log_dir}/${job_name}_${job_id}.{err,out} ${simout_dir}/log/.
fi

# job info
case "${scheduler}" in
  slurm) echo $(scontrol show job ${job_id}) > ${simout_dir}/log/job_info.log ;;
  pbs)   qstat -f ${job_id} > ${simout_dir}/log/job_info.log 2>&1 ;;
  local) echo "local job ${job_name} (id ${job_id}) ran on $(hostname) at $(date)" > ${simout_dir}/log/job_info.log ;;
  *)     echo $(scontrol show job ${job_id}) > ${simout_dir}/log/job_info.log ;;
esac

# remove run directory
rm -rf ${sim_dir:?}

} # sim_cleanup
