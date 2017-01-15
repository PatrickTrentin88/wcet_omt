#!/bin/bash

###
###
###

LOC_SETUP_PAGAI="$(realpath "$(dirname "${BASH_SOURCE[0]}" )" )"
NAME_SETUP_PAGAI="$(basename "${BASH_SOURCE[0]}" )"

###
### main
###

# pagai_setup:
#   installs pagai if needed
#
function pagai_setup ()
{
    DIR_BASE="$(realpath "${LOC_SETUP_PAGAI}"/../../)"
    DIR_TOOLS="${DIR_BASE}/tools"
    LOG_PAGAI="${DIR_TOOLS}/pagai_setup.log"

    pagai_load_libraries || \
        { echo "error: failed to load libraries" 1>&2; return "${?}"; };

    pagai_parse_options "${@}" && shift $((OPTIND - 1)) || return "${?}";

    pagai_is_installed "${DIR_TOOLS}" && \
        { log "pagai is already installed"; return 0; };

    pagai_install "${DIR_TOOLS}" "${LOG_PAGAI}" || \
        { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "setup failed" "${?}"; return "${?}"; };

    [ -s "${LOG_PAGAI}" ] || rm "${LOG_PAGAI}" &>/dev/null

    return 0;
}

###
### help functions
###

# pagai_usage:
#   prints usage information for this script
#
# shellcheck disable=SC2016
function pagai_usage ()
{
    echo '
NAME
    setup_pagai.sh - installs pagai

SYNOPSIS
    setup_pagai.sh [OPTION]...

DESCRIPTION
    Downloads, patches and installas pagai in the <wcet_omt/tools> folder.

    -h, -?  display this help and exit

    -w      enable print of warnings [errors are always enabled]

    -f      enable print of general information

    -c      enable print of calls to external commands

AUTHOR
    Written by Patrick Trentin.

REPORTING BUGS
    GitHub: https://github.com/PatrickTrentin88/wcet_omt
'
    return 0;
}


# pagai_load_libraries:
#   loads bash libraries into environment
#
# shellcheck disable=SC1090
function pagai_load_libraries ()
{
    source "${DIR_BASE}/bin/wcet_lib/generic_lib.sh" || return 1;

    return 0
}

# pagai_parse_options:
#   options parsers for this script
#
# shellcheck disable=SC2034
function pagai_parse_options()
{
    VERBOSE_WARNINGS=0  # print warnings [errors are always printed]
    VERBOSE_WORKFLOW=0  # print general informations along search
    VERBOSE_COMMANDS=0  # print relevant pipeline commands being executed

    OPTIND=1
    while getopts "h?wfc" opt; do
        case "${opt}" in
            h|\?)
                pagai_usage; exit 0; ;;
            w)
                VERBOSE_WARNINGS=1; ;;
            f)
                VERBOSE_WORKFLOW=1; ;;
            c)
                VERBOSE_COMMANDS=1; ;;
            *)
                pagai_usage; return 1; ;;
        esac
    done

    shift $((OPTIND-1))
    [ "$1" = "--" ] && shift

    return 0;
}

# pagai_is_installed:
#   tests whether pagai's binary is in the desired location
#       ${1}        -- full path to the location in which
#                      pagai's binary should be located
#
function pagai_is_installed ()
{
    BIN_PAGAI=$(find -L "${1}/pagai" -name pagai -executable -type f 2>/dev/null)
    [ -n "${BIN_PAGAI}" ]  || return 1;
    BIN_SMTOPT=$(find -L "${1}/pagai" -name smtopt -executable -type f 2>/dev/null)
    [ -n "${BIN_SMTOPT}" ] || return 1;
    return 0;
}

# pagai_is_downloaded:
#   tests whether pagai's source code is in the desired location
#       ${1}        -- full path to the location in which
#                      pagai source code should be located
#
function pagai_is_downloaded ()
{
    [ -d "${1}/pagai" ] || return 1;
    return 0;
}

