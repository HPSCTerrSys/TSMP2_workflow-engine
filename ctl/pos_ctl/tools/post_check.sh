#!/usr/bin/env bash
#
# post_check.sh -- check the post files of one month (SPICE post.job.sh checks, plus the step count)
#
# Usage: post_check.sh <month dir> <expected number of time steps> <name> [<name> ...]
# Checks per file <name>_ts.nc: exists, readable by CDO, on the rotated grid, expected step count.
# Also: no *.tmp files left in the month directory. Exit code = number of problems found.

set -uo pipefail

dir=$1 nexp=$2
shift 2
problems=0

for name in "$@"; do
  f=${dir}/${name}_ts.nc
  if [[ ! -f ${f} ]]; then
    echo "  MISSING   ${name}_ts.nc"; problems=$((problems + 1)); continue
  fi
  if ! cdo -s showname ${f} >/dev/null 2>&1; then
    echo "  UNREADABLE ${name}_ts.nc"; problems=$((problems + 1)); continue
  fi
  if ! grep -q 'rotated_latitude_longitude' <<< "$(ncdump -h ${f})"; then
    echo "  NOT ROTATED ${name}_ts.nc"; problems=$((problems + 1))
  fi
  n=$(cdo -s ntime ${f} 2>/dev/null | tail -1)
  if [[ ${n} != ${nexp} ]]; then
    echo "  STEPS     ${name}_ts.nc: ${n}, expected ${nexp}"; problems=$((problems + 1))
  else
    echo "  OK        ${name}_ts.nc: ${n} steps, $(du -h ${f} | cut -f1)"
  fi
done

shopt -s nullglob
leftovers=( ${dir}/*.tmp )
if [[ ${#leftovers[@]} -gt 0 ]]; then
  echo "  TEMPORARY files left: ${leftovers[*]}"; problems=$((problems + 1))
fi

exit ${problems}
