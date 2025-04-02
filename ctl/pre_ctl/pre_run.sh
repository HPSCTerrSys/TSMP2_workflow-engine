#!/usr/bin/env bash
#
# function to run tsmp2 preprocessing

pre_run(){

echo "Start Pre-processing run"

####################
# CLM
####################
if [[ "${modelid}" == *clm* ]]; then

echo "Start processing clm"

module use $OTHERSTAGES
module load Stages/2022  NVHPC/22.9  ParaStationMPI/5.5.0-1 CDO/2.0.2 NCO


# list contain dates needed for forcing
for yyyymm in "${listfrcfile[@]}"; do
   year="${yyyymm%%-*}"
   month="${yyyymm#*-}"
   mkdir -p $yyyymm # temporary directory for scripts

   # extract data from ERA5 meteocloud
   srun --exclusive -n 1 ${lsmforcgensrc_dir}/extract_ERA5_meteocloud.sh iyear=$year imonth=$month \
        outdir=${pre_dir}/${yyyymm} #quiet=y

#  # needs to be done in advance
#   # download from CDSAPI needs
#   python ${lsmforcgensrc_dir}/download_ERA5_input.py $year $month ${pre_dir}/${yyyymm}

   # link cdsapi data for preparation script
   ln -s ${cdsapi_dtadir}/download_era5_${year}_$month.zip ${yyyymm}/

   # preparation script
   srun --exclusive -n 1 ${lsmforcgensrc_dir}/prepare_ERA5_input.sh pathdata=${pre_dir}/${yyyymm} \
	                  iyear=$year imonth=$month wrkdir=${yyyymm}

done
unset yyyymm year month

fi

} # pre_run

