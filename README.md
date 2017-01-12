# REQUIREMENTS

This project has been tested on *linux-gnu* only. In case you need support for another OS, contact
the project maintainer <https://github.com/PatrickTrentin88/wcet_omt/>.


# INSTALLATION

The project comes with an installation script* which **attempts** to download and configure the 
required dependencies. In case of **failure**, please refer to `wcet_omt/setup_tools/REAME.txt` 
for **manual installation**.

Type

    ~$ make -f Makefile.master install

in the root directory and *follow the instructions*.


# USAGE

To run a simple experiment, type

    ~$ pushd bench/test
    ~$ make optimathsat_0 optimathsat_2_dl_1
    ~$ popd

Here, `optimathsat_0` and `optimathsat_2_dl_1` are compilation **targets**, scroll this
file to get for more information.

This will result in the following *folder structure* being created:
    
    wcet_omt
    |--stats
       |--test
          |--optimathsat_0
          |  |-- optimathsat_0.log        # summary of relevant benchmark information
          |  |-- benchmark_1.log
          |  |-- ...
          |  |-- benchmark_i.log          # the omt solver's output for i-th benchmark
          |  |-- ...
          |  |-- benchmark_N.log
          |
          |-- optimathsat_2_dl_1
             |-- optimathsat_2_dl_1.log   # summary of relevant benchmark information
             |-- benchmark_1.log
             |-- ...
             |-- benchmark_i.log          # the omt solver's output for i-th benchmark
             |-- ...
             |-- benchmark_N.log

To modify the experimental conditions (*e.g. change TIMEOUT*), you should edit
the `Makefile` within the target benchmark directory. Please avoid modifying
`Makefile.master`.


### TARGETS

Benchmark targets are defined in `Makefile.master`, and correspond to the list of **HANDLER_UIDS**
mentioned by

    ~$ ./bin/run_experiment.sh -h
    ...
    HANDLER UIDS
        z3_0                    -- z3          + default encoding
        z3_0_cuts               -- z3          + default encoding + cuts
        optimathsat_0           -- optimathsat + default encoding
        optimathsat_0_cuts      -- optimathsat + default encoding + cuts
        optimathsat_1_sn        -- optimathsat + assert-soft enc. +      + sorting networks
        optimathsat_1_cuts_sn   -- optimathsat + assert-soft enc. + cuts + sorting networks
        optimathsat_2           -- optimathsat + diff. logic enc.
        optimathsat_2_cuts      -- optimathsat + diff. logic enc. + cuts
        optimathsat_2_dl_1      -- optimathsat + diff. logic enc. +      + dlSolver + short tlemmas
        optimathsat_2_cuts_dl_1 -- optimathsat + diff. logic enc. + cuts + dlSolver + short tlemmas
        optimathsat_2_dl_2      -- optimathsat + diff. logic enc. +      + dlSolver + long  tlemmas
        optimathsat_2_cuts_dl_2 -- optimathsat + diff. logic enc. + cuts + dlSolver + long  tlemmas
        optimathsat_2_dl_3      -- optimathsat + diff. logic enc. +      + dlSolver + both  tlemmas
        optimathsat_2_cuts_dl_3 -- optimathsat + diff. logic enc. + cuts + dlSolver + both  tlemmas
    ...

Each **HANDLER_UID** corresponds to a specific combination of *SMT2 encoding*, *OMT solver*
and *solver parameters* wrapped into a *function* that acts as a *benchmark handler*. These
*handlers* are defined within `wcet_omt/bin/wcet_lib/wcet_handlers.sh`.


### DEBUG

The scripts are designed to print any **error** that might be encountered. However, to keep the 
output nice and clean, relevant debugging information is hidden by default. To enable it, type:

     ~$ pushd bench/test
     ~$ export -f DEBUG=1
     ~$ make all
     ~$ popd

