# INSTALLATION TEST

In order to check that the *probject* is successfully installed, please
run the following test:

    ~$ pushd bench
    ~$ make all ; popd

The expected output is:

    [log]  << z3_0(statemate)                          -- max: 997, opt: 764, gain: 23.37 %, time: 5.88s
    [log]  << z3_0_cuts(statemate)                     -- max: 997, opt: 764, gain: 23.37 %, time: 5.95s
    [log]  << optimathsat_0(statemate)                 -- max: 997, opt: 997, gain: 0.00 %, time: 120.91s
    [log]  << optimathsat_0_cuts(statemate)            -- max: 997, opt: 764, gain: 23.37 %, time: 19.28s
    [log]  << optimathsat_1_sn(statemate)              -- max: 997, opt: 764, gain: 23.37 %, time: 19.06s
    [log]  << optimathsat_1_cuts_sn(statemate)         -- max: 997, opt: 764, gain: 23.37 %, time: 39.50s
    [log]  << optimathsat_2(statemate)                 -- max: 997, opt: 997, gain: 0.00 %, time: 120.62s
    [log]  << optimathsat_2_cuts(statemate)            -- max: 997, opt: 997, gain: 0.00 %, time: 121.10s
    [log]  << optimathsat_2_dl_1(statemate)            -- max: 997, opt: 764, gain: 23.37 %, time: 35.94s
    [log]  << optimathsat_2_cuts_dl_1(statemate)       -- max: 997, opt: 764, gain: 23.37 %, time: 42.39s

In case of **errors**, please enable the *verbose* mode

    ~$ pushd bench
    ~$ export DEBUG=1
    ~$ make all ; popd

Get in touch with the project maintainer in case of unsolvable errors.


### HANDLERS TESTING

The following instructions allow for testing *benchmark handlers* only,
rather than the whole experimental environment. Type:

    ~$ source ../../wcet_omt/bin/wcet_lib/wcet_handlers.sh
    ~$ test_handlers

The expected output is:

    [log]  << z3_0(statemate)                          -- max: 997, opt: 764, gain: 23.37 %, time: 5.86s
    [log]  << z3_0_cuts(statemate)                     -- max: 997, opt: 764, gain: 23.37 %, time: 5.95s
    [log]  << optimathsat_0(statemate)                 -- max: 997, opt: 997, gain: 0.00 %, time: 60.53s
    [log]  << optimathsat_0_cuts(statemate)            -- max: 997, opt: 764, gain: 23.37 %, time: 18.58s
    [log]  << optimathsat_1_sn(statemate)              -- max: 997, opt: 764, gain: 23.37 %, time: 18.30s
    [log]  << optimathsat_1_cuts_sn(statemate)         -- max: 997, opt: 764, gain: 23.37 %, time: 38.71s
    [log]  << optimathsat_2(statemate)                 -- max: 997, opt: 997, gain: 0.00 %, time: 60.46s
    [log]  << optimathsat_2_cuts(statemate)            -- max: 997, opt: 997, gain: 0.00 %, time: 60.30s
    [log]  << optimathsat_2_dl_1(statemate)            -- max: 997, opt: 764, gain: 23.37 %, time: 34.62s
    [log]  << optimathsat_2_cuts_dl_1(statemate)       -- max: 997, opt: 764, gain: 23.37 %, time: 42.07s

