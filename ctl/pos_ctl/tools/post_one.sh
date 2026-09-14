#!/usr/bin/env bash
#
# post_one.sh -- one SPICE-compatible monthly post file from TSMP2-WFE ICON output
#
# Follows SPICE v2.4 (configure_scripts/template_gcm2icon/scripts): arch.job.sh -> iconcor
# (correct_cf.py), post.job.sh -> timeseries / timeseriesp -> remap2rot -> cell_methods_time.
#
# Usage: post_one.sh <name> <icon_name> <stream> <hout_inc> <operation|-> <level_hPa|-> <outfile>
#
# Environment (set by pos_config.sh):
#   pos_simres     directory holding the chunk result directories (dta/simres), searched as
#                  icon_*/out/icon/ICON_out_<expid>_<stream>_<YYYYMMDD>...nc[_part_<n>+], *_bku* excluded
#                  (after a restart ICON logs "Modify filename ... _part_<n>+" for each stream's first
#                  file, but 2026.04 keeps the plain name, F38; the pattern accepts both)
#   pos_out        post-processing directory with icon_grid.nc and remapnn_weights.nc
#   pos_tmp        scratch directory for temporary files
#   pos_target_grid, pos_mapping_csv, pos_correct_cf, expid
#   pos_sel_start, pos_sel_end   selection window (ISO), e.g. 2001-12-01T00:00:01 .. 2002-01-01T00:00:00:
#                  a month holds the output steps in (M-01T00, M+1-01T00], as the SPICE reference files
#   pos_omp        CDO threads
#   pos_ga_*       global attributes (title, institution, project_id, realization, contact,
#                  icon_version, references)

set -euo pipefail

name=$1 var=$2 stream=$3 hinc=$4 oper=$5 level=$6 outfile=$7
[[ ${oper} == - ]] && oper=""

tmp=${pos_tmp}/${name}_$(basename ${outfile} .nc)_$$
mkdir -p ${tmp}
cd ${tmp}
trap 'echo "ERROR post_one ${name}: failed, temporary files kept in ${tmp}" >&2' ERR

# --- 1. input files: every daily file whose date lies in the selection window --------------------
d0=$(date -u -d "${pos_sel_start}" +%Y%m%d)
d1=$(date -u -d "${pos_sel_end}" +%Y%m%d)
files=()
while IFS= read -r f; do
  fdate=$(basename ${f} | sed -E "s/^ICON_out_${expid}_${stream}_([0-9]{8})T.*/\1/")
  if [[ ${fdate} -ge ${d0} && ${fdate} -le ${d1} ]]; then files+=("${f}"); fi
done < <(ls -1 ${pos_simres}/icon_*/out/icon/ICON_out_${expid}_${stream}_[0-9]*T[0-9]*Z*.nc* 2>/dev/null \
         | grep -v '_bku' | sort -t_ -k1,1 || true)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "ERROR post_one ${name}: no ICON_out_${expid}_${stream}_*.nc between ${d0} and ${d1} in ${pos_simres}" >&2
  exit 1
fi
echo "post_one ${name}: ${#files[@]} input files, ${pos_sel_start} .. ${pos_sel_end}"

# --- 2. extract the variable and the month's steps ------------------------------------------------
# SKIP_SAME_TIME: a time step written twice (chunk end and next chunk start, O45) is taken once
levsel=""
[[ ${level} != - ]] && levsel="-sellevel,$(( level * 100 ))"
SKIP_SAME_TIME=1 cdo -s -r -f nc4 ${levsel} -seldate,${pos_sel_start},${pos_sel_end} \
    -mergetime -apply,-selname,${var} [ "${files[@]}" ] raw.nc

# pressure levels: SPICE's iconcor renames plev -> pressure before the CF correction
if [[ ${level} != - ]]; then
  ncrename -h -d plev,pressure -v plev,pressure raw.nc >/dev/null
fi

# --- 3. SPICE CF correction: post name, standard_name, cell_methods, time_bnds, 2 m height --------
python3 ${pos_correct_cf} ${hinc} ${pos_mapping_csv} raw.nc ${oper}
post_var=$(sed -nE 's/^\s+float ([A-Z0-9_]+)\(.*/\1/p' <<< "$(ncdump -h raw.nc)")
post_var=${post_var%%$'\n'*}   # first match; no "| head", which breaks pipes under pipefail
[[ -n ${post_var} ]] || { echo "ERROR post_one ${name}: no upper-case float variable after correct_cf" >&2; exit 1; }

# pressure level: remove the level dimension, keep a scalar pressure coordinate (SPICE timeseriesp)
scalar=""
if [[ ${level} != - ]]; then
  ncwa -h -O --no_cell_methods -a pressure raw.nc raw1.nc && mv raw1.nc raw.nc
  scalar=pressure
elif grep -qE '^\s+double height_2m ;' <<< "$(ncdump -h raw.nc)"; then
  scalar=height_2m
elif grep -qE '^\s+double height_10m ;' <<< "$(ncdump -h raw.nc)"; then
  scalar=height_10m
