#!/usr/bin/env bash
#
# function to configure tsmp2 simulations

sim_config(){

echo "###"
echo "# Configure Simulation"
echo "###"

###
# Start replacing variables
###

####################
# General
####################

# create a new simulation run directory
echo "simdir: "$sim_dir
if [ -e "${sim_dir}" ]; then
  mv ${sim_dir} ${sim_dir}_bku$(date '+%Y%m%d%H%M%S')
fi
mkdir -p $sim_dir

# copy blueprints
cp ${ctl_dir}/conf/slm_multiprog_mapping_sed.conf ${sim_dir}/slm_multiprog_mapping.conf

# slm_multiprog
if [[ "${modelid}" != *icon* ]]; then
   sed -i "/__icon_pe__/d" ${sim_dir}/slm_multiprog_mapping.conf
fi
if [[ "${modelid}" != *eclm* ]]; then
   sed -i "/__clm_pe__/d" ${sim_dir}/slm_multiprog_mapping.conf
fi
if [[ "${modelid}" != *parflow* ]]; then
   sed -i "/__pfl_pe__/d" ${sim_dir}/slm_multiprog_mapping.conf
fi
sed -i "s/__icon_pe__/$(($ico_proc-1))/" ${sim_dir}/slm_multiprog_mapping.conf
sed -i "s/__clm_ps__/$(($ico_proc))/" ${sim_dir}/slm_multiprog_mapping.conf
sed -i "s/__clm_pe__/$(($ico_proc+$clm_proc-1))/" ${sim_dir}/slm_multiprog_mapping.conf
sed -i "s/__pfl_ps__/$(($ico_proc+$clm_proc))/" ${sim_dir}/slm_multiprog_mapping.conf
sed -i "s/__pfl_pe__/$(($ico_proc+$clm_proc+$pfl_proc-1))/" ${sim_dir}/slm_multiprog_mapping.conf

# change to run directory
cd ${sim_dir}

####################
# ICON
####################
if [[ "${modelid}" == *icon* ]]; then

  icon_latbc_dir=${frc_dir}/icon/latbc/$(date -u -d "${startdate}" +%Y%m)

# link executeable (will be replaced with copy in production)
#  ln -sf $tsmp2_install_dir/bin/icon icon
  cp $tsmp2_install_dir/bin/icon icon

# copy namelist
  cp ${nml_dir}/icon/NAMELIST_icon NAMELIST_icon
  cp ${nml_dir}/icon/icon_master.namelist icon_master.namelist
  cp ${nml_dir}/icon/map_file.ic map_file.ic
  cp ${nml_dir}/icon/map_file.lbc map_file.lbc
  cp ${nml_dir}/icon/map_file.fc map_file.fc

# ICON NML
  sed -i "s#__ecraddata_dir__#ecraddata#" NAMELIST_icon # needs to be short path in ICON v2.6.4
  sed -i "s/__dateymd__/${dateymd}/" NAMELIST_icon
  sed -i "s/__outdatestart__/$(date -u -d "${startdate}" +%Y-%m-%dT%H:%M:%SZ)/" NAMELIST_icon
  sed -i "s/__outdateend__/$(date -u -d "${datep1}" +%Y-%m-%dT%H:%M:%SZ)/" NAMELIST_icon
  sed -i "s/__outname__/ICON_out_${expid}/" NAMELIST_icon
  sed -i "s/__restartname__/${expid}_restart_\<mtype\>_\<rsttime\>.nc/" NAMELIST_icon
  sed -i "s#__latbc_dir__#${icon_latbc_dir}#" NAMELIST_icon
  sed -i "s/__simstart__/$(date -u -d "${startdate}" +%Y-%m-%dT%H:%M:%SZ)/" icon_master.namelist
  sed -i "s/__simend__/$(date -u -d "${datep1}" +%Y-%m-%dT%H:%M:%SZ)/" icon_master.namelist
  sed -i "s/__dtrestart__/${simlensec}/" icon_master.namelist
  sed -i "s/\(lrestart            =\).*/\1 $lrestart/" icon_master.namelist

# link needed files
  ln -sf ${icon_latbc_dir}/igaf$(date -u -d "${startdate}" +%Y%m%d%H).nc dwdFG_R13B05_DOM01.nc
  ln -sf ${geo_dir}/icon/static/europe011_DOM01.nc
  ln -sf ${geo_dir}/icon/static/external_parameter_icon_europe011_DOM01_tiles.nc
  ln -sf ${geo_dir}/icon/static/bc_greenhouse_rcp45_1765-2500.nc
  ln -sf ${geo_dir}/icon/static/ecraddata

fi # if modelid == ICON

####################
# CLM
####################
if [[ "${modelid}" == *clm* ]]; then

# 
  geo_dir_clm=${geo_dir}/eclm/static
  clm_tsp=${cpltsp_atmsfc}
  clmoutfrq=-1
#
  domainfile_clm=domain.lnd.ICON-11_ICON-11.230302_masked.nc
  surffile_clm=surfdata_ICON-11_hist_16pfts_Irrig_CMIP6_simyr2000_c230302.nc
  fini_clm="/p/scratch/cslts/poll1/sim/euro-cordex/eu11_iconeclm_icogrid/ini/EU11.clm2.r.2017-07-01-00000.nc"

# link executeable
#  ln -sf $tsmp2_install_dir/bin/eclm.exe eclm
  cp $tsmp2_install_dir/bin/eclm.exe eclm

# calculation for automated adjustment of clm forcing
#  forcedate=$(date '+%s' -d "${datep1} + 1 month - 1 day")
  forcedate=$(date '+%s' -d "${datep1} + 1 month - 2 day")
  ldate="${startdate}"
  forcdatelist=""
  while [[ $(date +%s -d $ldate) -le $forcedate ]]; do
    forcdatelist+=$(echo "${ldate%-*}.nc\n")
    ldate=$(date '+%Y-%m-%d' -d "$ldate +1 month")
  done
  forcdatelist=${forcdatelist::-2} # delete last new line command

# copy namelist
  cp ${nml_dir}/eclm/drv_in drv_in
  cp ${nml_dir}/eclm/lnd_in lnd_in
  cp ${nml_dir}/eclm/datm_in datm_in
  cp ${nml_dir}/eclm/drv_flds_in drv_flds_in
  cp ${nml_dir}/eclm/mosart_in mosart_in
  cp ${nml_dir}/eclm/datm.streams.txt* .
  cp ${nml_dir}/eclm/cime/* .

# CLM NML
  sed -i "s/__nclm_proc__/$(($clm_proc))/" drv_in
  sed -i "s/__clm_tsp__/$clm_tsp/" drv_in
#  sed -i "s/__clm_tsp2__/$(($clm_tsp*3 | bc -l))/" drv_in
  sed -i "s/__clm_tsp2__/${simlensec}/" drv_in
  sed -i "s/__simstart__/$(date -u -d "${startdate}" +%Y%m%d)/" drv_in
  sed -i "s/__simend__/$(date -u -d "${datep1}" +%Y%m%d)/" drv_in
  sed -i "s/__simendsec__/$(($simlensec % 86400))/" drv_in
  sed -i "s/__simrestart__/$(date -u -d "${datep1}" +%Y%m%d)/" drv_in
  sed -i "s/__clm_casename__/eCLM_${EXP_ID}/" drv_in
  sed -i "s/__clm_tsp__/$clm_tsp/" lnd_in
  sed -i "s/\( hist_nhtfrq =\).*/\1 $clmoutfrq/" lnd_in
  sed -i "s#__fini_clm__#$fini_clm#" lnd_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" lnd_in
  sed -i "s#__domainfile_clm__#$domainfile_clm#" lnd_in
  sed -i "s#__surffile_clm__#$surffile_clm#" lnd_in
  if [[ "${modelid}" != *parflow* ]]; then
    sed -i "s/__swmm__/1/" lnd_in # soilwater_movement_method
    sed -i "s/__clmoutvar__/'TWS','H2OSOI','TSOI','TG','EFLX_LH_TOT','FSH','FSA','FSR','FIRA','Rnet','EFLX_SOIL_GRND'/" lnd_in
  else
    sed -i "s/__swmm__/4/" lnd_in # soilwater_movement_method
    sed -i "s/__clmoutvar__/'TWS','H2OSOI','TSOI','TG','EFLX_LH_TOT','FSH','FSA','FSR','FIRA','Rnet','EFLX_SOIL_GRND'/" lnd_in
#    sed -i "s/__clmoutvar__/'TWS','H2OSOI','QFLX_EVAP_TOT','TG','TSOI','FSH','FSR'/" lnd_in
#    sed -i "s/__clmoutvar__/'PFL_PSI', 'PFL_PSI_GRC', 'PFL_SOILLIQ', 'PFL_SOILLIQ_GRC', 'RAIN', 'SNOW', 'SOILPSI', 'SMP', 'QPARFLOW', 'FH2OSFC', 'FH2OSFC_NOSNOW', 'FRAC_ICEOLD', 'FSAT', 'H2OCAN', 'H2OSFC', 'H2OSNO', 'H2OSNO_ICE', 'H2OSOI', 'LIQCAN', 'LIQUID_WATER_TEMP1', 'OFFSET_SWI', 'ONSET_SWI', 'QH2OSFC', 'QH2OSFC_TO_ICE', 'QROOTSINK', 'QTOPSOIL', 'SNOLIQFL', 'SNOWLIQ', 'SNOWLIQ_ICE', 'SNOW_SINKS', 'SNOW_SOURCES', 'SNO_BW', 'SNO_BW_ICE', 'SNO_LIQH2O', 'SOILLIQ', 'SOILPSI', 'SOILWATER_10CM', 'TH2OSFC', 'TOTSOILLIQ', 'TWS', 'VEGWP', 'VOLR', 'VOLRMCH', 'WF', 'ZWT', 'ZWT_CH4_UNSAT', 'ZWT_PERCH', 'watfc', 'watsat', 'QINFL', 'Qstor', 'QOVER', 'QRUNOFF', 'EFF_POROSITY', 'TSOI', 'TSKIN', 'QDRAI'/" lnd_in
  fi
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" datm_in
  sed -i "s/__simystart__/$(date -u -d "${startdate}" +%Y)/g" datm_in
  sed -i "s/__simyend__/$(date -u -d "${startdate}" +%Y)/g" datm_in
  sed -i "s#__domainfile_clm__#$domainfile_clm#" datm_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" drv_flds_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" mosart_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" datm.streams.txt*
#  sed -i "s#topodata_0.9x1.25_USGS_070110_stream_c151201.nc#topodata_0.9x1.25_zeroed.nc#" datm.streams.txt.topo.observed
  # forcing
  sed -i "s#__forcdir__#${frc_dir}/eclm/forcing/#" datm.streams.txt.CLMCRUNCEPv7.*
  sed -i "s#__forclist__#${forcdatelist}#" datm.streams.txt.CLMCRUNCEPv7.*
  sed -i "s#__domainfile_clm__#$domainfile_clm#" datm.streams.txt.CLMCRUNCEPv7.*
fi # if modelid == CLM

####################
# PFL
####################
if [[ "${modelid}" == *parflow* ]]; then

# link executeable
#  ln -sf $tsmp2_install_dir/bin/parflow parflow
  cp $tsmp2_install_dir/bin/parflow parflow

#  
  parflow_tsp=$(echo "$cpltsp_sfcss / 3600" | bc -l)
  parflow_base=0.0025
#  parflow_inifile=${frc_dir}/parflow/ini/ic_press.pfb

# copy namelist
  cp ${nml_dir}/parflow/ascii2pfb_slopes.tcl ascii2pfb_slopes.tcl
  cp ${nml_dir}/parflow/ascii2pfb_SoilInd.tcl ascii2pfb_SoilInd.tcl
  cp ${nml_dir}/parflow/coup_oas.tcl coup_oas.tcl
#  cp ${parflow_inifile}  $(basename "$parflow_inifile")

# copy sa and pfsol files
  cp ${geo_dir}/parflow/static/*sa .
  cp ${geo_dir}/parflow/static/PfbMask4SolidFile_eCLM.pfsol PfbMask4SolidFile_eCLM.pfsol

# PFL NML
  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" ascii2pfb_slopes.tcl
  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" ascii2pfb_slopes.tcl
  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" ascii2pfb_SoilInd.tcl
  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" ascii2pfb_SoilInd.tcl
  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" coup_oas.tcl
  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" coup_oas.tcl
  sed -i "s/__ngpflx_bldsva__/444/" coup_oas.tcl
  sed -i "s/__ngpfly_bldsva__/432/" coup_oas.tcl
  sed -i "s/__base_pfl__/$parflow_base/" coup_oas.tcl
  sed -i "s/__start_cnt_pfl__/0/" coup_oas.tcl
  sed -i "s/__stop_pfl_bldsva__/$(echo "${simlenhr} + ${parflow_base}" | bc -l)/" coup_oas.tcl
  sed -i "s/__dt_pfl_bldsva__/$parflow_tsp/" coup_oas.tcl
  sed -i "s/__dump_pfl_interval__/1.0/" coup_oas.tcl
  sed -i "s/__pfl_casename__/$EXP_ID/" coup_oas.tcl
  sed -i "s#__inifile__#$(basename "$parflow_inifile")#" coup_oas.tcl
  sed -i "s/__pfl_expid__/$EXP_ID/" slm_multiprog_mapping.conf


  # --- execute ParFlow distributeing tcl-scripts
  export PARFLOW_DIR=${tsmp2_install_dir}
  tclsh ascii2pfb_slopes.tcl
  tclsh ascii2pfb_SoilInd.tcl

fi # if modelid == parflow

####################
# OASIS
####################

if [[ "${MODEL_ID}" == *-* ]]; then

# copy namelist
  cp ${nml_dir}/oasis/namcouple_${modelid} namcouple

# OAS NML
  sed -i "s/__cpltsp_as__/$cpltsp_atmsfc/" namcouple
  sed -i "s/__cpltsp_ss__/$cpltsp_sfcss/" namcouple
  sed -i "s/__simlen__/$(( $simlensec + $cpltsp_atmsfc ))/" namcouple
  sed -i "s/__icongp__/199920/" namcouple
  sed -i "s/__eclmgpx__/199920/" namcouple
  sed -i "s/__eclmgpy__/1/" namcouple
  sed -i "s/__parflowgpx__/444/" namcouple
  sed -i "s/__parflowgpy__/432/" namcouple

# copy remap-files
  cp ${geo_dir}/oasis/static/masks.nc .
#  cp ${geo_dir}/static/oasis/grids.nc .
  if [[ "${modelid}" == *parflow* ]]; then
    cp ${geo_dir}/oasis/static/rmp* .
    cp ${geo_dir}/oasis/static/masks_parflow.nc masks.nc
  fi

fi # if modelid == oasis

if ${debugmode}; then

# create job submission script (tsmp2.job)
echo "#!/usr/bin/env bash" > tsmp2.job
echo "#SBATCH ${jobsimstring//[$'\t\r\n']}" >> tsmp2.job

# add modelid, which is needed
echo "" >> tsmp2.job
echo "modelid=${modelid}" >> tsmp2.job

# cat sim run script into submission script
cat ${ctl_dir}/sim_ctl/sim_run.sh | tail -n +2 >> tsmp2.job # start from line 2

#echo "mv $(echo ${jobsimstring#*output=} | cut -d' ' -f1) ." >> tsmp2.job
#echo "mv $(echo ${jobsimstring#*error=} | cut -d' ' -f1) ." >> tsmp2.job

sed -i "s/sim_run(){//" tsmp2.job
sed -i "s/} # sim_run//" tsmp2.job
sed -i "s#${log_dir}#${sim_dir}#g" tsmp2.job
sed -i "s#\(LOADENVS=\).*#\1${tsmp2_env}#" tsmp2.job
sed -i "s#\(CASE_DIR=\).*#\1${sim_dir}#" tsmp2.job
sed -i "s#\(PARFLOW_DIR=\).*#\1${tsmp2_install_dir}#" tsmp2.job

fi # debugmode

echo "Configuration:"
echo "MODEL_ID: "$MODEL_ID

} # sim_config
