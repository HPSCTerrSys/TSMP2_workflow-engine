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

# Large files that are genuinely in the run directory (model output, and the second
# leg of the restart, which is written twice on purpose) are moved rather than copied:
# the run directory and the data directories are on the same filesystem, so a move is
# a rename, while a copy reads and writes every byte. Set bulk_file_op_mode=copy in
# [sim_clean_general] to fall back to whatever file_op_mode says.
bulk_file_op_mode=${bulk_file_op_mode:-"move"}

bulk_op() {
    if [ "$bulk_file_op_mode" = "move" ]; then
        mv -v "$@"
    else
        file_op "$@"
    fi
}

# simulation status: failed if the model launch returned non-zero or, for ICON,
# if finish.status is missing (ICON writes OK or RESTART there only at a clean end)
sim_status=ok
if [[ "${sim_rc:-0}" -ne 0 ]]; then sim_status=failed; fi
if [[ "${modelid}" == *icon* ]] && ! grep -qsE "OK|RESTART" ${sim_dir}/finish.status; then
  sim_status=failed
fi
echo "Simulation status: ${sim_status} (model exit code: ${sim_rc:-not recorded})"
if [[ "${sim_status}" == "failed" ]]; then
  file_op_mode=copy      # keep the run directory complete for debugging
  bulk_file_op_mode=copy # likewise for the large files
  sim_exit=1             # sim.job exits non-zero, so the next chunk does not start
fi

simout_dir=${out_dir}/${caseid}${modelid}_${dateymd}
# a failed run gets its own marked directory and never takes the place of a good one
if [[ "${sim_status}" == "failed" ]]; then
  simout_dir=${simout_dir}_failed_${job_id}
fi
simrst_dir=${rst_dir}/${caseid}${dateymd}

# create a new simulation output directory
if [ -e "${simout_dir}" ]; then
  mv ${simout_dir} ${simout_dir}_bku$(date '+%Y%m%d%H%M%S')
fi
mkdir -p "${simout_dir}"

echo "Moving model output to simout and storing restart files"

mkdir -p "${simout_dir}/log" "${simout_dir}/nml" "${simout_dir}/rst" "${simout_dir}/bin"

# mark a failed run
if [[ "${sim_status}" == "failed" ]]; then
  { echo "status:        failed"
    echo "job id:        ${job_id}"
    echo "exit code:     ${sim_rc:-not recorded}"
    echo "finish.status: $(cat ${sim_dir}/finish.status 2>/dev/null || echo missing)"
    echo "run directory: ${sim_dir} (kept)"
    echo "written:       $(date '+%Y-%m-%dT%H:%M:%S')"
  } > ${simout_dir}/SIM_FAILED
fi

cp -v ${tsmp2_env} ${simout_dir}/bin/ # always a copy: this one lives in the install directory, not in the run directory

if [[ "${MODEL_ID}" == *-* ]]; then
  file_op ${sim_dir}/namcouple ${simout_dir}/nml/
fi # MODEL_ID oasis

if [[ "${modelid}" == *icon* ]]; then
  # Namelists: all of them, including ICON's own dump (NAMELIST_ICON_output_atm) and the name maps
  file_op ${sim_dir}/NAMELIST_* ${sim_dir}/*.namelist ${simout_dir}/nml/
  file_op ${sim_dir}/map_file.* ${sim_dir}/dict.* ${simout_dir}/nml/

  # Model output: the bulk of the data, moved rather than copied (see bulk_op)
  mkdir -p ${simout_dir}/out/icon
  bulk_op ${sim_dir}/ICON_out_* ${simout_dir}/out/icon

  # Model log
  file_op ${sim_dir}/nml.atmo.log ${simout_dir}/log/
  file_op ${sim_dir}/*.dat ${simout_dir}/log/
  [ -e ${sim_dir}/finish.status ] && file_op ${sim_dir}/finish.status ${simout_dir}/log/
  ls ${sim_dir}/METEOGRAM_* >/dev/null 2>&1 && file_op ${sim_dir}/METEOGRAM_* ${simout_dir}/out/icon

  # Restart: only from a run that ended cleanly. A restart directory left by an
  # earlier run of the same chunk is kept as a backup, not overwritten.
  if [[ "${sim_status}" == "ok" ]]; then
    if [ -e "${simrst_dir}/icon" ]; then
      mv ${simrst_dir}/icon ${simrst_dir}/icon_bku$(date '+%Y%m%d%H%M%S')
    fi
    mkdir -p ${simout_dir}/rst/icon ${simrst_dir}/icon
    # saved twice on purpose, as simout is archived: copy first, then move the
    # originals, so both land regardless of the file operation mode
    cp -v   ${sim_dir}/${expid}_restart_ATMO_*.nc  ${simout_dir}/rst/icon
    bulk_op ${sim_dir}/${expid}_restart_ATMO_*.nc  ${simrst_dir}/icon
  fi

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

# remove the run directory only after a clean run (and unless keep_rundir=true);
# a failed run keeps it for debugging, and the next sim_config of the same chunk
# moves it aside as _bku
if [[ "${sim_status}" == "ok" && "${keep_rundir:-false}" != "true" ]]; then
  rm -rf ${sim_dir:?}
else
  echo "Run directory kept: ${sim_dir}"
fi

} # sim_cleanup
