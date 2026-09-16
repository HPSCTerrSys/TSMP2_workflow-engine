#!/usr/bin/env bash
#
# function to run tsmp2 post-processing
#
# ICON: for every month, all table lines with role deliver/intermediate in parallel (post_one.sh),
# then the derived ones (post_sp.sh). Logs: ${pos_tmp}/<YYYY_MM>/<name>.log with <name>.rc.
#
# A variable that succeeded has the benign HDF5 probe block dropped from its log (drop_hdf5_probe):
# some tool in the chain asks whether a file that does not exist yet is an HDF5 file, and HDF5 prints
# a ten-line error block for it. It looks like a failure in an archived log but is not one -- such a
# block always contains "errno = 2 ... No such file or directory". A variable that FAILED keeps its
# log exactly as written, so nothing is ever hidden from a real problem.

# drop_hdf5_probe <logfile> -- remove HDF5-DIAG blocks caused by probing a non-existent file
drop_hdf5_probe(){
  local f=$1
  [[ -s ${f} ]] || return 0
  grep -q "errno = 2" ${f} 2>/dev/null || return 0
  awk '
    /^HDF5-DIAG:/                           { if (inblk && !benign) print blk
                                              inblk=1; blk=$0; benign=0; next }
    inblk && /^(  #|    major:|    minor:)/ { blk=blk ORS $0
                                              if ($0 ~ /errno = 2/) benign=1; next }
    inblk                                   { if (!benign) print blk; inblk=0; print; next }
                                            { print }
    END                                     { if (inblk && !benign) print blk }
  ' ${f} > ${f}.tmp$$ && command mv ${f}.tmp$$ ${f}
}

pos_run(){

echo "###"
echo "# Run Post-processing"
echo "###"

if [[ "${modelid}" != *icon* ]]; then
  echo "Post-processing is implemented for ICON only; nothing to run for ${modelid}"
  return 0
fi

pos_run_failed=0
for month in ${pos_monthstr}; do

  # selection window (M-01T00, M+1-01T00], cut at the chunk end for an incomplete month
  local m0 m1 end
  m0=$(date -u -d "${month/_/-}-01" +%Y-%m-%dT%H:%M:%S)
  m1=$(date -u -d "${month/_/-}-01 +1 month" +%Y-%m-%dT%H:%M:%S)
  end=${m1}
  if [[ $(date -u -d "${pos_chunk_end}" +%s) -lt $(date -u -d "${m1}" +%s) ]]; then end=${pos_chunk_end}; fi
  # epoch arithmetic: GNU date reads "<time> +1 second" as a UTC+1 offset
  export pos_sel_start=$(date -u -d "@$(( $(date -u -d "${m0}" +%s) + 1 ))" +%Y-%m-%dT%H:%M:%S)
  export pos_sel_end=${end}

  local mtmp=${pos_tmp}/${month}
  mkdir -p ${pos_out}/${month} ${mtmp}/intermediate
  echo "=== ${month}: ${pos_sel_start} .. ${pos_sel_end}"

  # --- pass 1: extract and remap (deliver, intermediate) ---
  local name icon stream hinc oper level role out
  while IFS=, read -r name icon stream hinc oper level role; do
    [[ -z ${name} || ${name} == \#* || ${name} == name ]] && continue
    [[ ${role} == derived:* ]] && continue
    out=${pos_out}/${month}/${name}_ts.nc
    [[ ${role} == intermediate ]] && out=${mtmp}/intermediate/${name}_ts.nc
    while [[ $(jobs -rp | wc -l) -ge ${pos_ntasks} ]]; do sleep 2; done
    ( bash ${pos_tools}/post_one.sh ${name} ${icon} ${stream} ${hinc} ${oper} ${level} ${out} \
        > ${mtmp}/${name}.log 2>&1; echo $? > ${mtmp}/${name}.rc ) &
  done < ${pos_varlist}
  wait

  # --- pass 2: derived quantities ---
  while IFS=, read -r name icon stream hinc oper level role; do
    [[ ${role} != derived:* ]] && continue
    case ${role#derived:} in
      sp) ( bash ${pos_tools}/post_sp.sh ${mtmp}/intermediate/U${level}p_ts.nc ${mtmp}/intermediate/V${level}p_ts.nc \
              ${pos_out}/${month}/${name}_ts.nc > ${mtmp}/${name}.log 2>&1; echo $? > ${mtmp}/${name}.rc ) ;;
      *)  echo "ERROR pos_run: unknown recipe ${role} for ${name}"; echo 1 > ${mtmp}/${name}.rc ;;
    esac
  done < ${pos_varlist}

  # --- status ---
  local rc
  for rc in ${mtmp}/*.rc; do
    if [[ $(cat ${rc}) != 0 ]]; then
      echo "FAILED  $(basename ${rc} .rc) -- see ${rc%.rc}.log"
      pos_run_failed=1
    else
      drop_hdf5_probe "${rc%.rc}.log"
      echo "ok      $(basename ${rc} .rc)"
    fi
  done

done

export pos_run_failed
} # pos_run
