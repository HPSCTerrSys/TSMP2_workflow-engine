#!/usr/bin/env bash
# Contains functions for TSMP2-WFE
#
# Included functions:
# sim_calc_numberofproc - calculate number of processors for TSMP2 application
# check_run_oasis - check if simulation is running in coupled mode
# check_var_def - check if variable is defined and if not take default and printing message
# logging_job_status - log information about the job into job_status.log
# parse_config_file - parser to read in ini/conf-files
#
# Scheduler abstraction to faciliate different schedular
# sched_pbs_mailcode  - map generic mailtype to a PBS -m code
# sched_step_opts     - per-job-step submission options (name, walltime, nodes/tasks, log files)
# sched_dependency_opt - build the scheduler-specific job-dependency flag
# sched_submit        - submit a job script, returns raw submission output
# sched_parse_jobid   - extract the job id from submission output
# sched_job_id        - current job id, read from within a running job
# sched_job_name      - current job name, read from within a running job
# sched_directive_prefix - in-script batch-directive comment prefix (#SBATCH / #PBS)
# run_serial_step     - run a serial helper program (job-step exclusive under slurm, direct under pbs)
##

# calculate number of processors for TSMP2 application
sim_calc_numberofproc(){

# calculate needed variables TODO: take LC_NUMERIC into account
ico_proc=$( printf %.0f $(echo "$ico_node * $npnode" | bc -l))
clm_proc=$( printf %.0f $(echo "$clm_node * $npnode" | bc -l))
pfl_proc_tmp=$( printf %.0f $(echo "$pfl_node * $npnode" | bc -l))
pfl_proc_sqrt=$(echo "sqrt($pfl_proc_tmp)" | bc -l)
if [[ $pfl_proc_sqrt =~ \.[0-9]*[1-9] ]]; then
   pfl_procY=$((${pfl_proc_sqrt%.*} + (2 - ${pfl_proc_sqrt%.*} % 2))) # go to next num of 2
   pfl_procX=$(($pfl_proc_tmp/$pfl_procY))
else
   pfl_procY=${pfl_proc_sqrt%.*}
   pfl_procX=${pfl_proc_sqrt%.*}
fi
pfl_proc=$(($pfl_procY*$pfl_procX))
unset pfl_proc_tmp pfl_proc_sqrt

# set <comp>_proc to zero based on modelid
if [[ "${modelid}" != *icon* ]]; then
   ico_node=0
   ico_proc=0
fi
if [[ "${modelid}" != *eclm* ]]; then
   clm_node=0
   clm_proc=0
fi
if [[ "${modelid}" != *parflow* ]]; then
   pfl_node=0
   pfl_proc=0
fi

tot_proc=$(($ico_proc+$clm_proc+$pfl_proc))
tot_node=$(echo $(echo "$ico_node+$clm_node+$pfl_node" | bc -l) | sed -e 's/\.0*$//;s/\.[0-9]*$/ + 1/' | bc) # ceiling

} # sim_calc_numberofproc

# check if oasis is active/true
check_run_oasis() {
  local model_id
  local comp_models=("icon" "eclm" "parflow")
  local model_count=0

  model_id=$(echo ${MODEL_ID} | tr '[:upper:]' '[:lower:]')

  # Split the identifier into individual elements
  IFS='-' read -r -a elements <<< "$model_id"

  # Check for each component model
  for comp_model in "${comp_models[@]}"; do
    for element in "${elements[@]}"; do
      if [ "$element" == "$comp_model" ]; then
#        ((model_count++))
         model_count=$((model_count+1))
      fi
    done
  done

  # Return true if at least 2 components are found
  if [ "$model_count" -ge 2 ]; then
    echo "true"
  else
    echo "false"
  fi
} # check_run_oasis

