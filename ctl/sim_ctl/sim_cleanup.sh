#!/usr/bin/env bash

sim_cleanup(){

echo "###"
echo "# Cleanup Simulation"
echo "###"

simout_dir=${out_dir}/${caseid}${modelid}_${dateymd}
simrst_dir=${rst_dir}/${caseid}${modelid}

# create a new simulation output directory
if [ -e "${simout_dir}" ]; then
  mv ${simout_dir} ${simout_dir}_bku$(date '+%Y%m%d%H%M%S')
fi
mkdir -p "${simout_dir}"

echo "Moving model output to simout and storing restart files"

mkdir -p "${simout_dir}/log" "${simout_dir}/nml" "${simout_dir}/rst" "${simout_dir}/bin"

if [[ "${MODEL_ID}" == *-* ]]; then
  cp -v ${sim_dir}/namcouple ${simout_dir}/nml/
fi # MODEL_ID oasis

if [[ "${modelid}" == *icon* ]]; then
  # Namelist
  cp -v ${sim_dir}/NAMELIST_icon ${simout_dir}/nml/
  cp -v ${sim_dir}/icon_master.namelist ${simout_dir}/nml/

  # Model output
  mkdir -p ${simout_dir}/out/icon
  cp -v ${sim_dir}/ICON_out_* ${simout_dir}/out/icon

  # Model log
  cp -v ${sim_dir}/nml.atmo.log ${simout_dir}/log/
  cp -v ${sim_dir}/*.dat ${simout_dir}/log/

  # Restart
  mkdir -p ${simout_dir}/rst/icon ${simrst_dir}/icon
  cp -v ${sim_dir}/${expid}_restart_atm_*.nc  ${simout_dir}/rst/icon
  cp -v ${sim_dir}/${expid}_restart_atm_*.nc  ${simrst_dir}/icon # save twice as simout is archived

  # copy binary
  cp -v icon ${simout_dir}/bin/

fi # icon

if [[ "${modelid}" == *clm* ]]; then
  # Namelist
  cp -v ${sim_dir}/*_in ${simout_dir}/nml/
  cp -v ${sim_dir}/datm.* ${simout_dir}/nml/

  # Model output
  mkdir -p ${simout_dir}/out/eclm
  cp -v ${sim_dir}/eCLM_*.clm2.h* ${simout_dir}/out/eclm

  # Model log
  cp -v ${sim_dir}/logs/${SLURM_JOB_ID}.comp_*.log  ${simout_dir}/log/

  # Restart
  mkdir -p ${simout_dir}/rst/eclm ${simrst_dir}/eclm
  cp -v ${sim_dir}/eCLM_*.clm2.r* ${simout_dir}/rst/eclm
  cp -v ${sim_dir}/eCLM_*.clm2.r* ${simrst_dir}/eclm # save twice as simout is archived

  # Copy binary
  cp -v eclm ${simout_dir}/bin/

fi # clm

if [[ "${modelid}" == *parflow* ]]; then

  # Namelist
  cp -v ${sim_dir}/coup_oas.tcl ${simout_dir}/nml/

  # Model output
  mkdir -p ${simout_dir}/out/parflow
  cp -v ${sim_dir}/*.out.?????.nc ${simout_dir}/out/parflow

  # Model log
  cp -v ${sim_dir}/*out.kinsol.log ${simout_dir}/log/
  cp -v ${sim_dir}/*out.timing* ${simout_dir}/log/

  # Restart
  mkdir -p ${simout_dir}/rst/parflow ${simrst_dir}/parflow
  cp -v $(ls -1 ${sim_dir}/*.out.?????.nc | tail -1) ${simout_dir}/rst/parflow
  cp -v $(ls -1 ${sim_dir}/*.out.?????.nc | tail -1) ${simrst_dir}/parflow # save twice as simout is archived

  # Copy binary
  cp -v parflow ${simout_dir}/bin/

fi # parflow

cp -v ${sim_dir}/slm_multiprog_mapping.conf ${simout_dir}/log/

# sim logs
mv ${log_dir}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}.{err,out} ${simout_dir}/log/.

#echo "SLURM node ID LIST:"${SLURM_JOB_NODELIST}

# remove run directory
rm -rf ${sim_dir:?}

} # sim_cleanup
