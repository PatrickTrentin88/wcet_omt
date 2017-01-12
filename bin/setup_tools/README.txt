                    ### DISCLAIMER ###

The scripts have been tested on linux-x86_64 only.
Please report any issue you may find on this or any other platform.


                    ### INSTRUCTIONS ###

After the successful installation of all tools, environment
variables should be updated using `wcet_omt/bin/setup_env.sh`.
This script checks that the project is properly installed and,
if so, it stores environment in `wcet_omt/.wcet_omt.bashrc`.


1) pagai (http://pagai.forge.imag.fr/)

    ~$ ./get_pagai.sh DIR

where DIR must be either the current directory (wcet_omt/tools)
or any other directory in the file system where you desire to
have pagai downloaded and patched. In the latter case,
a symlink will be created in the current directory.

It is possible to set DIR to be the super-directory
of an existing pagai installation. However, please note
that the installation script will attempt changing
commit version and patching the source code.

After applying the patch, the installation of pagai
should be done manually, referring to the installation
scripts and instructions shipped with pagai.


2) OptiMathSAT (http://optimathsat.disi.unitn.it/)

    ~$ ./get_optimathsat.sh DIR

where DIR must be either the current directory (wcet_omt/tools)
or any other directory in the file system where you desire to
have OptiMathSAT downloaded and installed. In the latter case,
a symlink will be created in the current directory.

Please note that the version of OptiMathSAT must be 1.4.2 or 
newer in order to take advantage of dynamic learning of theory 
lemmas based on Difference Logic conflicts.


3) z3 (https://github.com/Z3Prover/z3)

    ~$ ./get_z3.sh DIR

where DIR must be either the current directory (wcet_omt/tools)
or any other directory in the file system where you desire to
have z3 downloaded and installed. In the latter case,
a symlink will be created in the current directory.

It is possible to set DIR to be the super-directory
of an existing z3 installation. However, please note
that the installation script will attempt changing
checking out the master branch and dischard any uncommitted
change to the code.
