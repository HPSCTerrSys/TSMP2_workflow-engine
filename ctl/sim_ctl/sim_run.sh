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
if [[ "${scheduler}" == "pbs" || "${scheduler}" == "local" ]]; then
  mpiexec --app ${mpmd_mapping_file}
else
  srun --multi-prog ${mpmd_mapping_file}
fi
TIME_END=$(date +%s)
echo ">>> ${modelid} finished at $(date +%H:%M:%S)"
echo ">>> ${modelid} runtime: $(date -u -d "0 $TIME_END sec - $TIME_START sec" +"%H:%M:%S")"

} # sim_run
