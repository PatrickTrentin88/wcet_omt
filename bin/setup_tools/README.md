## DISCLAIMER

The scripts have been tested on linux-x86_64 only, and are expected
to work only on a gnu-linux distro.
Please report any issue you may find on this or any other platform.


## INSTRUCTIONS

The project can be easily installed with the following command

	~$ ./setup_env.sh -f -c -w

This installs the required resources (pagai, z3 and optimathsat)
within the path `wcet_omt/tools` and store the newly installed
environment in the `wcet_omt/.wcet_omt.bashrc` config file.

Some of the resources may require being compiled. The following
is a non-exhaustive list of required packages for building
the source code:

- make
- g++
- libgmp3-dev

Each tool can be separately installed in case of difficulties.
However, it is reccomended to always use `setup_env.sh` as
it is the only script responsible for updating the .bashrc 
file.

#### PAGAI
> (http://pagai.forge.imag.fr/)

To install only pagai, type

    ~$ ./setup_pagai.sh -f -c -w

Please note that this project requires a patched version of
`pagai`, and therefore existing installations of this tool
on your system might be incompatible with this project.

In case the script fails at automatically installing 
pagai, please consult the log located in
`wcet_omt/tools/pagai_setup.log` and refer to the
installation instructions of pagai's source code
to solve any possible issue.

#### Z3
> (https://github.com/Z3Prover/z3)

To install only z3, type

    ~$ ./setup_z3.sh -f -c -w

In case the script fails at automatically building z3,
please consult the log located in `wcet_omt/tools/z3_setup.log`
and refer to the installation instructions of z3's source code
to solve any possible issue.

#### OptiMathSAT
> (http://optimathsat.disi.unitn.it/)

To install only OptiMathSAT, type

    ~$ ./setup_optimathsat.sh -f -c -w

Please note that the version of OptiMathSAT must be 1.4.2 or 
newer in order to take advantage of dynamic learning of theory 
lemmas based on Difference Logic conflicts.