# check var defaults
check_var_def() {
  local var_name="$1"
  local default="$2"
  local message="$3"
  local cur_value="${!var_name}"

  # take default value when var_name is not set yet
  if [ -z "$cur_value" ]; then
    cur_value="$default"
    eval "$var_name=\"$cur_value\""
    if [ -n "$message" ]; then
      echo "$message"${!var_name}
    fi
  fi
} # check_var_def

logging_job_status(){
  local step="$1"

  if [ "$joblog" = true ] && [ "$debugmode" != true ]; then
    job_id=$(sched_job_id)
    case "${scheduler:-slurm}" in
      slurm)
        job_state=$(scontrol show job $job_id | grep "JobState=" | cut -d= -f2 | cut -d' ' -f1)
        ;;
      pbs)
        job_state=$(qstat -f "$job_id" 2>/dev/null | awk -F' = ' '/job_state/{print $2}')
        ;;
      local)
        job_state="COMPLETED"
        ;;
      *)
        job_state=$(scontrol show job $job_id | grep "JobState=" | cut -d= -f2 | cut -d' ' -f1)
        ;;
    esac
    printf "%10s %8s %3s %15s %14s %10s %10s %14s %8s\n" "${expid}" "${caseid}" "${step}" "${modelid}" \
        "${dateshort}" "${job_id}" "${job_state}" "$(date '+%Y%m%d%H%M%S')" $(date -u -d "0 $timeend sec - $timestart sec" +"%H:%M:%S") \
        >> ${ctl_dir}/job_status.log
  fi
} # logging_job_status

###
# Scheduler abstraction: slurm (default), pbs, or local, selected via ${scheduler}
# 'local' runs job scripts synchronously in the foreground (no queue), for
# machines without a batch scheduler (e.g. a plain Ubuntu workstation).
###

# map generic mailtype (NONE,BEGIN,END,FAIL,REQUEUE,ALL) to a PBS -m code
sched_pbs_mailcode() {
  case "${mailtype^^}" in
    BEGIN)            echo "b" ;;
    END)              echo "e" ;;
    FAIL|REQUEUE)     echo "a" ;;
    ALL)              echo "abe" ;;
    *)                echo "n" ;;
  esac
} # sched_pbs_mailcode

# per-job-step submission options (job name, walltime, node/task layout, log files)
# args: jobname walltime nodes ntasks
sched_step_opts() {
  local jobname="$1" walltime="$2" nodes="$3" ntasks="$4"

  case "${scheduler:-slurm}" in
    slurm)
      echo "--job-name=${jobname} \
            --time=${walltime} \
            --output=${log_dir}/%x_%j.out \
            --error=${log_dir}/%x_%j.err \
            --nodes=${nodes} \
            --ntasks=${ntasks}"
      ;;
    pbs)
      local ppn=$((ntasks/nodes))
      echo "-N ${jobname} \
            -l walltime=${walltime} \
            -l nodes=${nodes}:ppn=${ppn} \
            -o ${log_dir}/ \
            -e ${log_dir}/"
      ;;
    local)
      : # no scheduler options: sched_submit runs the job script directly
      ;;
    *)
      echo "--job-name=${jobname} \
            --time=${walltime} \
            --output=${log_dir}/%x_%j.out \
            --error=${log_dir}/%x_%j.err \
            --nodes=${nodes} \
            --ntasks=${ntasks}"
      ;;
  esac
} # sched_step_opts

# build the scheduler-specific job-dependency flag
# args: dependency payload, e.g. "afterok:123:456" (empty => no dependency)
sched_dependency_opt() {
  local dep="$1"
  [ -z "$dep" ] && return 0

  case "${scheduler:-slurm}" in
    slurm) echo "--dependency=${dep}" ;;
    pbs)   echo "-W depend=${dep}" ;;
    local) : ;; # local jobs already run sequentially/blocking, no dependency needed
    *)     echo "--dependency=${dep}" ;;
  esac
} # sched_dependency_opt

