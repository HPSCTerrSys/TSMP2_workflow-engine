#!/usr/bin/env bash
#
# function to configure tsmp2 post-processing cleanup
#
# ICON: checks the post files of every processed month (tools/post_check.sh). The per-variable logs,
# the variable list, the job info and the job logs are stored with the post files in
# <pos_out>/<YYYY_MM>/log/. If all is well the temporary directory is removed; otherwise it is kept
# as well. The model output in dta/simres is never touched here.

pos_cleanup(){

echo "###"
echo "# Cleanup Post-processing"
echo "###"

if [[ "${modelid}" != *icon* ]]; then
  echo "Post-processing is implemented for ICON only; nothing to clean up for ${modelid}"
  return 0
fi

local problems=${pos_run_failed:-0}
local month m0 end nsteps hinc names name icon stream oper level role
for month in ${pos_monthstr}; do
  m0=$(date -u -d "${month/_/-}-01" +%s)
  end=$(date -u -d "${month/_/-}-01 +1 month" +%s)
  [[ $(date -u -d "${pos_chunk_end}" +%s) -lt ${end} ]] && end=$(date -u -d "${pos_chunk_end}" +%s)

  # final files and the expected step count (all four are hourly; the check takes one count per call)
  names=()
  while IFS=, read -r name icon stream hinc oper level role; do
    [[ -z ${name} || ${name} == \#* || ${name} == name || ${role} == intermediate ]] && continue
    names+=( ${name} )
    IFS=: read -r hh mm ss <<< "${hinc}"
    nsteps=$(( (end - m0) / (10#${hh} * 3600 + 10#${mm} * 60 + 10#${ss}) ))
  done < ${pos_varlist}

  echo "=== ${month}: expecting ${nsteps} steps"
  bash ${pos_tools}/post_check.sh ${pos_out}/${month} ${nsteps} "${names[@]}" || problems=$((problems + $?))
done

if [[ ${problems} -eq 0 ]]; then
  echo "Post-processing status: ok"
else
  echo "Post-processing status: FAILED (${problems} problem(s)); temporary files and logs kept in ${pos_tmp}"
fi

# keep the evidence with the data: for every processed month the per-variable logs and return codes,
# the variable list that produced the files, the job info and the job's own logs (as sim_cleanup does
# for simres). Done after the status line so the copied job log contains it.
local job_id=$(sched_job_id) job_name=$(sched_job_name)
for month in ${pos_monthstr}; do
  mkdir -p ${pos_out}/${month}/log
  cp -p ${pos_tmp}/${month}/*.log ${pos_tmp}/${month}/*.rc ${pos_out}/${month}/log/ 2>/dev/null
  cp -p ${pos_varlist} ${pos_out}/${month}/log/
  case "${scheduler:-slurm}" in
    pbs) qstat -f ${job_id} > ${pos_out}/${month}/log/job_info.log 2>&1
         cp -p ${log_dir}/${job_name}.{e,o}${job_id} ${pos_out}/${month}/log/ 2>/dev/null ;;
    local) echo "local job ${job_name} (id ${job_id}) on $(hostname) at $(date)" > ${pos_out}/${month}/log/job_info.log ;;
    *)   scontrol show job ${job_id} > ${pos_out}/${month}/log/job_info.log 2>&1
         cp -p ${log_dir}/${job_name}_${job_id}.{err,out} ${pos_out}/${month}/log/ 2>/dev/null ;;
  esac
done

# the temporary directory is cleared only once its logs are stored with the data
if [[ ${problems} -eq 0 ]]; then
  rm -r ${pos_tmp}
fi

} # pos_cleanup
