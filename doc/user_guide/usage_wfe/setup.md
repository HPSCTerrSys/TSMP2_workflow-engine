# Setup TSMP2 WFE


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
