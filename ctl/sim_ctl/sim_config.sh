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

# slm_multiprog
if [[ "${modelid}" == *icon* ]]; then
   echo "0-__icon_pe__   ./icon" >> ${sim_dir}/slm_multiprog_mapping.conf
fi
if [[ "${modelid}" == *eclm* ]]; then
   echo "__clm_ps__-__clm_pe__ ./eclm" >> ${sim_dir}/slm_multiprog_mapping.conf
fi
if [[ "${modelid}" == *parflow* ]]; then
   echo "__pfl_ps__-__pfl_pe__ ./parflow __pfl_expid__" >>  ${sim_dir}/slm_multiprog_mapping.conf
fi
sed -i "s/__icon_pe__/$(($ico_proc-1))/" ${sim_dir}/slm_multiprog_mapping.conf
sed -i "s/__clm_ps__/$(($ico_proc))/" ${sim_dir}/slm_multiprog_mapping.conf
sed -i "s/__clm_pe__/$(($ico_proc+$clm_proc-1))/" ${sim_dir}/slm_multiprog_mapping.conf
sed -i "s/__pfl_ps__/$(($ico_proc+$clm_proc))/" ${sim_dir}/slm_multiprog_mapping.conf
sed -i "s/__pfl_pe__/$(($ico_proc+$clm_proc+$pfl_proc-1))/" ${sim_dir}/slm_multiprog_mapping.conf

# change to run directory
cd ${sim_dir}

parse_config_file ${conf_file} "sim_config_general"

lreal=${lreal:-true}
lcpbin=${lcpbin:-true}
simrstm1_dir=${simrstm1_dir:-${rst_dir}/${caseid}$(date -u -d "${datem1}" +%Y%m%d)}

