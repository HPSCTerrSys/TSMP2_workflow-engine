# pos_ctl/tools — ICON post-processing

SPICE-compatible monthly post files, one variable per file, on the rotated lat-lon grid:
`dta/postpro/icon/<YYYY_MM>/<NAME>_ts.nc`. The variables are listed in `../pos_varlist_icon.csv`
(pkp006: the four deliverables `PMSL`, `TOT_PREC`, `T_2M`, `SP300p`). The stage scripts
`../pos_config.sh`, `../pos_run.sh`, `../pos_cleanup.sh` call these tools; `lpos` in `master.conf`
switches the stage on.

| Tool | Does | Follows SPICE v2.4 |
| --- | --- | --- |
| `pos_env.jsc.2026` | modules: CDO, NCO, netCDF, Python with xarray/pandas, ncview (Stage 2026) | — |
| `post_grid.sh` | once: `icon_grid.nc` (ICON grid from the constants file), `rotated_grid_bnds.nc` (target lon/lat bounds) | `post.job.sh`, first month |
| `post_one.sh` | one post file: the month's steps from the daily ICON files → `correct_cf.py` → grid attached → `remapnn` → coordinates, time axis, global attributes → netCDF-4, deflate 1 + shuffle | `iconcor`, `timeseries`, `timeseriesp`, `remap2rot`, `cell_methods_time` |
| `post_sp.sh` | wind speed `SP<p>p` from `U<p>p`/`V<p>p` | `timeseriesap SP` |
| `post_check.sh` | per month: files present, readable, rotated grid, step count, no temporary files | `post.job.sh` checks |
| `test/test_pos_stage.sh` | the whole stage on synthetic data, checked value by value | — |

**Conventions taken from SPICE's reference post files:** a month holds the output steps in
(M-01T00, M+1-01T00]; instantaneous values without time bounds; sums (`TOT_PREC`) with `time_bnds`
and the time at the interval midpoint; fill value `-1e20`; `rotated_pole` grid mapping; 2-D
`lon`/`lat` with bounds; scalar `height_2m` / `pressure`.

**Reused unchanged from SPICE** through the linker script (`aux/link_pgkics_to_wfe.sh` of the pkp006
workspace): `correct_cf.py` and `mapping_to_cosmo.3km.csv` in `dta/geo/icon/spice/`. The target grid is
Zonda's `*_DOM01_latlon_rotated.nc` in `dta/geo/icon/static/`.

**Learned while testing:**
- CDO reuses nearest-neighbour weights only when the field's missing-value mask equals the one the
  weights were built with. `post_one.sh` therefore builds `remapnn_weights_<NAME>.nc` from each
  variable's own first step, once, and warns if CDO still recomputes them.
- CDO does not always write the target `lon_bnds`/`lat_bnds` when remapping with a weights file;
  they are appended from `rotated_grid_bnds.nc`.
- A time step written by two chunks (chunk end and next chunk start) is taken once
  (`SKIP_SAME_TIME=1` for `mergetime`); `*_bku*` result directories are ignored.
- netCDF-4.9/HDF5 print harmless `HDF5-DIAG` messages when probing output files that do not exist yet.

Test: `bash ctl/pos_ctl/tools/test/test_pos_stage.sh <SPICE dir>`
