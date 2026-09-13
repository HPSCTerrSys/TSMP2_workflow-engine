#!/usr/bin/env bash
#
# post_sp.sh -- wind speed on a pressure level from the U and V post files (SPICE timeseriesap SP)
#
# Usage: post_sp.sh <U<p>p_ts.nc> <V<p>p_ts.nc> <SP<p>p_ts.nc>
# Environment: pos_tmp

set -euo pipefail

ufile=$1 vfile=$2 outfile=$3
for f in ${ufile} ${vfile}; do
  [[ -f ${f} ]] || { echo "ERROR post_sp: missing ${f}" >&2; exit 1; }
done

tmp=${pos_tmp}/SP_$(basename ${outfile} .nc)_$$
mkdir -p ${tmp}
cd ${tmp}
trap 'echo "ERROR post_sp: failed, temporary files kept in ${tmp}" >&2' ERR

nccopy -k nc4 ${ufile} uv.nc
ncks -h -A -v V ${vfile} uv.nc
cdo -s -f nc4 expr,'SP=(U^2+V^2)^0.5;' uv.nc sp.nc

# SPICE cdocor: missing value, coordinates attribute and coordinate variables from the U file
cdo -s setmissval,-1.E20 sp.nc sp1.nc && mv sp1.nc sp.nc
coords=$(ncdump -h uv.nc | sed -nE 's/^\s+U:coordinates = "(.*)" ;/\1/p')
ncatted -h -a coordinates,SP,o,c,"${coords}" sp.nc
copy=$(echo ${coords} | tr ' ' ','),rotated_pole   # always: cdo expr writes rotated_pole without the pole parameters
if grep -qE '^\s+\w+ lon_bnds\(' <<< "$(ncdump -h uv.nc)"; then copy=${copy},lon_bnds,lat_bnds; fi
ncks -h -A -C -v ${copy} uv.nc sp.nc

ncatted -h -O \
  -a standard_name,SP,o,c,'wind_speed' \
  -a long_name,SP,o,c,'wind speed' \
  -a units,SP,o,c,'m s-1' \
  -a cell_methods,SP,o,c,'time: point' \
  -a grid_mapping,SP,o,c,'rotated_pole' \
  -a institution,,d,, \
  -a creation_date,global,o,c,"$(date '+%Y-%m-%d %H:%M:%S %Z')" \
  sp.nc

mkdir -p $(dirname ${outfile})
nccopy -k nc4 -d 1 -s sp.nc ${outfile}.tmp
mv ${outfile}.tmp ${outfile}

trap - ERR
cd ${pos_tmp}
rm -r ${tmp}
echo "post_sp: wrote ${outfile}"
