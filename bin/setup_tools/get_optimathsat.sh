#!/bin/bash

###
###
###

BASE_URL="http://optimathsat.disi.unitn.it/releases"
version="1.4.2"	# NOTE: not yet publicly available [Mac binary is unavailable, and the packages may be updated without warning with critical updates]
platform=""
arch=""
extension=""

###
### 1. usage
###

( [ -z "${1}" ] || [ ! -d "${1}" ] ) && echo "usage: get_optimathsat.sh INSTALL_DIR" && exit 1

###
### 2. resource location
###

DIR_INSTALLATION="${1%/}"
DIR_TOOLS="$(realpath "$( dirname "$( readlink -f "$0" )" )"/../../tools)"

function pushd () { command pushd "${@}" >/dev/null; }
function popd  () { command popd >/dev/null; }

###
### 3. get system info and build resource url
###

    # TODO: code tested only on linux :(

# get platform
case ${OSTYPE} in
    linux*)  platform="linux";  extension="tar.gz" ;;
    darwin*) platform="macos";  extension="tar.gz" ;;
    msys*)   platform="windows" extension="zip"    ;;
esac
[ -z "${platform}" ] && echo "error: unknown OS <${OSTYPE}>" 1>&2 && exit 1

# get arch
[ "${platform}" == "linux" ] && arch=$(uname -m)
[ "${platform}" == "macos" ] && arch=$(uname -m)
[ "${arch}" == "x86_64" ] && arch="64-bit" || arch="32-bit"
if [ "${platform}" == "windows" ]; then
    echo -n "Download 64 bit? [Y/n] "; read -s -r ret; echo ""
    case ${ret} in
        [yY][eE][sS]|[yY])
            arch="64-bit-mingw"
            ;;
        *)
            arch="32-bit-mingw"
            ;;
    esac
fi

echo -e -n "Selected OptiMathSAT\n\
version   : ${version}\n\
platform  : ${platform}\n\
arch      : ${arch}\n\
\n\
Continue? [Y/n] "
read -s -r ret; echo ""
case ${ret} in
    [yY][eE][sS]|[yY])
        # TODO: prompt version/platform/arch to the user
        ;;
    *)
        echo "Please, manually download the selected resource." 1>&2 ; exit 1;
        ;;
esac

BASENAME_OPTIMATHSAT="optimathsat-${version}-${platform}-${arch}"
PACKAGE_OPTIMATHSAT="${BASENAME_OPTIMATHSAT}.${extension}"
URL_OPTIMATHSAT="${BASE_URL}/optimathsat-${version}/${PACKAGE_OPTIMATHSAT}"

###
### 4. download and unpack
###

pushd "${DIR_INSTALLATION}"

if [ ! -d "${BASENAME_OPTIMATHSAT}" ]; then
    [ ! -f "${PACKAGE_OPTIMATHSAT}" ] && wget ${URL_OPTIMATHSAT} &>/dev/null
    [ ! -f "${PACKAGE_OPTIMATHSAT}" ] && echo "error: unable to fetch optimathsat" 1>&2 && exit 1

    [[ "${extension}" =~ zip$ ]]    && unzip "${PACKAGE_OPTIMATHSAT}"
    [[ "${extension}" =~ tar.gz$ ]] && tar -xf "${PACKAGE_OPTIMATHSAT}"

    [ -f "${PACKAGE_OPTIMATHSAT}" ] && rm "${PACKAGE_OPTIMATHSAT}" 2>/dev/null

    [ ! -d "${BASENAME_OPTIMATHSAT}" ] && echo "error: unable to uncompress optimathsat" 1>&2 && exit 1
fi

popd

###
### 5. create symlink if needed
###

DIR_OPTIMATHSAT="${DIR_TOOLS}/${BASENAME_OPTIMATHSAT}"
if [ ! -d "${DIR_OPTIMATHSAT}" ] && [ ! -h "${DIR_OPTIMATHSAT}" ]; then
    ln -s "${DIR_INSTALLATION}/${BASENAME_OPTIMATHSAT}" "${DIR_OPTIMATHSAT}" &>/dev/null || { echo "error: unable to create symlink to optimathsat" 1>&2; exit 1; };
fi

###
### 6. done
###

echo -e "Success: optimathsat downloaded."

###
###
###

exit 0
