#!/usr/bin/env bash
#
# test_pos_stage.sh -- run the complete ICON post-processing stage (pos_config, pos_run, pos_cleanup)
# on synthetic data and check the post files value by value. No real model output is read, nothing
# in the WFE's dta/ is written; everything goes to a new directory under ${TMPDIR:-/tmp}.
#
# Usage: bash ctl/pos_ctl/tools/test/test_pos_stage.sh <SPICE directory>
#        e.g. the PG KICS submodule .../workflow-engine_spice/spice
# Exit code 0 = all checks passed. The test directory is printed and kept for inspection.

set -eo pipefail

spice=$(realpath ${1:?usage: test_pos_stage.sh <SPICE directory>})
here=$(dirname $(realpath ${BASH_SOURCE[0]}))
ctl_dir=$(realpath ${here}/../../..)
root=$(mktemp -d ${TMPDIR:-/tmp}/pos_stage_test.XXXX)

source ${ctl_dir}/pos_ctl/tools/pos_env.jsc.2026 >/dev/null 2>&1
# Cartopy only for the generator, in a subshell: its HDF4 dependency puts an HDF4 ncdump first in PATH,
# which cannot read netCDF-4
( module load Cartopy/0.25.0 >/dev/null 2>&1; python3 ${here}/make_synthetic.py ${root} )

# the variables control_tsmp2.sh would export, for a one-day chunk
# an empty experiment config: the real expid.conf may point pos_simres at real model output
conf_file=${root}/expid_test.conf; : > ${conf_file}
modelid=icon; expid=pkp006; EXP_ID=pkp006; mailaddress=""
startdate=2001-12-01T00:00Z; datep1=2001-12-02; out_dir=${root}/dta/simres; geo_dir=${root}/geo
export pos_out=${root}/postpro/icon pos_target_grid=${root}/target_latlon_rotated.nc pos_partial=true
export pos_correct_cf=${spice}/src/python_util/correct_cf.py pos_mapping_csv=${spice}/data/csv/mapping_to_cosmo.3km.csv
export pos_ntasks=5 pos_omp=2

source ${ctl_dir}/utils_tsmp2.sh
source ${ctl_dir}/pos_ctl/pos_config.sh
source ${ctl_dir}/pos_ctl/pos_run.sh
source ${ctl_dir}/pos_ctl/pos_cleanup.sh
set +e
{ pos_config && pos_run && pos_cleanup; } 2>&1 | grep -vE '^\s*#[0-9]+:|major:|minor:|HDF5-DIAG'

python3 - ${pos_out}/2001_12 <<'EOF'
import sys, netCDF4 as nc, numpy as np
m, bad = sys.argv[1], 0
cases = (('PMSL', 'PMSL', lambda h: 100000 + 10 * h, 'lon lat'), ('T_2M', 'T_2M', lambda h: 270 + h, 'lon lat height_2m'),
         ('TOT_PREC', 'TOT_PREC', lambda h: 0.1 * h, 'lon lat'), ('SP300p', 'SP', lambda h: 5 + 0 * h, 'lon lat pressure'))
for fname, var, expect, coords in cases:
    try:
        d = nc.Dataset(f'{m}/{fname}_ts.nc')
    except OSError:
        print(f'FAIL {fname}: missing'); bad += 1; continue
    x, t = d[var][:], d['time']
    h_end = d['time_bnds'][:, 1] / 3600. if 'time_bnds' in d.variables else t[:] / 3600.
    first = nc.num2date(t[0], t.units, t.calendar).isoformat()
    checks = {
        'steps=24': len(t) == 24,
        'first step': first == ('2001-12-01T00:30:00' if fname == 'TOT_PREC' else '2001-12-01T01:00:00'),
        'values': all(np.allclose(x[i].compressed(), expect(h_end[i]), atol=1e-3) for i in range(len(t))),
        'masked cells': 0 < np.ma.count_masked(x[0]) < x[0].size,
        'fill -1e20': np.isclose(d[var]._FillValue, -1e20),
        'coordinates': d[var].coordinates == coords,
        'lon_bnds': 'lon_bnds' in d.variables,
        'rotated_pole with pole': 'rotated_pole' in d.variables
                                  and getattr(d['rotated_pole'], 'grid_north_pole_latitude', None) == 39.25,
        'no ICON param attribute': not hasattr(d[var], 'param'),
        'deflate+shuffle': bool(d[var].filters().get('zlib')) and bool(d[var].filters().get('shuffle')),
        'bounds only for sums': ('time_bnds' in d.variables) == (fname == 'TOT_PREC'),
    }
    failed = [k for k, ok in checks.items() if not ok]
    print(f"{'ok  ' if not failed else 'FAIL'} {fname}" + (f": {failed}" if failed else ''))
    bad += bool(failed)
sys.exit(bad)
EOF
rc=$?
echo "test directory: ${root}"
[[ ${rc} -eq 0 ]] && echo "TEST PASSED" || echo "TEST FAILED (${rc} file(s))"
exit ${rc}
