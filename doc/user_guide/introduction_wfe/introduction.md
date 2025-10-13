# Workflow engine overview

## Overview of TSMP2-WFE
We are utilizing a WorkFlow Engine (WFE) for our simulations, designed to streamline and manage the complex processes involved in running and analyzing them. Its primary purpose is to automate and oversee the various steps required to execute a simulation, including data preparation, model configuration, simulation execution, and result processing.

A key objective of the WFE is to enhance reproducibility, which it achieves more easily through the use of version control with git.

The TSMP2 workflow engine also allows for flexible model component combinations. You can specify the model combination by providing the MODEL_ID, similar to the TSMP2 building system. The WFE itself is lightweight, functioning as a framework, while individual experiments are configured using git submodules to manage components such as namelists, static fields, and other necessary elements.


## Structure of TSMP2-WFE

The directory structure of the WFE is the following:
```
TSMP2_wfe/
|    
|---- ctl                             -> for managing the simulation
|    |---- {pre,sim,pos,vis}_ctl      -> for controlling the steps
|    |---- logs                       -> for job log during the run
|---- src                             -> for source code (TSMP2, pre/post-processing tools , ...)
|---- nml                             -> for component namelists
|---- run                             -> for number crunching
|---- dta                             -> for data
```

Two configure files to manage configuration / setup 
```
ctl/
|---- master.conf  -> general settings
|---- expid.conf    -> model specifications
```

Information: Inside `expid.conf`, variables set in the `master.conf`
can be used (e.g. `MODEL_ID` set in `master.conf` could be used in
`expid.conf` as `$MODEL_ID`).

## Developer information

Forks (i.e. SimExps) of the Workflow Engine should only change
- `ctl/master.conf`
- `ctl/expid.conf`
- `.gitmodules`.

All other changes should be applied to the main repository through
Pull Requests (PRs) under
<https://github.com/HPSCTerrSys/TSMP2_workflow-engine/pulls>.
