# 0. Preamble

The TSMP2 workflow engine (WFE) is designed to support a wide range of simulation applications. To facilitate immediate usability, it is distributed with a default test case that enables users to operate the WFE without requiring additional configuration or data. A specific configration is called simulation experiment. Please go to Setup, Build and Run for much more information.

# 1. TSMP pan-european domain

## 1.1 Description of the model experiment

The numerical experiment covers a pan-European area, according to the EUR-12 CORDEX domain. [EURO-CORDEX](https://euro-cordex.net) is the European branch of the international CORDEX initiative, which is a program sponsored by the World Climate Research Program (WCRP) to organize an internationally coordinated framework to produce improved regional climate change projections for all land regions worldwide. The respective horizontal grid has a horizontal grid size of 0.11°(∼12 km).

The experiment is carried out on 01 July 2017 using the fully coupled (ICON-eCLM-ParFlow) configuration of TSMP2.

ICON is forced within ERA-5 [Hersbach et al.(2020)](https://doi.org/10.1002/qj.3803), the reanalysis of the European Centre for Medium-Range Weather Forecasts (ECMWF) in a hourly interval. The land surface composition for eCLM over the European CORDEX domain is based on the globecover data set [(Arino et al., 2012)](https://doi.pangaea.de/10.1594/PANGAEA.787668?utm_source=chatgpt.com), and the land use is transferred to plant functional types (PFT). The atmospheric component uses a constant lateral spatial resolution of about 12 km and a variable vertical discretization into 60 levels, gradually coarsening from the bottom (20 m) to the top (22000 m). ParFlow is set up with 30 vertical layers, resulting in a total depth of 60 m with increasing thickness toward the bottom. The thickness of the upper 20 layers is identical to the layers in eCLM, reaching a depth of 8.5 m. The time step for ParFlow and eCLM is hourly, while ICON runs with a 100-second time step. Coupling between the component models is applied at an 15 minutes frequency from ICON.

In this section, we want to perform a 24-hour simulation using the fully coupled TSMP2 including ICON-eCLM-ParFlow coupled with the OASIS3-MCT coupler over the EURO-CORDEX domain with about 0.11° grid spacing. ICON is doing its calculations - as the name already suggests - on an icosahedral grid structure, whereas eCLM and ParFlow use a curvilinear grid. The TSMP2 system allows, similar to TSMP1, different grids between the components and uses resampling weights for the exchange of information between the components.

## 1.2 TSMP Experiment setup

First, open a terminal and let's prepare the environment for TSMP2 runs:

```bash
# Replace PROJECTNAME with your compute project
jutil env activate -p PROJECTNAME

# Check if $BUDGET_ACCOUNTS was set.
echo $BUDGET_ACCOUNTS
```

# 2. Download the experiment setup

Get the real test case files by running

```bash
cd $TRAINHOME
git clone https://github.com/HPSCTerrSys/TSMP2_workflow-engine.git simexp_real_CORDEX-EUR-12-iic_icon-eclm-parflow
export TSMP2_WFE=$(realpath simexp_real_CORDEX-EUR-12-iic_icon-eclm-parflow)
```

Next, download the namelists and static fields:

```bash
cd $TSMP2_WFE
git submodule init
git submodule update --init
```

Download the initial and forcing data for the simulation date:
> :notepad_spiral: **NOTE**: This takes about 5minutes.
```bash
cd $TSMP2_WFE/dta
wget -x -l 8 -nH --cut-dirs=4 -e robots=off --recursive --no-parent --reject="index.html*" https://datapub.fz-juelich.de/slts/tsmp_testcases/data/tsmp2_eur12-iic_wfe_iniforc/
```

## 2.1 Check the configuration files

Have a look at the configuration files by running:

```bash
cd $TSMP2_WFE/ctl
vim master.conf
vim expid.conf
```

> :notepad_spiral: **NOTE**: Which model-combination is set?

## 2.2. Check TSMP2 binaries

In case that you have prebuilt TSMP2 model binaries, we are going to set the path to the shared `TSMP2` folder:

```bash
export TSMP2_DIR=/PATH/TO/TSMP2
```

Otherwise, you need to build the TSMP2 model binaries by doing

```bash
cd ${wfe_dir}/src/TSMP2
./build_tsmp2.sh icon eclm parflow
```

# 3. Running the simulation

First, we are going to set the path to the shared `TSMP2` folder that contains the prebuilt binaries:

```bash
export TSMP2_DIR=/PATH/TO/TSMP2
```

Then initiate the experiment by running:

```bash
cd $TSMP2_WFE/ctl
sh control_tsmp2.sh
```

Check the status of your runs:

```bash
sacct
```

You can check the `$rundir` folder, in case the simulation is started:

```bash
ls -lrth $TSMP2_WFE/run/sim_iconeclmparflow_20170701
```

You can also continuously monitor the progress of the simulation by printing the log file:

```bash
# Check job status and job ID
sacct

# Replace <Job ID> with the one associated to your model run
less +F $TSMP2_WFE/ctl/logs/*_<Job ID>.out
```

> :point_up_tone1: **TIP**: The `less` command above prints contents in real time. To exit, hit `CTRL+C` and then `q`.

> :notepad_spiral: **NOTE**: the model log of ICON is written into `*.err`, while the model output of ParFlow and eCLM is written into `*.out`

The end of the simulation will be marked by the printing of timing outputs from each component model. The simulation will take about 25 minutes to finish.

When the simulation is finished, the logs, model output, model namelist, model binaries can be found in the simulation results (`simres`) directory:
```bash
cd $TSMP2_WFE/dta/simres/iconeclmparflow_20170701
ls -l *
```
