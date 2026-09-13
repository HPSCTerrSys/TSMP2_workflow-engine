#!/usr/bin/env python3
"""Synthetic ICON output and a Zonda-like rotated target grid, for testing the pos_ctl tools.

Mirrors the real pkp006 streams (headers of dta/simres/icon_20011201, 2026-09-13): daily files with
24 hourly steps, a one-step file for the chunk-end 00 step, no grid in the streams, the grid only
in the constants file, _FillValue -9.99e-08 in a few cells (lmask_boundary). Values are known, so the
post files can be checked exactly:
  t_2m = 270 + h, pres_msl = 100000 + 10 h, tot_prec = 0.1 h (h = hours since 2001-12-01T00),
  u = 3, v = 4 at 300 hPa  ->  SP300p = 5.
Also written: a following chunk that repeats the 2001-12-02T00 step with t_2m = 999 (must be
skipped), and a *_bku copy of the first chunk (must be ignored).

Usage: make_synthetic.py <root dir>
"""
import os
import shutil
import sys

import cartopy.crs as ccrs
import netCDF4 as nc
import numpy as np

root = sys.argv[1]
simres = f'{root}/dta/simres'
icon = f'{simres}/icon_20011201/out/icon'
os.makedirs(icon, exist_ok=True)
FILL = np.float32(-9.99e-08)

# --- target: rotated grid with the EURO-CORDEX pole, layout as Zonda's *_latlon_rotated.nc ---
rp, pc = ccrs.RotatedPole(pole_longitude=-162, pole_latitude=39.25), ccrs.PlateCarree()
rlon, rlat = np.arange(-1.0, 1.0001, 0.05), np.arange(-0.75, 0.7501, 0.05)
RLON, RLAT = np.meshgrid(rlon, rlat)
g = pc.transform_points(rp, RLON, RLAT)
LON, LAT = g[..., 0], g[..., 1]
d = 0.025
vx = np.stack([RLON - d, RLON + d, RLON + d, RLON - d], -1)
vy = np.stack([RLAT - d, RLAT - d, RLAT + d, RLAT + d], -1)
gv = pc.transform_points(rp, vx.ravel(), vy.ravel())
with nc.Dataset(f'{root}/target_latlon_rotated.nc', 'w') as t:
    for dim, size in (('rlat', len(rlat)), ('rlon', len(rlon)), ('nv', 4), ('string1', 1)):
        t.createDimension(dim, size)
    v = t.createVariable('lon', 'f8', ('rlat', 'rlon')); v[:] = LON
    v.standard_name, v.units, v.bounds = 'longitude', 'degrees_east', 'lon_vertices'
    v = t.createVariable('lat', 'f8', ('rlat', 'rlon')); v[:] = LAT
    v.standard_name, v.units, v.bounds = 'latitude', 'degrees_north', 'lat_vertices'
    t.createVariable('lon_vertices', 'f8', ('rlat', 'rlon', 'nv'))[:] = gv[:, 0].reshape(vx.shape)
    t.createVariable('lat_vertices', 'f8', ('rlat', 'rlon', 'nv'))[:] = gv[:, 1].reshape(vx.shape)
    v = t.createVariable('dummy', 'f8', ('rlat', 'rlon')); v[:] = 0.
    v.coordinates, v.grid_mapping = 'lon lat', 'rotated_pole'
    v = t.createVariable('rlon', 'f8', ('rlon',)); v[:] = rlon; v.standard_name, v.units = 'grid_longitude', 'degrees'
    v = t.createVariable('rlat', 'f8', ('rlat',)); v[:] = rlat; v.standard_name, v.units = 'grid_latitude', 'degrees'
    v = t.createVariable('rotated_pole', 'S1', ('string1',))
    v.grid_mapping_name = 'rotated_latitude_longitude'
    v.grid_north_pole_longitude, v.grid_north_pole_latitude, v.north_pole_grid_longitude = -162., 39.25, 0.

# --- source: "ICON" cells on a jittered lattice covering the target, triangles as bounds ---
lo = np.arange(np.floor(LON.min()) - 0.5, LON.max() + 0.5, 0.045)
la = np.arange(np.floor(LAT.min()) - 0.5, LAT.max() + 0.5, 0.03)
CLO, CLA = np.meshgrid(lo, la)
CLO, CLA = CLO.ravel() + 0.004 * np.sin(np.arange(CLO.size)), CLA.ravel()
n = CLO.size
fillcells = np.arange(0, n, 97)


