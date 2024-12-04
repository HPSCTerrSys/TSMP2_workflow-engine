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

In case you are not on a [JSC](https://www.fz-juelich.de/) machine, set the shell variables `BUDGET_ACCOUNT`, `PROJECT` and `SCRATCH` manually.
Instead of setting `BUDGET_ACCOUNT` you may also replace this variable in `ctl/control_tsmp2.sh`

``` bash
cd $PROJECT/$USER
git clone https://github.com/HPSCTerrSys/TSMP2_workflow-engine
wfe_dir=$(realpath tsmp2_workflow-engine)
git submodule init
git submodule update
```

## Building the model

The TSMP2 ( https://github.com/HPSCTerrSys/TSMP2 ) should be either already compiled (see [ReadMe TSMP2](https://github.com/HPSCTerrSys/TSMP2/blob/master/README.md)) or compiled with the following steps.

```bash
cd ${wfe_dir}/src/TSMP2
./build_tsmp2.sh --icon --eclm --parflow
```

Adjust the components to your purpose.

## Run experiment

Create run-directory on SCRATCH
``` bash
export scratch_dir=$SCRATCH/$USER/$sim_id
mkdir -pv $scratch_dir/run
```

Adapt resources and time in the setup-script.
``` bash
cd ctl
vi control_tsmp2.sh
```

Start simulation
``` bash
sh control_tsmp2.sh
```

## Contact
Stefan Poll <mailto:s.poll@fz-juelich.de>
