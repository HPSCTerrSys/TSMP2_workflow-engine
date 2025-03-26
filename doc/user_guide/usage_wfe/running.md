# Run experiment

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
