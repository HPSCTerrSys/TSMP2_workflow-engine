#!/usr/bin/env bash
#
# post_grid.sh -- one-off grid preparation for post-processing (SPICE post.job.sh, first month)
#
# Writes into <outdir>:
#   icon_grid.nc           clon, clat, clon_bnds, clat_bnds of the ICON grid. post_one.sh attaches it
#                          to every raw extract before remapping, because the output streams carry
#                          no grid (output_grid = .FALSE. except in the constants stream).
#   rotated_grid_bnds.nc   lon_bnds, lat_bnds of the rotated target grid, as CDO writes them. CDO does
#                          not always write the bounds when remapping with a weights file; post_one.sh
#                          appends them from here, so every post file carries them like the SPICE files.
#
# The nearest-neighbour weights are not built here: CDO reuses remapping weights only when the source
# missing-value mask matches the field's, so post_one.sh builds them per variable from its own data.
#
# Usage: post_grid.sh <icon constants file with grid> <target grid file> <outdir>
# Existing files are kept; remove them to rebuild.

set -euo pipefail

const=$1
target=$2
outdir=$3
grid=${outdir}/icon_grid.nc
bnds=${outdir}/rotated_grid_bnds.nc

for f in ${const} ${target}; do
  [[ -f ${f} ]] || { echo "ERROR post_grid: missing ${f}" >&2; exit 1; }
done
mkdir -p ${outdir}

if [[ -f ${grid} ]]; then
  echo "post_grid: reusing ${grid}"
else
  grep -qE '^\s+double clon\(' <<< "$(ncdump -h ${const})" || { echo "ERROR post_grid: no clon/clat in ${const}" >&2; exit 1; }
  ncks -h -O -v clon,clat,clon_bnds,clat_bnds ${const} ${grid}.tmp
  ncatted -h -a ,global,d,, ${grid}.tmp
  mv ${grid}.tmp ${grid}
  echo "post_grid: wrote ${grid}"
fi

if [[ -f ${bnds} ]]; then
  echo "post_grid: reusing ${bnds}"
else
  tmpl=${outdir}/rotated_grid_tmpl.nc.tmp$$
  cdo -s -f nc4 remapnn,${target} -selname,topography_c ${const} ${tmpl}
  grep -qE '^\s+double lon_bnds\(' <<< "$(ncdump -h ${tmpl})" || { echo "ERROR post_grid: CDO wrote no lon_bnds for ${target}" >&2; exit 1; }
  ncks -h -O -v lon_bnds,lat_bnds ${tmpl} ${bnds}.tmp
  ncatted -h -a ,global,d,, ${bnds}.tmp
  mv ${bnds}.tmp ${bnds}
  rm ${tmpl}
  echo "post_grid: wrote ${bnds}"
fi