####################
# ICON
####################
if [[ "${modelid}" == *icon* ]]; then

  parse_config_file ${conf_file} "sim_config_icon"

  # copy executeable
  [[ "$lcpbin" == "true" ]] && cp $tsmp2_install_dir/bin/icon icon

  # set defaults
  icon_latbc_dir=${icon_latbc_dir:-${frc_dir}/icon/latbc/$(date -u -d "${startdate}" +%Y%m)}
  icon_restartdt=${icon_restartdt:-${simlensec}}
  nproma=${nproma:-12}
  icon_numioprocs=${icon_numioprocs:-1}
  icon_numrstprocs=${icon_numrstprocs:-0}
  icon_numprefetchproc=${icon_numprefetchproc:-1}
  domainfile_icon=${domainfile_icon:-europe011_DOM01.nc}
  icon_mapfile_lbc=${icon_mapfile_lbc:-dict.latbc}
  [ "${icon_numrstprocs}" -eq 0 ] && icon_rstmode="sync" || icon_rstmode="dedicated procs multifile"
  # this method just works for simlength <= 1 month, ICON src changes needed
  [ "${#allow_overcast_yr[@]}" -eq 0 ] && allow_overcast_yr=( 0.917 0.884 0.909 0.951 0.976 0.951 0.951 0.951 0.917 0.901 0.901 0.909 )
  allow_overcast=${allow_overcast_yr[$((10#$(date -u -d "${startdate}" +%m) -1 ))]}

  # set restart parameter
  if [[ "$(date -u -d "${startdate}" +%s)" -eq "$(date -u -d "${inidate}" +%s)" ]]; then
    lrestart=${lrestart:-false}
  else
    lrestart=${lrestart:-true}
    if [ "${icon_numrstprocs}" -eq 0 ]; then
      icon_rstfiles=$(ls ${simrstm1_dir}/icon/*restart*${dateymd}*.nc)
      fini_icon=restart_ATMO_DOM01.nc
    else
      icon_rstfiles=$(ls ${simrstm1_dir}/icon/*restart*${dateymd}*.mfr)
      fini_icon=multifile_restart_ATMO.mfr
    fi
  fi

# copy namelist
  cp ${nml_dir}/icon/NAMELIST_icon NAMELIST_icon
  cp ${nml_dir}/icon/icon_master.namelist icon_master.namelist
  [[ "$lreal" == "true" ]] && cp ${nml_dir}/icon/map_file.ic map_file.ic
  [[ "$lreal" == "true" ]] && cp ${nml_dir}/icon/${icon_mapfile_lbc} ${icon_mapfile_lbc}
  [[ "$lreal" == "true" ]] && cp ${nml_dir}/icon/map_file.fc map_file.fc

# ICON NML
  sed -i "s/__simstart__/$(date -u -d "${inidate}" +%Y-%m-%dT%H:%M:%SZ)/" icon_master.namelist
  sed -i "s/__simend__/$(date -u -d "${datep1}" +%Y-%m-%dT%H:%M:%SZ)/" icon_master.namelist
  sed -i "s/__dtrestart__/${icon_restartdt}/" icon_master.namelist
  sed -i "s/\(lrestart            =\).*/\1 $lrestart/" icon_master.namelist
  sed -i "s/__nproma__/${nproma}/" NAMELIST_icon
#  sed -i "s/\( num_io_procs   =\).*/\1 ${icon_numioprocs}/" NAMELIST_icon
  sed -i "s/__num_io_procs__/${icon_numioprocs}/" NAMELIST_icon
  sed -i "s/__num_restart_procs__/${icon_numrstprocs}/" NAMELIST_icon
  sed -i "s/__num_prefetch_proc__/${icon_numprefetchproc}/" NAMELIST_icon
  sed -i "s#__domainfile_icon__#${domainfile_icon}#" NAMELIST_icon
  sed -i "s#__ecraddata_dir__#ecraddata#" NAMELIST_icon # needs to be short path in ICON v2.6.4
  sed -i "s/__dateymd__/${dateymd}/" NAMELIST_icon
  sed -i "s/__outdatestart__/$(date -u -d "${startdate}" +%Y-%m-%dT%H:%M:%SZ)/" NAMELIST_icon
  sed -i "s/__outdateend__/$(date -u -d "${datep1}" +%Y-%m-%dT%H:%M:%SZ)/" NAMELIST_icon
  sed -i "s/__outname__/ICON_out_${expid}/" NAMELIST_icon
  sed -i "s/__restartname__/${expid}_restart_\<mtype\>_\<rsttime\>.nc/" NAMELIST_icon
  sed -i "s#__latbc_dir__#${icon_latbc_dir}#" NAMELIST_icon
  sed -i "s/__overcast__/${allow_overcast}/" NAMELIST_icon
  sed -i "s/__wrstmode__/${icon_rstmode}/" NAMELIST_icon

# link needed files
  [[ "$lrestart" == "false" && "$lreal" == "true" ]] && ln -sf ${icon_latbc_dir}/igaf$(date -u -d "${startdate}" +%Y%m%d%H).nc ${fname_dwdFG}
  [[ "$lrestart" == "true" ]] && ln -sf ${icon_rstfiles} ${fini_icon}
  ln -sf ${geo_dir}/icon/static/${fname_icondomain}
  ln -sf ${geo_dir}/icon/static/${fname_iconextpar}
  ln -sf ${geo_dir}/icon/static/${fname_iconghgforc}
  ln -sf ${geo_dir}/icon/static/${ecraddata:-ecraddata}

fi # if modelid == ICON

####################
# CLM
####################
if [[ "${modelid}" == *clm* ]]; then

  parse_config_file ${conf_file} "sim_config_clm"

# copy executeable
  [[ "$lcpbin" == "true" ]] && cp $tsmp2_install_dir/bin/eclm.exe eclm

# set defaults
  geo_dir_clm=${geo_dir_clm:-${geo_dir}/eclm/static}
  clm_tsp=${clm_tsp:-${cpltsp_atmsfc}}
  clmoutfrq=${clmoutfrq:--1} # in hr
  clmoutmfilt=${clmoutmfilt:-24} # number of tsp in out
  clmoutvar=${clmoutvar:-'TG'}
#
  topofile_clm=${topofile_clm:-topodata_0.9x1.25_USGS_070110_stream_c151201.nc}
  fini_clm=${fini_clm:-${simrstm1_dir}/eclm/eCLM_${EXP_ID}.clm2.r.$(date -u -d "${startdate}" +%Y-%m-%d)-$(printf "%05d" $(( $(date -d "${startdate}" +%s) % 86400 ))).nc}
  clm_frc_dir=${clm_frc_dir:-${frc_dir}/eclm/forcing/}

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
  sed -i "s/\( hist_mfilt =\).*/\1 $clmoutmfilt/" lnd_in
  sed -i "s#__fini_clm__#$fini_clm#" lnd_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" lnd_in
  sed -i "s#__domainfile_clm__#$domainfile_clm#" lnd_in
  sed -i "s#__surffile_clm__#$surffile_clm#" lnd_in
  if [[ "${modelid}" != *parflow* ]]; then
    sed -i "s/__swmm__/1/" lnd_in # soilwater_movement_method
    sed -i "s/__clmoutvar__/$clmoutvar/" lnd_in
  else
    sed -i "s/__swmm__/4/" lnd_in # soilwater_movement_method
    sed -i "s/__clmoutvar__/$clmoutvar/" lnd_in
  fi
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" datm_in
  sed -i "s/__simystart__/$(date -u -d "${startdate}" +%Y)/g" datm_in
  sed -i "s/__simyend__/$(date -u -d "${datep1}" +%Y)/g" datm_in
  sed -i "s#__domainfile_clm__#$domainfile_clm#" datm_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" drv_flds_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" mosart_in
  sed -i "s#__geo_dir_clm__#$geo_dir_clm#" datm.streams.txt*
  sed -i "s#__topofile_clm__#$topofile_clm#" datm.streams.txt.topo.observed
  # forcing
  sed -i "s#__forcdir__#${clm_frc_dir}#" datm.streams.txt.CLMCRUNCEPv7.*
  sed -i "s#__forclist__#${forcdatelist}#" datm.streams.txt.CLMCRUNCEPv7.*
  sed -i "s#__domainfile_clm__#$domainfile_clm#" datm.streams.txt.CLMCRUNCEPv7.*
fi # if modelid == CLM

####################
# PFL
####################
if [[ "${modelid}" == *parflow* ]]; then

  parse_config_file ${conf_file} "sim_config_parflow"
#
  fini_pfl=${fini_pfl:-${simrstm1_dir}/parflow/${EXP_ID}.out.${dateshort}.nc}

# copy executeable
  [[ "$lcpbin" == "true" ]] && cp $tsmp2_install_dir/bin/parflow parflow

#  set defaults
  parflow_tsp=${parflow_tsp:-$(echo "$cpltsp_sfcss / 3600" | bc -l)}
  parflow_base=${parflow_base:-0.0025}
#  parflow_inifile=${frc_dir}/parflow/ini/ic_press.pfb
  pfloutfrq=${pfloutfrq:-1.0}
  pfloutmfilt=${pfloutmfilt:-1}
  pfltsfilerst=${pfltsfilerst:-0}

# copy namelist
  [[ "$lreal" == "true" ]] && cp ${nml_dir}/parflow/ascii2pfb_slopes.tcl ascii2pfb_slopes.tcl
  [[ "$lreal" == "true" ]] && cp ${nml_dir}/parflow/ascii2pfb_SoilInd.tcl ascii2pfb_SoilInd.tcl
  cp ${nml_dir}/parflow/coup_oas.tcl coup_oas.tcl
  ln -s ${fini_pfl} .

# copy sa and pfsol files
  [[ "$lreal" == "true" ]] && cp ${geo_dir}/parflow/static/*sa .
  [[ "$lreal" == "true" ]] && cp ${geo_dir}/parflow/static/${pfl_mask} ${pfl_mask}

# PFL NML
  [[ "$lreal" == "true" ]] && sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" ascii2pfb_slopes.tcl
  [[ "$lreal" == "true" ]] && sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" ascii2pfb_slopes.tcl
  [[ "$lreal" == "true" ]] && sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" ascii2pfb_SoilInd.tcl
  [[ "$lreal" == "true" ]] && sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" ascii2pfb_SoilInd.tcl
  sed -i "s/__nprocx_pfl_bldsva__/$pfl_procX/" coup_oas.tcl
  sed -i "s/__nprocy_pfl_bldsva__/$pfl_procY/" coup_oas.tcl
  sed -i "s/__ngpflx_bldsva__/$pfl_ngx/" coup_oas.tcl
  sed -i "s/__ngpfly_bldsva__/$pfl_ngy/" coup_oas.tcl
  sed -i "s/__base_pfl__/$parflow_base/" coup_oas.tcl
  sed -i "s/__start_cnt_pfl__/0/" coup_oas.tcl
  sed -i "s/__stop_pfl_bldsva__/$(echo "${simlenhr} + ${parflow_base}" | bc -l)/" coup_oas.tcl
  sed -i "s/__dt_pfl_bldsva__/$parflow_tsp/" coup_oas.tcl
  sed -i "s/__dump_pfl_interval__/$pfloutfrq/" coup_oas.tcl
  sed -i "s/__pfl_casename__/$EXP_ID/" coup_oas.tcl
  sed -i "s#__inifile__#$(basename "$fini_pfl")#" coup_oas.tcl
  sed -i "s/__pfltsfilerst__/${pfltsfilerst}/" coup_oas.tcl
  sed -i "s/__pfloutmfilt__/${pfloutmfilt}/" coup_oas.tcl
  sed -i "s/__pfl_expid__/$EXP_ID/" slm_multiprog_mapping.conf

  # --- execute ParFlow distributeing tcl-scripts
  export PARFLOW_DIR=${tsmp2_install_dir}
  [[ "$lreal" == "true" ]] && tclsh ascii2pfb_slopes.tcl
  [[ "$lreal" == "true" ]] && tclsh ascii2pfb_SoilInd.tcl

fi # if modelid == parflow

####################
# OASIS
####################

if [[ "${run_oasis}" == true ]]; then

  parse_config_file ${conf_file} "sim_config_oas"

# set defaults
  geo_dir_oas=${geo_dir_oas:-${geo_dir}/oasis/static}

# copy namelist
  cp ${nml_dir}/oasis/namcouple_${modelid} namcouple

# OAS NML
  sed -i "s/__msglvl__/0/" namcouple
  sed -i "s/__cpltsp_as__/$cpltsp_atmsfc/" namcouple
  sed -i "s/__cpltsp_ss__/$cpltsp_sfcss/" namcouple
  sed -i "s/__simlen__/$(( $simlensec + $cpltsp_atmsfc ))/" namcouple
  sed -i "s/__icongp__/$icon_ncg/" namcouple
  sed -i "s/__eclmgpx__/$clm_ngx/" namcouple
  sed -i "s/__eclmgpy__/$clm_ngy/" namcouple
  sed -i "s/__parflowgpx__/$pfl_ngx/" namcouple
  sed -i "s/__parflowgpy__/$pfl_ngy/" namcouple

# copy remap-files
  [[ "$lreal" == "true" ]] && cp ${geo_dir_oas}/masks.nc .
  if [[ "${modelid}" == *parflow* ]]; then
    cp ${geo_dir_oas}/rmp* .
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