fi
if [[ -n ${scalar} ]]; then
  ncks -h -O -C -v ${scalar} raw.nc scalar.nc
  ncatted -h -a ,global,d,, scalar.nc
fi

# --- 4. attach the ICON grid and remap to the rotated grid (SPICE remap2rot) --------------------
if ! grep -qE '^\s+double clon\(' <<< "$(ncdump -h raw.nc)"; then
  ncks -h -A ${pos_out}/icon_grid.nc raw.nc
fi
ncatted -h -a coordinates,${post_var},o,c,"clon clat" raw.nc
cdo -s setmissval,-1e20 raw.nc rawm.nc && mv rawm.nc raw.nc

# nearest-neighbour weights: CDO reuses weights only if the source missing-value mask matches the
# field's (lmask_boundary), so they are built from this variable's own first step, once per post
# name, and kept in ${pos_out}
weights=${pos_out}/remapnn_weights_${name}.nc
if [[ ! -f ${weights} ]]; then
  cdo -s -P ${pos_omp} gennn,${pos_target_grid} -seltimestep,1 raw.nc ${weights}.tmp$$
  mv ${weights}.tmp$$ ${weights}
fi
cdo -P ${pos_omp} -f nc4 remap,${pos_target_grid},${weights} raw.nc rot.nc 2> remap.log || { cat remap.log >&2; exit 1; }
if grep -q 'not used' remap.log; then
  echo "WARNING post_one ${name}: $(grep 'not used' remap.log) -- weights recomputed on the fly (slow)" >&2
fi
rm raw.nc

keep=${post_var},lon,lat
hdr=$(ncdump -h rot.nc)
if grep -qE '^\s+\w+ rotated_pole' <<< "${hdr}"; then keep=${keep},rotated_pole; fi
if grep -qE '^\s+\w+ lon_bnds\(' <<< "${hdr}"; then keep=${keep},lon_bnds,lat_bnds; fi
ncks -h -O -v ${keep} rot.nc keep.nc
rm rot.nc
ncatted -h -a institution,,d,, keep.nc
# lon/lat bounds as in the SPICE files: CDO does not always write them when remapping with weights
if ! grep -qE '^\s+\w+ lon_bnds\(' <<< "$(ncdump -h keep.nc)"; then
  ncks -h -A -v lon_bnds,lat_bnds ${pos_out}/rotated_grid_bnds.nc keep.nc
  ncatted -h -a bounds,lon,o,c,lon_bnds -a bounds,lat,o,c,lat_bnds keep.nc
fi

if [[ -n ${scalar} ]]; then
  ncks -h -A scalar.nc keep.nc
  ncatted -h -a coordinates,${post_var},o,c,"lon lat ${scalar}" keep.nc
else
  ncatted -h -a coordinates,${post_var},o,c,"lon lat" keep.nc
fi

# --- 5. time axis (SPICE cell_methods_time) --------------------------------------------------------
# sums and means: time = middle of time_bnds; instantaneous values: no bounds
cm=$(ncdump -h keep.nc | sed -nE "s/^\s+${post_var}:cell_methods = \"(.*)\" ;/\1/p")
if [[ -n ${cm} && ${cm} != *"time: point"* ]]; then
  ncwa -h -O -C -v time_bnds -a bnds keep.nc t1.nc
  ncap2 -h -O -s "time=time_bnds" t1.nc t2.nc
  ncks -h -O -v time t2.nc t1.nc
  ncatted -h -a ,time,d,,, t1.nc
  ncks -h -A t1.nc keep.nc
  rm t1.nc t2.nc
else
  if grep -qE '^\s+double time_bnds\(' <<< "$(ncdump -h keep.nc)"; then
    ncatted -h -a bounds,time,d,, keep.nc
    ncks -h -O -x -v time_bnds keep.nc t1.nc && mv t1.nc keep.nc
  fi
fi

# --- 6. global attributes (SPICE iconcor) ---------------------------------------------------------
ncatted -h -a institution,,d,, -a param,,d,, \
  -a title,global,o,c,"${pos_ga_title}" \
  -a institution,global,o,c,"${pos_ga_institution}" \
  -a project_id,global,o,c,"${pos_ga_project_id}" \
  -a experiment_id,global,o,c,"${expid}" \
  -a realization,global,o,c,"${pos_ga_realization}" \
  -a Conventions,global,o,c,"CF-1.4" \
  -a ConventionsURL,global,o,c,"http://www.cfconventions.org/" \
  -a contact,global,o,c,"${pos_ga_contact}" \
  -a icon-clm_version,global,o,c,"${pos_ga_icon_version}" \
  -a references,global,o,c,"${pos_ga_references}" \
  -a creation_date,global,o,c,"$(date '+%Y-%m-%d %H:%M:%S %Z')" \
  keep.nc

# --- 7. write: compressed netCDF-4, deflate 1 + shuffle (PV2) --------------------------------------
mkdir -p $(dirname ${outfile})
nccopy -k nc4 -d 1 -s keep.nc ${outfile}.tmp
mv ${outfile}.tmp ${outfile}

trap - ERR
cd ${pos_tmp}
rm -r ${tmp}
echo "post_one ${name}: wrote ${outfile} (${post_var})"
