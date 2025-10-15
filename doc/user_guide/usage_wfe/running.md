# Run experiment

If you want to store your run directory files elsewhere than here, set a simulation ID (replace `MY-SIMULATION`) and make `${wfe_dir}/run` into a symlink pointing to your new directory.

```bash
cd ${wfe_dir}
export sim_id=MY-SIMULATION
export scratch_dir=$SCRATCH/$USER/$sim_id
mkdir -p $scratch_dir/run
git rm run/.gitkeep
ln -snf $scratch_dir/run run
```

The configuration of the simulation is managed by two shell-based configure files besides the git submodules. `master.conf` for generic setting such as simulation time or model-id and `expid.conf` for doing component specific settings.

Adapt resources and time in the setup-script.

```bash
cd ${wfe_dir}/ctl
vi master.conf
```

Start simulation

```bash
./control_tsmp2.sh
```

## master.conf

The `master.conf` file contains general configuration settings for the
workflow engine. It is located in `ctl/master.conf`.

### Main Settings

#### MODEL_ID

Specifies which model components to use. Options include but are not
restriced to:

- `ParFlow` - ParFlow only
- `ICON-eCLM` - ICON atmosphere with eCLM land surface
- `ICON-eCLM-ParFlow` - Fully coupled system
- `ICON` - ICON atmosphere only

#### EXP_ID

Experiment identifier (e.g., `"eur-11u"`). Used for naming and
organizing simulation outputs.

#### CASE_ID

Optional identifier for specific cases within an experiment.

#### conf_file

Path to case-specific configuration file. If left empty, the system
will look for `${ctl_dir}/expid.conf`.

### Main Switches

Each workflow stage has three boolean flags: `config`, `run`,
`cleanup`.

#### lpre

Preprocessing stage switches: `( config run cleanup )`

- `config`: Configure preprocessing
- `run`: Execute preprocessing
- `cleanup`: Clean up preprocessing files

#### lsim

Simulation stage switches: `( config run cleanup )`

- `config`: Configure simulation
- `run`: Execute simulation
- `cleanup`: Clean up simulation files

#### lpos

Post-processing stage switches: `( config run cleanup )`

- `config`: Configure post-processing
- `run`: Execute post-processing
- `cleanup`: Clean up post-processing files

#### lvis

Visualization stage switches: `( config run cleanup )`

- `config`: Configure visualization
- `run`: Execute visualization
- `cleanup`: Clean up visualization files

### Time Information

#### cpltsp_atmsfc

Coupling time step between atmosphere and surface (eCLM timestep) in
seconds. Default: `900`.

#### cpltsp_sfcss

Coupling time step between surface and subsurface (ParFlow timestep)
in seconds. Default: `900`.

#### simlength

Length of each simulation step (e.g., `"1 day"`, `"23 hours"`).

#### startdate

Start date of the simulation in ISO 8601 format (e.g.,
`"2017-07-01T00:00Z"`).

#### inidate

Initial date for the entire simulation in ISO 8601 format. Default:
same as `startdate`.

#### numsimstep

Number of simulation steps.

Total simulation time = `numsimstep * simlength`.

Each simulation step is a queued job on the machine. The next job is
only executed once the previous is done.

### Mail Notification

#### mailtype

Email notification trigger for SLURM jobs. Options: `NONE`, `BEGIN`,
`END`, `FAIL`, `REQUEUE`, `ALL`.

#### mailaddress

Email address for job notifications. Leave empty if `mailtype=NONE`.

### User Settings

#### prevjobid

Previous job ID for job chaining. Leave empty by default; system will
manage this automatically.

#### npnode

Number of cores per node. Leave empty to use machine defaults.

#### partition

Compute partition to use. Leave empty to use machine defaults.

#### account

Compute account for billing. If not set, `$BUDGET_ACCOUNTS` or `slts`
will be used.

### Wallclock Times

Wallclock time limits for each workflow stage in `hh:mm:ss` format.

#### pre_wallclock

Time limit for preprocessing jobs (e.g., `00:35:00`).

#### sim_wallclock

Time limit for simulation jobs (e.g., `00:25:00`).

#### pos_wallclock

Time limit for post-processing jobs (e.g., `00:05:00`).

#### vis_wallclock

Time limit for visualization jobs (e.g., `00:05:00`).

### File/Directory Paths

#### tsmp2_dir

Path to TSMP2 directory. Uses `$TSMP2_DIR` environment variable.

#### tsmp2_install_dir

Path to TSMP2 installation directory. Leave empty to use default.

#### tsmp2_env

Path to TSMP2 environment file. Leave empty to use default.

### Node Allocation

Number of nodes allocated to each model component. Components not
indicated in `MODEL_ID` will have their node count set to zero.

#### ico_node

Number of nodes for ICON atmosphere component. Default: `3`.

#### clm_node

Number of nodes for eCLM land surface component. Default: `1`.

#### pfl_node

Number of nodes for ParFlow subsurface component. Default: `2`.

### Debug and Logging

