# TSMP2 workflow-engine

## Introduction

TSMP2 workflow engine for running simulations. The following examples and descriptions are based on a coupled climate simulation case over the EUR-11 domain, but the underlying idea applies to all types of simulations, such as LES, NWP, real and idealised cases. The workflow is applicable for any model combination within the TSMP2 framework realm.

## Setup the workflow

Activate a compute project
```bash
# Replace PROJECTNAME with your compute project
jutil env activate -p PROJECTNAME

# Check if $BUDGET_ACCOUNTS was set.
echo $BUDGET_ACCOUNTS
```

In case you are not on a [JSC](https://www.fz-juelich.de/) machine, set the shell variables `PROJECT`, `SCRATCH` (existing pathnames) and `BUDGET_ACCOUNTS` manually.
Instead of setting `BUDGET_ACCOUNTS` you may also replace this variable in `ctl/control_tsmp2.sh`.

``` bash
cd $PROJECT/$USER
git clone https://github.com/HPSCTerrSys/TSMP2_workflow-engine
wfe_dir=$(realpath TSMP2_workflow-engine)
cd ${wfe_dir}
git submodule update --init
```

## Building the model

The TSMP2 ( https://github.com/HPSCTerrSys/TSMP2 ) should be either already compiled (see [ReadMe TSMP2](https://github.com/HPSCTerrSys/TSMP2/blob/master/README.md)) or compiled with the following steps.

```bash
cd ${wfe_dir}/src/TSMP2
./build_tsmp2.sh --icon --eclm --parflow
```

Adjust the components to your purpose.

## Run experiment

If you want to store your run directory files elsewhere than here, set a simulation ID (replace `MY-SIMULATION`) and make `${wfe_dir}/run` into a symlink pointing to your new directory.
``` bash
cd ${wfe_dir}
export sim_id=MY-SIMULATION
export scratch_dir=$SCRATCH/$USER/$sim_id
mkdir -p $scratch_dir/run
git rm run/.gitkeep
ln -snf $scratch_dir/run run
```

Adapt resources and time in the setup-script.
``` bash
cd ${wfe_dir}/ctl
vi control_tsmp2.sh
```

Start simulation
``` bash
./control_tsmp2.sh
```

## Contact
Stefan Poll <mailto:s.poll@fz-juelich.de>
