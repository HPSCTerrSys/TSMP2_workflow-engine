#!/usr/bin/env bash

sim_run(){

LOADENVS=${tsmp2_env}
CASE_DIR=${sim_dir}


if [[ ! -f $LOADENVS || -z "$LOADENVS" ]]; then
  echo "ERROR: Loadenvs script '$LOADENVS' does not exist."
  exit 1
fi

cd $CASE_DIR
source $LOADENVS

# threads per MPI rank (after the env file, whose module purge must not undo it); default: pure MPI
export OMP_NUM_THREADS=${omp_num_threads:-1}
export MKL_NUM_THREADS=${OMP_NUM_THREADS}

# pkp007 (JUPITER GPU, 2026-10-10): OpenACC runtime settings for the GPU build, as in JSC's JUWELS
# Booster/JEDI and ETH's Saentis run scripts and ICON's run/create_target_header. srun passes them on
# to every rank. NVCOMPILER_TERM=trace prints a stack trace if a rank aborts.
if [[ -n "${ico_gpus_per_node}" ]]; then
  export NVCOMPILER_ACC_DEFER_UPLOADS=1
  export NVCOMPILER_TERM=trace
  # pkp007 P-b (2026-10-11): needed by the OpenACC runtime when ICON captures CUDA graphs (lcuda_graph_turb_tran,
  # lcuda_graph_lnd; ICON's run_wrapper_levante_gpu.tmpl). Set only when a graph switch is on, so runs without graphs
  # keep the environment they were benchmarked with (J1, P-a).
  if [[ "${lcuda_graph_turb_tran,,}${lcuda_graph_lnd,,}" == *true* ]]; then
    export NVCOMPILER_ACC_USE_GRAPH=1
  fi
  # pkp007 x0105 diagnostics (2026-10-12): every OpenACC kernel and transfer runs synchronously, so a GPU error
  # (x0105ng: CUDA_ERROR_ILLEGAL_ADDRESS reported at the !$ACC WAIT in o3_pl2ml) is raised by the kernel that
  # causes it. Slower; diagnostics only. Off unless acc_synchronous=true in expid.conf [sim_config_icon].
  if [[ "${acc_synchronous,,}" == true ]]; then
    export NVCOMPILER_ACC_SYNCHRONOUS=1
  fi
fi

# pkp007 (2026-10-13): provenance. The runtime environment the model starts with (OpenACC, threads, UCX, CUDA, MPI
# tuning) and the loaded modules; sim_cleanup copies run_env.log to simres/<case>_<date>/log.
{ echo "# environment at model start, $(date '+%Y-%m-%dT%H:%M:%S'), job ${SLURM_JOB_ID:-n/a}"
  env | grep -E '^(NVCOMPILER_|OMP_|MKL_|UCX_|CUDA_|OMPI_MCA_|PMIX_MCA_)' | sort
  echo "# modules"
  module list 2>&1 || echo "(module command not available)"
} > run_env.log

# pkp007 (2026-10-20): GPU state per node at job start (driver, clocks, power cap, temperature, uncorrected ECC
# errors, clock-event/throttle reasons), to match slow or failed runs with nodes (2425992 and 2426353 ran ~7x slow
# on 16 different nodes). One short job step on all nodes, limited to 2 min; a failure here never stops the model.
if [[ -n "${ico_gpus_per_node}" && -n "${SLURM_JOB_ID:-}" ]]; then
  { echo "# GPU state per node (nvidia-smi), $(date '+%Y-%m-%dT%H:%M:%S')"
    timeout 120 srun --nodes=${SLURM_NNODES} --ntasks-per-node=1 --cpu-bind=none bash -c \
      'nvidia-smi --query-gpu=index,name,driver_version,pci.bus_id,clocks.sm,clocks.max.sm,power.limit,temperature.gpu,ecc.errors.uncorrected.volatile.total,clocks_event_reasons.active --format=csv,noheader | sed "s/^/$(hostname -s), /"' 2>&1 \
      || echo "(nvidia-smi step failed or timed out)"
  } >> run_env.log
fi

if [[ "${modelid}" == *clm* ]]; then

# Set PIO log files
job_id=$(sched_job_id)
if [[ -z "$job_id" || "$job_id" == " " ]]; then
  LOGID=$(date +%Y-%m-%d_%H.%M.%S)
else
  LOGID=$job_id
fi
mkdir -p logs timing/checkpoints
LOGDIR=$(realpath logs)
comps=(atm cpl esp glc ice lnd ocn rof wav)
for comp in ${comps[*]}; do
  LOGFILE="$LOGID.comp_${comp}.log"
  sed -i "s#diro.*#diro = \"$LOGDIR\"#" ${comp}_modelio.nml
  sed -i "s#logfile.*#logfile = \"$LOGFILE\"#" ${comp}_modelio.nml
done

fi # eclm

if [[ "${modelid}" == *parflow* ]]; then

export PARFLOW_DIR=${tsmp2_install_dir}

# ParFlow config
#tclsh ascii2pfb_slopes.tcl
#tclsh ascii2pfb_SoilInd.tcl
tclsh coup_oas.tcl

fi # parflow

# Run model
TIME_START=$(date +%s)
echo ">>> ${modelid} started at $(date +%H:%M:%S)"
sim_rc=0 # model exit code, evaluated by sim_cleanup
${mpmd_run_cmd} ${mpmd_mapping_file} || sim_rc=$?
TIME_END=$(date +%s)
echo ">>> ${modelid} finished at $(date +%H:%M:%S), exit code ${sim_rc}"
echo ">>> ${modelid} runtime: $(date -u -d "0 $TIME_END sec - $TIME_START sec" +"%H:%M:%S")"

} # sim_run
