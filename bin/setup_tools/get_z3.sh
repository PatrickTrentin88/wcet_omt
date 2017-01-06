#!/bin/bash

###
### 1. usage
###

( [ -z "${1}" ] || [ ! -d "${1}" ] ) && echo "usage: get_z3.sh INSTALL_DIR" 1>&2 && exit 1

###
### 2. resource location
###

DIR_INSTALLATION="${1%/}"
DIR_TOOLS="$(realpath "$( dirname "$( readlink -f "$0" )" )"/../../tools)"

function pushd () { command pushd "${@}" >/dev/null; }
function popd  () { command popd >/dev/null; }

###
### 3. get z3
###

pushd "${DIR_INSTALLATION}"

[ ! -d "z3" ] && [ ! -h "z3" ] && git clone https://github.com/Z3Prover/z3.git &>/dev/null
[ ! -d "z3" ] && [ ! -h "z3" ] && echo "error: unable to fetch z3" 1>&2 && exit 1

pushd "z3"

has_executable=$(find . -name "z3" -type f -executable)

if [ -z "${has_executable}" ]; then
    echo -e -n "Ready for building z3\n\nContinue? [Y/n] "
    read -s -r ret; echo ""
    case ${ret} in
        [yY][eE][sS]|[yY])
            git checkout master &>/dev/null || { echo "error: unable to checkout master branch" 1>&2 ; exit 1; };
            git reset --hard &>/dev/null    || { echo "error: unable to reset z3 source code" 1>&2   ; exit 1; };

            ./configure
            pushd "build"
            make all
            popd

            ;;
        *)
            ;;
    esac
fi

popd
popd

###
### 4. create symlink if needed
###

DIR_Z3="${DIR_TOOLS}/z3"
if [ ! -d "${DIR_Z3}" ] && [ ! -h "${DIR_Z3}" ]; then
    ln -s "${DIR_INSTALLATION}/z3" "${DIR_Z3}" &>/dev/null || { echo "error: unable to create symlink to z3" 1>&2 ; exit 1; };
fi

###
### 6. done
###

echo -e "Success: z3 downloaded."

###
###
###

exit 0
