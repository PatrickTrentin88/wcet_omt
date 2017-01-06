#!/bin/bash

###
### script configuration
###

EXIT_ON_ERROR=$((0))
VERBOSE=$((1))

[ -n "${1}" ] && EXIT_ON_ERROR=$(( ${1} ))
[ -n "${2}" ] && VERBOSE=$(( ${2} ))

###
### globals
###

DIR_BASE="$( realpath "$( dirname "$( readlink -f "$0" )" )"/.. )"
DIR_TOOLS="${DIR_BASE}/tools"
DIR_SETUP_TOOLS="${DIR_BASE}/bin/setup_tools"
BASHRC="${DIR_BASE}/.wcet_omt.bashrc"

NUM_ERRORS=$((0))

(( 0 != VERBOSE )) && echo -e "Environment setup ...\n"



###
### 1. locate pagai
###

DIR_PAGAI="${DIR_TOOLS}/pagai"
if [ ! -d "${DIR_PAGAI}" ]; then
    echo -e -n "error: pagai dir not found in <${DIR_TOOLS}>\nDo you want to download it now? [Y/n] "
    read -s -r ret; echo ""
    case ${ret} in
        [yY][eE][sS]|[yY])
            "${DIR_SETUP_TOOLS}/get_and_patch_pagai.sh" "${DIR_TOOLS}" || NUM_ERRORS=$((NUM_ERRORS + 1))
            ;;
        *)
            NUM_ERRORS=$((NUM_ERRORS + 1))
            ;;
    esac
fi

BIN_PAGAI=$(find -L "${DIR_PAGAI}" -name pagai -executable -type f 2>/dev/null)
[ -z "${BIN_PAGAI}" ] && echo -e "error: unable to locate pagai binary in <${DIR_PAGAI}>,\n\tplease run pagai's auto-installation script" 1>&2 \
                      && NUM_ERRORS=$((NUM_ERRORS + 1))

(( 0 != EXIT_ON_ERROR )) && (( 0 != NUM_ERRORS )) && exit 1



###
### 2. set pagai resources
###

DIR_LLVM="${DIR_PAGAI}/external/llvm/bin"
DIR_PAGAI_Z3_LIB="${DIR_PAGAI}/external/z3/lib"
BIN_PAGAI_Z3="${DIR_PAGAI}/external/z3/bin/z3"

[ ! -d "${DIR_LLVM}" ] && echo -e "error: unable to locate pagai's llvm resource dir <${DIR_LLVM}>" 1>&2 \
                       && NUM_ERRORS=$((NUM_ERRORS + 1))
[ ! -d "${DIR_PAGAI_Z3_LIB}" ] && echo -e "error: unable to locate pagai's z3 lib dir <${DIR_PAGAI_Z3_LIB}>" 1>&2 \
                       && NUM_ERRORS=$((NUM_ERRORS + 1))
[ ! -x "${BIN_PAGAI_Z3}" ] && echo -e "error: unable to locate or execute pagai's z3 binary <${BIN_PAGAI_Z3}>" 1>&2 \
                       && NUM_ERRORS=$((NUM_ERRORS + 1))

(( 0 != EXIT_ON_ERROR )) && (( 0 != NUM_ERRORS )) && exit 1



###
### 3. locate z3
###

DIR_Z3="${DIR_TOOLS}/z3"
if [ ! -d "${DIR_Z3}" ]; then
    echo -e -n "error: z3 dir not found in <${DIR_TOOLS}>\nDo you want to download it now? [Y/n] "
    read -s -r ret; echo ""
    case ${ret} in
        [yY][eE][sS]|[yY])
            "${DIR_SETUP_TOOLS}/get_z3.sh" "${DIR_TOOLS}"              || NUM_ERRORS=$((NUM_ERRORS + 1))
            ;;
        *)
            NUM_ERRORS=$((NUM_ERRORS + 1))
            ;;
    esac
fi

BIN_Z3=$(find -L "${DIR_Z3}" -name z3 -executable -type f 2>/dev/null)
[ -z "${BIN_Z3}" ] && echo -e "error: unable to locate z3 binary in <${DIR_Z3}>" 1>&2 \
                   && NUM_ERRORS=$((NUM_ERRORS + 1))

(( 0 != EXIT_ON_ERROR )) && (( 0 != NUM_ERRORS )) && exit 1



###
### 4. locate optimathsat
###

DIR_OPTIMATHSAT=$(find -L "${DIR_TOOLS}" -name "optimathsat-*" -executable -type d 2>/dev/null)
if [ -z "${DIR_OPTIMATHSAT}" ]; then
    echo -e -n "error: optimathsat dir not found in <${DIR_TOOLS}>\nDo you want to download it now? [Y/n] "
    read -s -r ret; echo ""
    case ${ret} in
        [yY][eE][sS]|[yY])
            "${DIR_SETUP_TOOLS}/get_optimathsat.sh" "${DIR_TOOLS}"     || NUM_ERRORS=$((NUM_ERRORS + 1))
            ;;
        *)
            NUM_ERRORS=$((NUM_ERRORS + 1))
            ;;
    esac