# pagai_download:
#   clones pagai's repository in the desired location
#       ${1}        -- full path to the location in which
#                      pagai should be downloaded
#       ${2}        -- full path to the installation
#                      log file
#
function pagai_download ()
{
    local repository=
    repository="http://forge.imag.fr/anonscm/git/pagai/pagai.git"

    pagai_is_downloaded "${1}" && return 0;

    mkdir -p "${1}/pagai" || \
        { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${1}/pagai> cannot be created" "${?}"; return "${?}"; };

    log "cloning pagai repository ..."

    log_cmd "git clone \"${repository}\" \"${1}/pagai\" &>\"${2}\""

    git clone "${repository}" "${1}/pagai" &>"${2}" || \
        { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "git: <${repository}> cannot be cloned, see <${2}>" "${?}"; return "${?}"; };

    pagai_is_downloaded "${1}" || return 1;

    return 0;
}

# pagai_patch:
#   installs pagai in the desired location
#       ${1}        -- full path to the location in which
#                      pagai should be installed
#       ${2}        -- full path to the installation
#                      log file
#
function pagai_patch ()
{
    local patch= ; local commit= ;
    patch="${LOC_SETUP_PAGAI}/patches/pagai.diff"
    commit="16eed0f528a19d54adc538ee5664755a199b5ae0"

    log "patching pagai ..."

    pushd "${1}/pagai"

    (
        log_cmd "git checkout \"${commit}\" &> \"${2}\""
        git checkout "${commit}" &> "${2}" || \
            { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "git: checkout ${commit} failed, see <${2}>" "${?}";  return "${?}"; };

        log_cmd "git reset --hard &> \"${2}\""
        git reset --hard &>"${2}" || \
            { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "git: reset --hard failed" "${?}";  return "${?}"; };

        log_cmd "git apply \"${patch}\" &> \"${2}\""
        git apply "${patch}" &> "${2}" || \
            { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "git: patch ${patch} failed" "${?}";  return "${?}"; };

    ) && ret="${?}"

    popd

    (( ret )) && return "${ret}"
    return 0;
}

# pagai_install:
#   installs pagai in the desired location
#       ${1}        -- full path to the location in which
#                      pagai should be installed
#       ${2}        -- full path to the installation
#                      log file
#
function pagai_install ()
{
    local ret= ;

    pagai_is_installed "${1}" && return 0;

    echo "" > "${2}" || \
        { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${2}> cannot be cleared" "${?}"; return "${?}"; };

    pagai_download "${1}" "${2}" || return "${?}";

    pagai_patch "${1}" "${2}" || return "${?}";

    pushd "${1}/pagai"

    (
        log "pagai auto-installation ..."

        log_cmd "./autoinstall.sh &> \"${2}\""
        ./autoinstall.sh &> "${2}" || \
            { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "pagai could not be installed, see <${2}>" "${?}";  return "${?}"; };
    ) && ret="${?}"

    popd

    (( ret )) && return "${ret}"

    pushd "${1}/pagai/WCET/smtopt"

    (
        log "building smtopt ..."

        log_cmd "make all &> \"${2}\""
        make all &> "${2}" || \
            { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "smtopt could not be compiled, see <${2}>" "${?}";  return "${?}"; };
    ) && ret="${?}"

    popd

    (( ret )) && return "${ret}"

    { pagai_is_installed "${1}" && log "... pagai successfully installed"; } || \
        { log "... pagai's installation failed"; return 1; };

    return 0;
}

# pagai_test:
#   tests access to pagai's binary
#
function pagai_test()
{
    which pagai &>/dev/null || \
        { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "pagai not found, did you forget to set \${PATH}?" "${?}"; return "${?}"; };

    log "pagai: $(which pagai)"
    return 0
}

# clang_test:
#   tests access to clang
#
function clang_test()
{
    which clang &>/dev/null || \
        { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "clang not found, did you forget to set \${PATH}?" "${?}"; return "${?}"; };

    log "clang: $(which clang) ($(clang --version | head -n 1 | cut -d\  -f 3))"
    return 0
}

# opt_test:
#   tests access to opt
#
function opt_test()
{
    which opt &>/dev/null || \
        { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "opt not found, did you forget to set \${PATH}?" "${?}"; return "${?}"; };

    log "opt: $(which opt) ($(opt --version | sed '2!d;s/  */ /g' | cut -d\  -f 4))"
    return 0
}

# llvmas_test:
#   tests access to llvm-as
#
function llvmas_test()
{
    which llvm-as &>/dev/null || \
        { error "${NAME_SETUP_PAGAI}" "${FUNCNAME[0]}" "$((LINENO - 1))" "llvm-as not found, did you forget to set \${PATH}?" "${?}"; return "${?}"; };

    log "llvm-as: $(which llvm-as) ($(llvm-as --version | sed '2!d;s/  */ /g' | cut -d\  -f 4))"
    return 0
}

###
###
###

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    pagai_setup "${@}"
else
    :
fi