def base(ds, ntime, t0):
    ds.createDimension('time', None); ds.createDimension('ncells', n); ds.createDimension('vertices', 3)
    tv = ds.createVariable('time', 'f8', ('time',))
    tv.standard_name, tv.calendar, tv.axis, tv.units = 'time', 'gregorian', 'T', 'minutes since 2001-12-1 00:00:00'
    tv[:] = t0 + 60. * np.arange(ntime)
    ds.Conventions, ds.uuidOfHGrid = 'CF-1.6', 'fe1e4509-59b7-d1a1-4a07-e882228b2be0'
    return tv[:] / 60.


def field(ds, name, dims, data, sn, ln, units):
    v = ds.createVariable(name, 'f4', dims, fill_value=FILL)
    data = np.array(data, dtype='f4'); data[..., fillcells] = FILL; v[:] = data
    v.standard_name, v.long_name, v.units = sn, ln, units
    v.CDI_grid_type, v.number_of_grid_in_reference, v.coordinates, v.missing_value = 'unstructured', 1, 'clat clon', FILL


def per_cell(h):
    return h[:, None] * np.ones((1, n))


for day, ntime, t0 in (('20011201', 24, 0.), ('20011202', 1, 1440.)):
    with nc.Dataset(f'{icon}/ICON_out_pkp006_1h_2d_{day}T000000Z.nc', 'w') as ds:
        h = base(ds, ntime, t0); ds.createDimension('height', 1)
        z = ds.createVariable('height', 'f8', ('height',)); z[:] = 2.
        z.standard_name, z.units, z.positive, z.axis = 'height', 'm', 'up', 'Z'
        field(ds, 't_2m', ('time', 'height', 'ncells'), (270. + per_cell(h))[:, None, :], 't_2m', 'temperature in 2m', 'K')
        field(ds, 'pres_msl', ('time', 'ncells'), 100000. + 10. * per_cell(h), 'mean sea level pressure', 'mean sea level pressure', 'Pa')
    with nc.Dataset(f'{icon}/ICON_out_pkp006_1h_acc_{day}T000000Z.nc', 'w') as ds:
        h = base(ds, ntime, t0)
        field(ds, 'tot_prec', ('time', 'ncells'), 0.1 * per_cell(h), 'tot_prec', 'total precip', 'kg m-2')
    with nc.Dataset(f'{icon}/ICON_out_pkp006_1h_pl300_{day}T000000Zp.nc', 'w') as ds:
        h = base(ds, ntime, t0); ds.createDimension('plev', 1)
        p = ds.createVariable('plev', 'f8', ('plev',)); p[:] = 30000.
        p.standard_name, p.long_name, p.units, p.positive, p.axis = 'air_pressure', 'pressure', 'Pa', 'down', 'Z'
        field(ds, 'u', ('time', 'plev', 'ncells'), np.full((ntime, 1, n), 3.), 'eastward_wind', 'Zonal wind', 'm s-1')
        field(ds, 'v', ('time', 'plev', 'ncells'), np.full((ntime, 1, n), 4.), 'northward_wind', 'Meridional wind', 'm s-1')
with nc.Dataset(f'{icon}/ICON_out_pkp006_const_20011201T000000Zc.nc', 'w') as ds:
    base(ds, 1, 0.)
    for name, val, b, sn, ln in (('clon', CLO, np.stack([CLO - 0.02, CLO + 0.02, CLO], -1), 'longitude', 'center longitude'),
                                 ('clat', CLA, np.stack([CLA - 0.012, CLA - 0.012, CLA + 0.012], -1), 'latitude', 'center latitude')):
        v = ds.createVariable(name, 'f8', ('ncells',)); v[:] = np.deg2rad(val)
        v.standard_name, v.long_name, v.units, v.bounds = sn, ln, 'radian', name + '_bnds'
        ds.createVariable(name + '_bnds', 'f8', ('ncells', 'vertices'))[:] = np.deg2rad(b)
    v = ds.createVariable('topography_c', 'f4', ('ncells',), fill_value=FILL); v[:] = 100.
    v.CDI_grid_type, v.number_of_grid_in_reference, v.coordinates = 'unstructured', 1, 'clat clon'

# following chunk repeating the 00 step (with a wrong value), and a *_bku copy
nxt = f'{simres}/icon_20011202/out/icon'; os.makedirs(nxt, exist_ok=True)
shutil.copy(f'{icon}/ICON_out_pkp006_1h_2d_20011202T000000Z.nc', nxt)
with nc.Dataset(f'{nxt}/ICON_out_pkp006_1h_2d_20011202T000000Z.nc', 'a') as ds:
    ds['t_2m'][:] = 999.
shutil.copytree(f'{simres}/icon_20011201', f'{simres}/icon_20011201_bku20260913000000')
print(f'synthetic data in {root}: {n} cells, target {RLON.shape}')
