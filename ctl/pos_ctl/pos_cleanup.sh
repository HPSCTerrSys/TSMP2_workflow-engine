#!/usr/bin/env bash
#
# function to configure tsmp2 post-processing cleanup
#
# ICON: checks the post files of every processed month (tools/post_check.sh). If all is well the
# temporary directory is removed; otherwise it is kept with the logs. The model output in
# dta/simres is never touched here.

pos_cleanup(){

echo "###"
echo "# Cleanup Post-processing"
echo "###"

if [[ "${modelid}" != *icon* ]]; then
  echo "Post-processing is implemented for ICON only; nothing to clean up for ${modelid}"
  return 0
fi

local problems=${pos_run_failed:-0}
local month m0 end nsteps hinc names name icon stream oper level role
for month in ${pos_monthstr}; do
  m0=$(date -u -d "${month/_/-}-01" +%s)
  end=$(date -u -d "${month/_/-}-01 +1 month" +%s)
  [[ $(date -u -d "${pos_chunk_end}" +%s) -lt ${end} ]] && end=$(date -u -d "${pos_chunk_end}" +%s)

  # final files and the expected step count (all four are hourly; the check takes one count per call)
  names=()
  while IFS=, read -r name icon stream hinc oper level role; do
    [[ -z ${name} || ${name} == \#* || ${name} == name || ${role} == intermediate ]] && continue
    names+=( ${name} )
    IFS=: read -r hh mm ss <<< "${hinc}"
    nsteps=$(( (end - m0) / (10#${hh} * 3600 + 10#${mm} * 60 + 10#${ss}) ))
  done < ${pos_varlist}

  echo "=== ${month}: expecting ${nsteps} steps"
  bash ${pos_tools}/post_check.sh ${pos_out}/${month} ${nsteps} "${names[@]}" || problems=$((problems + $?))
done

if [[ ${problems} -eq 0 ]]; then
  echo "Post-processing status: ok"
  rm -r ${pos_tmp}
else
  echo "Post-processing status: FAILED (${problems} problem(s)); temporary files and logs kept in ${pos_tmp}"
fi

} # pos_cleanup
