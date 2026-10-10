#!/usr/bin/env bash
#
# function to configure tsmp2 post-processing
#
# ICON: SPICE-compatible monthly post files, one variable per file, on the rotated lat-lon grid,
# written to dta/postpro/icon/<YYYY_MM>/<NAME>_ts.nc. Variables: pos_varlist_icon.csv; tools: tools/.
# Settings can be overridden in the [pos_config_icon] section of expid.conf.

pos_config(){

echo "###"
echo "# Configure Post-processing"
echo "###"

if [[ "${modelid}" != *icon* ]]; then
  echo "Post-processing is implemented for ICON only; nothing to configure for ${modelid}"
  return 0
fi

parse_config_file ${conf_file} "pos_config_icon"

# --- paths ------------------------------------------------------------------------------------
pos_tools=${ctl_dir}/pos_ctl/tools
pos_varlist=${pos_varlist:-${ctl_dir}/pos_ctl/pos_varlist_icon.csv}
pos_simres=${pos_simres:-${out_dir}}
pos_out=${pos_out:-$(realpath -m ${ctl_dir}/../dta/postpro/icon)}
pos_tmp=${pos_tmp:-${pos_out}/tmp_$(date -u -d "${startdate}" +%Y%m%d)}
# the rotated target grid and SPICE's CF correction come from the PG KICS repo via the linker script
pos_target_grid=${pos_target_grid:-${geo_dir}/icon/static/EUR-3_R13B07_v20260423-00_DOM01_latlon_rotated.nc}
pos_spice_dir=${pos_spice_dir:-${geo_dir}/icon/spice}
pos_correct_cf=${pos_correct_cf:-${pos_spice_dir}/correct_cf.py}
pos_mapping_csv=${pos_mapping_csv:-${pos_spice_dir}/mapping_to_cosmo.3km.csv}

# --- parallelism ----------------------------------------------------------------------------
pos_ntasks=${pos_ntasks:-8}   # post_one.sh processes at a time
pos_omp=${pos_omp:-4}         # CDO threads per process

# --- global attributes of the post files (SPICE iconcor) -----------------------------------------
pos_ga_title=${pos_ga_title:-"${EXP_ID} ICON simulation with the TSMP2 workflow engine"}
pos_ga_institution=${pos_ga_institution:-""}
pos_ga_project_id=${pos_ga_project_id:-"-"}
pos_ga_realization=${pos_ga_realization:-1}
pos_ga_contact=${pos_ga_contact:-${mailaddress}}
pos_ga_icon_version=${pos_ga_icon_version:-"ICON"}
pos_ga_references=${pos_ga_references:-"https://www.icon-model.org/"}

# --- months to process ----------------------------------------------------------------------
# A month holds the output steps in (M-01T00, M+1-01T00] (as the SPICE reference post files), so
# a month is processed once a chunk has simulated up to M+1-01T00. pos_months=(YYYY_MM ...) in
# expid.conf overrides; pos_partial=true also processes an incomplete month up to the chunk end
# (tests with chunks shorter than a month).
pos_partial=${pos_partial:-false}
pos_chunk_start=$(date -u -d "${startdate}" +%Y-%m-%dT%H:%M:%S)
pos_chunk_end=$(date -u -d "${datep1}" +%Y-%m-%dT%H:%M:%S)
pos_months=( ${pos_months[*]:-} )   # a plain string from expid.conf becomes an array
if [[ ${#pos_months[@]} -eq 0 ]]; then
  pos_months=()
  m=$(date -u -d "${pos_chunk_start}" +%Y-%m-01)
  [[ $(date -u -d "${m}" +%s) -lt $(date -u -d "${pos_chunk_start}" +%s) ]] && m=$(date -u -d "${m} +1 month" +%Y-%m-01)
  while [[ $(date -u -d "${m} +1 month" +%s) -le $(date -u -d "${pos_chunk_end}" +%s) ]]; do
    pos_months+=( $(date -u -d "${m}" +%Y_%m) )
    m=$(date -u -d "${m} +1 month" +%Y-%m-01)
  done
  if [[ ${#pos_months[@]} -eq 0 && ${pos_partial} == true ]]; then
    pos_months=( $(date -u -d "${pos_chunk_start}" +%Y_%m) )
  fi
fi
pos_monthstr="${pos_months[*]}"

echo "pos_out:      ${pos_out}"
echo "pos_simres:   ${pos_simres}"
echo "pos_varlist:  ${pos_varlist}"
echo "target grid:  ${pos_target_grid}"
echo "months:       ${pos_monthstr:-none} (chunk ${pos_chunk_start} .. ${pos_chunk_end}, partial=${pos_partial})"

# --- checks and one-off preparation --------------------------------------------------------------
for f in ${pos_varlist} ${pos_target_grid} ${pos_correct_cf} ${pos_mapping_csv}; do
  [[ -f ${f} ]] || { echo "ERROR pos_config: missing ${f}"; return 1; }
done
mkdir -p ${pos_out} ${pos_tmp}

if [[ ! -f ${pos_out}/icon_grid.nc || ! -f ${pos_out}/rotated_grid_bnds.nc ]]; then
  pos_const=$(ls -1 ${pos_simres}/${caseid}${modelid}_*/out/icon/ICON_out_${expid}_const_*.nc 2>/dev/null | grep -v '_bku' | sort | head -n 1 || true)
  [[ -n ${pos_const} ]] || { echo "ERROR pos_config: no ICON constants file (ICON_out_${expid}_const_*.nc) in ${pos_simres}"; return 1; }
  bash ${pos_tools}/post_grid.sh ${pos_const} ${pos_target_grid} ${pos_out} || return 1
fi

export pos_tools pos_varlist pos_simres pos_out pos_tmp pos_target_grid pos_spice_dir pos_correct_cf \
       pos_mapping_csv pos_ntasks pos_omp pos_partial pos_chunk_end pos_monthstr \
       pos_ga_title pos_ga_institution pos_ga_project_id pos_ga_realization pos_ga_contact \
       pos_ga_icon_version pos_ga_references expid caseid modelid

} # pos_config