# submit a job script; args: jobname opt_string job_script
# under 'local', runs synchronously in the foreground (blocking) and redirects
# stdout/stderr into log_dir, matching the slurm output-file naming convention
sched_submit() {
  local jobname="$1" opts="$2" job_script="$3"

  case "${scheduler:-slurm}" in
    slurm)
      sbatch ${opts} ${job_script} 2>&1
      ;;
    pbs)
      qsub ${opts} ${job_script} 2>&1
      ;;
    local)
      local job_id=$(date +%s%N)
      TSMP2_LOCAL_JOB_ID="${job_id}" TSMP2_LOCAL_JOB_NAME="${jobname}" \
        bash ${job_script} > ${log_dir}/${jobname}_${job_id}.out 2> ${log_dir}/${jobname}_${job_id}.err
      echo "${job_id}"
      ;;
    *)
      sbatch ${opts} ${job_script} 2>&1
      ;;
  esac
} # sched_submit

# extract the job id from a job's submission output
# args: submission output (e.g. captured from sched_submit)
sched_parse_jobid() {
  case "${scheduler:-slurm}" in
    slurm)     echo "$1" | awk 'END{print $(NF)}' ;;
    pbs|local) echo "$1" | tail -n1 | tr -d '[:space:]' ;;
    *)         echo "$1" | awk 'END{print $(NF)}' ;;
  esac
} # sched_parse_jobid

# current job id, read from within a running job
sched_job_id() {
  case "${scheduler:-slurm}" in
    slurm) echo "${SLURM_JOB_ID}" ;;
    pbs)   echo "${PBS_JOBID%%.*}" ;;
    local) echo "${TSMP2_LOCAL_JOB_ID}" ;;
    *)     echo "${SLURM_JOB_ID}" ;;
  esac
} # sched_job_id

# current job name, read from within a running job
sched_job_name() {
  case "${scheduler:-slurm}" in
    slurm) echo "${SLURM_JOB_NAME}" ;;
    pbs)   echo "${PBS_JOBNAME}" ;;
    local) echo "${TSMP2_LOCAL_JOB_NAME}" ;;
    *)     echo "${SLURM_JOB_NAME}" ;;
  esac
} # sched_job_name

# in-script batch-directive comment prefix, used when generating job scripts in debugmode
sched_directive_prefix() {
  case "${scheduler:-slurm}" in
    slurm) echo "#SBATCH" ;;
    pbs)   echo "#PBS" ;;
    local) echo "#" ;;
    *)     echo "#SBATCH" ;;
  esac
} # sched_directive_prefix

# run a serial helper program: an exclusive job-step under slurm, directly under pbs/local
run_serial_step() {
  case "${scheduler:-slurm}" in
    slurm)     srun --exclusive -n 1 "$@" ;;
    pbs|local) "$@" ;;
    *)         srun --exclusive -n 1 "$@" ;;
  esac
} # run_serial_step


# input 1: filename of conf-file input 2: section (optional)
parse_config_file() {
    local config_file="$1"
    local target_section="${2:-default}"
    local current_section="default"

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}" # remove comments including in-line comments
        line="${line%"${line##*[![:space:]]}"}" # remove spaces
        line="${line#"${line%%[![:space:]]*}"}" # remove spaces
        [[ -z "$line" ]] && continue # skip empty lines

        # get section
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi

        # only parse target section
        if [[ "$current_section" == "$target_section" ]]; then
            # handle array assignment
            if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=\((.*)\)$ ]]; then
                key="${BASH_REMATCH[1]}"
                array_values="${BASH_REMATCH[2]}"
                # evaluate array values and convert them to an array
                eval "$key=($array_values)"

            # handle scalar assignment
            elif [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"
                # strip surrounding quotes if they exist
                value="${value%\"}"
                value="${value#\"}"

                # evaluate the value
                eval "$key=\"$value\""
            fi
        fi
    done < "$config_file"
} # parse_config_file
