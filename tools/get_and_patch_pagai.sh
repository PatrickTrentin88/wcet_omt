#!/bin/bash

###
### 1. usage
###

( [ -z "${1}" ] || [ ! -d "${1}" ] ) && echo "usage: get_and_patch_pagai.sh INSTALL_DIR" 1>&2 && exit 1

###
### 2. resource location
###

DIR_INSTALLATION="${1%/}"
DIR_DEPENDENCIES="$(dirname "$(readlink -f "$0")")"
PAGAI_PATCH="${DIR_DEPENDENCIES}/patches/pagai.diff"
PAGAI_COMMIT="16eed0f528a19d54adc538ee5664755a199b5ae0"

function pushd () { command pushd "${@}" >/dev/null; }
function popd  () { command popd >/dev/null; }

###
### 3. get pagai
###

pushd "${DIR_INSTALLATION}"

[ ! -d "pagai" ] && [ ! -h "pagai" ] && git clone http://forge.imag.fr/anonscm/git/pagai/pagai.git &>/dev/null
[ ! -d "pagai" ] && [ ! -h "pagai" ] && echo "error: unable to fetch pagai" 1>&2 && exit 1

popd

###
### 4. apply patch
###

pushd "${DIR_INSTALLATION}/pagai"

git checkout "${PAGAI_COMMIT}" &>/dev/null || { echo "error: unable to checkout commit ${PAGAI_COMMIT}" 1>&2 ; exit 1; };
git reset --hard &>/dev/null               || { echo "error: unable to reset pagai source code" 1>&2         ; exit 1; };
git apply "${PAGAI_PATCH}" &>/dev/null     || { echo "error: unable to apply patch to pagai" 1>&2            ; exit 1; };

popd

###
### 5. create symlink if needed
###

DIR_PAGAI="${DIR_DEPENDENCIES}/pagai"
if [ ! -d "${DIR_PAGAI}" ] && [ ! -h "${DIR_PAGAI}" ]; then
	ln -s "${DIR_INSTALLATION}/pagai" "${DIR_PAGAI}" &>/dev/null || { echo "error: unable to create symlink to pagai" 1>&2 ; exit 1; };
fi

###
### 6. defer pagai installation to the user
###

echo -e "Success: pagai patched.\nPlease follow pagai's installation instructions in <${DIR_INSTALLATION}/pagai>."

###
###
###

exit 0