#### debugmode

If set to `true`, no job submission is carried out. Works only for
`config` steps.

Useful for testing configuration without running jobs.

Useful for running single tasks, e.g. namelist creation.

#### joblog

If set to `true`, job status will be logged. Default: `true`.

## expid.conf

The `expid.conf` file contains component-specific configuration
settings for the workflow engine. It is located in `ctl/expid.conf` by
default, or at the path specified by `conf_file` in `master.conf`.

The file is organized into sections for each workflow stage
(preprocessing, simulation, post-processing, visualization) and
further subdivided by component.

### Preprocessing Configuration

#### [pre_config_clm]

Configuration settings for eCLM preprocessing stage. Currently empty
in the default configuration.

### Simulation Configuration

#### [sim_config_general]

General simulation configuration settings applicable across all
components. Currently empty in the default configuration.

#### [sim_config_icon]

ICON atmosphere component configuration.

##### icon_numioprocs

Number of I/O processors for ICON. Controls how many processes handle
file output operations (e.g., `3`).

##### fname_dwdFG

Filename for DWD first guess data used by ICON (e.g.,
`dwdFG_R13B05_DOM01.nc`).

##### fname_icondomain

Filename for ICON domain grid file (e.g., `europe011_DOM01.nc`).

##### fname_iconextpar

Filename for ICON external parameters including tiles (e.g.,
`external_parameter_icon_europe011_DOM01_tiles.nc`).

##### fname_iconghgforc

Filename for greenhouse gas forcing data (e.g.,
`bc_greenhouse_rcp45_1765-2500.nc`). Used for climate scenario
simulations.

#### [sim_config_clm]

eCLM land surface component configuration.

For eCLM namelist definitions (derived from CLM5.0 if not declared
otherwise), see
https://docs.cesm.ucar.edu/models/cesm2/settings/current/clm5_0_nml.html

##### geo_dir_clm

Directory path for eCLM static geographical input files (domain file,
surface data, topography, etc.). Default: `${geo_dir}/eclm/static`
(e.g., `./input_clm`).

##### clm_frc_dir

Directory path for eCLM atmospheric forcing data. Default:
`${frc_dir}/eclm/forcing/` (e.g., `./forcings`).

##### domainfile_clm

Domain file for eCLM grid definition. Specifies land/lake mask and
grid structure (e.g.,
`domain.lnd.ICON-11_ICON-11.230302_landlake_halo.nc`).

##### surffile_clm

Surface data file for eCLM containing vegetation, soil properties, and
land use (e.g.,
`surfdata_ICON-11_hist_16pfts_Irrig_CMIP6_simyr2000_c230302_gcvurb-pfsoil_halo.nc`).

##### fini_clm

Path to eCLM restart file for continuing simulations. Used when
`startdate` differs from `inidate`. Default: automatically determined
from previous simulation restart directory (e.g.,
`./input_clm/FSpinup_300x300_NRW.clm2.r.2222-01-01-00000.nc`).

##### clm_tsp

eCLM timestep in seconds.

Default: value of `cpltsp_atmsfc` from `master.conf` (e.g., `1800` for
30-minute timestep).

##### clmoutvar

Comma-separated list of eCLM output variables.

Sets `hist_fincl1` in eCLM's `lnd_in` namelist.

##### clmoutfrq

eCLM history output frequency in hours (negative values).

Sets `hist_nhtfrq` in eCLM's `lnd_in` namelist.

##### clmoutmfilt

Maximum number of time samples per eCLM history file.

Sets `hist_mfilt` in eCLM's `lnd_in` namelist.

#### [sim_config_parflow]

ParFlow subsurface component configuration.

##### pfl_ngx

Number of grid cells in x-direction for ParFlow domain (e.g., `444`).

##### pfl_ngy

Number of grid cells in y-direction for ParFlow domain (e.g., `432`).

##### pfl_mask

Filename for ParFlow solid file mask defining inactive cells (e.g.,
`PfbMask4SolidFile_eCLM.pfsol`).

##### pfloutmfilt

Output frequency multiplier for ParFlow files. Controls how often
output is written (e.g., `24` means every 24 timesteps).

##### pfltsfilerst

Timestep file index for ParFlow restart files. Typically set to
`$((pfloutmfilt - 1))` to align with output frequency.

#### [sim_config_oas]

OASIS coupler configuration for component coupling.

##### icon_ncg

Number of grid cells for ICON in OASIS coupler (e.g., `189976`). Must
match ICON grid definition.

##### clm_ngx

Number of grid cells in x-direction for eCLM in OASIS coupler (e.g.,
`189976`). For unstructured grids, represents total cell count.

##### clm_ngy

Number of grid cells in y-direction for eCLM in OASIS coupler. For
unstructured grids, set to `1`.

### Post-processing Configuration

#### [pos_config_*]

Configuration settings for post-processing stage. Currently empty in
the default configuration.

### Visualization Configuration

#### [vis_config_*]

Configuration settings for visualization stage. Currently empty in the
default configuration.
