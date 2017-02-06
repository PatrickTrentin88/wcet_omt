## DESCRIPTION

This project aims to reproduce the results obtained in the paper

    [HAL-14]
    How to Compute Worst-Case Execution Time by Optimization Modulo Theory and a Clever Encoding of Program Semantics
    Julien Henry (VERIMAG - IMAG), Mihail Asavoae (VERIMAG - IMAG), David Monniaux (VERIMAG - IMAG), Claire Maïza (VERIMAG - IMAG)
    HAL-00998138 https://hal.archives-ouvertes.fr/hal-00998138

We expand over [HAL-14] in the following way:

    - new and improved build-chain
    - updated original source code to be compatible with newer versions of z3's API library
    - updated smt2 formula encoding to use Optimization Modulo Theory language extensions
    - added two additional formula encodings
    - benchmarking functionality

The original work of [HAL-14] is made available within Pagai's sources.


## LIMITATIONS

There are a number of inherent limitations in this work, some of which derive from
using an outdated version of clang/llvm and from Pagai's implementation.


## REQUIREMENTS

This project has been tested on *linux-gnu* only. In case support for another OS is needed, contact
the project maintainer <https://github.com/PatrickTrentin88/wcet_omt/>.


## INSTALLATION

The project comes with an *installation script* which **attempts** to download and configure the 
required dependencies. In case of **failure**, please refer to `wcet_omt/setup_tools/REAME.md` 
for **manual installation**.

Type

    ~$ make -f Makefile.master install

in the root directory and *follow the instructions*.

Please note that the following packages and tools, or their equivalent for your own distribution,
should be installed on your system in order to successfully install the required resources:

- coreutils         # (timeout, realpath)
- make
- g++
- curl
- cmake
- flex
- bison
- libgmp3-dev
- libmpfr-dev
- libboost-all-dev
- libncurses5-dev

## TESTING INSTALLATION

Follow the instructions found in `wcet_omt/test/README.md`.

## USAGE

To run a simple experiment, type

    ~$ pushd test/bench
    ~$ make optimathsat_0 optimathsat_2_dl_1
    ~$ popd

Here, `optimathsat_0` and `optimathsat_2_dl_1` are compilation **targets**, scroll this
file to get for more information.

As the experiment runs, the following *folder structure* is added to the file-system:
    
    wcet_omt
    |-- test
        |-- stats
            |-- bench
                |-- optimathsat_0
                |   |-- optimathsat_0.txt        # summary of relevant benchmark information
                |   |-- benchmark_1.log
                |   |-- ...
                |   |-- benchmark_i.log          # the omt solver's output for i-th benchmark
                |   |-- ...
                |   |-- benchmark_N.log
                |
                |-- optimathsat_2_dl_1
                    |-- optimathsat_2_dl_1.txt   # summary of relevant benchmark information
                    |-- benchmark_1.log
                    |-- ...
                    |-- benchmark_i.log          # the omt solver's output for i-th benchmark
                    |-- ...
                    |-- benchmark_N.log

To modify the experimental conditions (*e.g. change TIMEOUT*), the `Makefile` within the target 
benchmark directory should be *edited*. Please avoid any change to `Makefile.master`.


#### TARGETS

Benchmark targets are defined in `Makefile.master`, and correspond to the list of **HANDLER_UIDS**
mentioned by

    ~$ ./bin/run_experiment.sh -h
    ...
    HANDLER UIDS
        z3_0                    -- z3          + default encoding
        z3_0_cuts               -- z3          + default encoding + cuts
        smtopt_0                -- smtopt      + default encoding
        smtopt_0_cuts           -- smtopt      + default encoding + cuts
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


#### DEBUG

The scripts are designed to print any **error** that might be encountered. However, to keep the 
output nice and clean, relevant debugging information is hidden by default. To enable it, type:

     ~$ pushd bench/test
     ~$ export WCET_DEBUG=1
     ~$ make all
     ~$ popd

#### LOOP UNROLLING

Loops are not supported and need to be unrolled. By default, loops in the bytecode are not 
optimized out. To enable this feature, type:

     ~$ pushd bench/test
     ~$ export WCET_UNROLL=1
     ~$ make all
     ~$ popd

Loop unrolling might fail, please refer to the loop unrolling log file for more information.