fi

[[ ${OSTYPE} =~ msys* ]] && optimathsat="optimathsat.exe" || optimathsat="optimathsat"
BIN_OPTIMATHSAT=$(find -L "${DIR_TOOLS}" -name "${optimathsat}" -executable -type f 2>/dev/null)
[ -z "${BIN_OPTIMATHSAT}" ] && echo -e "error: unable to locate ${optimathsat} binary in <${DIR_TOOLS}>" 1>&2 \
                            && NUM_ERRORS=$((NUM_ERRORS + 1))

(( 0 != EXIT_ON_ERROR )) && (( 0 != NUM_ERRORS )) && exit 1



###
### 5. dump environment into ${BASHRC}
###

(
    echo -e -n "#!/bin/bash\n"
    echo -e '                                                           # ignore shellcheck: no expansion intended
pathappend() {
  for ARG in "$@"
  do
    if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
        PATH="${PATH:+"$PATH:"}$ARG"
    fi
  done
  # credits: Guillaume Perrault-Archambault@superuser.com
}

pathprepend() {
  for ((i=$#; i>0; i--));
  do
    ARG=${!i}
    if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
        PATH="$ARG${PATH:+":$PATH"}"
    fi
  done
  # credits: Guillaume Perrault-Archambault@superuser.com,
  #          ishmael@superuser.com
}
'

    # update path [compatibility with old scripts]
    echo "export PATH_PAGAI=$( dirname "${BIN_PAGAI}" )"
    echo "export PATH_LLVM=${DIR_LLVM}"
    echo 'pathprepend "${PATH_PAGAI}" "${PATH_LLVM}"'                   # ignore shellcheck: no expansion intended
    echo ""
    echo "export PATH_Z3=$( dirname "${BIN_Z3}" )"
    echo "export PATH_OPTIMATHSAT=$( dirname "${BIN_OPTIMATHSAT}" )"
    echo 'pathprepend "${PATH_Z3}" "${PATH_OPTIMATHSAT}"'               # ignore shellcheck: no expansion intended

) > "${BASHRC}"



###
### 6. test environment
###

(
    (( 0 != VERBOSE )) && echo -e "\nEnvironment test ...\n"

    source "${BASHRC}"                                                  # ignore shellcheck: checked separately
    ret=$((0))

    if [ -z "$(which pagai)" ]; then
        echo "error: pagai not found" 1>&2       && ret=$((ret + 1))
    elif (( 0 != VERBOSE )); then
        echo "pagai:"
        echo "- using : $(which pagai)"
    fi

    if [ -z "$(which clang)" ]; then
        echo "error: clang not found" 1>&2       && ret=$((ret + 1))
    elif (( 0 != VERBOSE )); then
        echo "clang:"
        echo "- using : $(which clang)"
        echo "- vers. : $(clang --version | head -n 1 | cut -d\  -f3)"
    fi

    if [ -z "$(which opt)" ]; then
        echo "error: opt not found" 1>&2         && ret=$((ret + 1))
    elif (( 0 != VERBOSE )); then
        echo "opt:"
        echo "- using : $(which opt)"
        echo "- vers. : $(opt --version | sed '2!d;s/  / /g' | cut -d\  -f 4)"
    fi

    if [ -z "$(which llvm-as)" ]; then
        echo "error: llvm-as not found" 1>&2     && ret=$((ret + 1))
    elif (( 0 != VERBOSE )); then
        echo "llvm-as:"
        echo "- using : $(which llvm-as)"
        echo "- vers. : $(llvm-as --version | sed '2!d;s/  / /g' | cut -d\  -f 4)"
    fi

    if [ -z "$(which z3)" ]; then
        echo "error: z3 not found" 1>&2          && ret=$((ret + 1))
    elif (( 0 != VERBOSE )); then
        echo "z3:"
        echo "- using : $(which z3)"
        echo "- vers. : $(z3 -version | cut -d\  -f3)"
    fi

    [[ ${OSTYPE} =~ msys* ]] && optimathsat="optimathsat.exe" || optimathsat="optimathsat"

    if [ -z "$(which ${optimathsat})" ]; then
        echo "error: ${optimathsat} not found" 1>&2 && ret=$((ret + 1))
    elif (( 0 != VERBOSE )); then
        echo "optimathsat:"
        echo "- using : $(which ${optimathsat})"
        echo "- vers. : $(${optimathsat} -version | cut -d\  -f3) (min: 1.4.2)"
    fi

    exit "${ret}"
) || NUM_ERRORS=$((NUM_ERRORS + $?))



###
### 7. done
###

if (( NUM_ERRORS != 0 )); then
    (( 0 != VERBOSE )) && echo -e -n "\n... failure! "
    echo "${NUM_ERRORS} error(s)" 2>/dev/null
else
    (( 0 != VERBOSE )) && echo -e "\n... success!\n"
    echo "Environment stored in <${BASHRC}>"
fi
