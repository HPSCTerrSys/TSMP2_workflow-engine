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
	
