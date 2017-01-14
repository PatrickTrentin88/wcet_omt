#!/bin/bash

###
###
###

LOC_SETUP_Z3="$(realpath "$(dirname "${BASH_SOURCE[0]}" )" )"
NAME_SETUP_Z3="$(basename "${BASH_SOURCE[0]}" )"

###
### main
###

# z3_setup:
#   installs z3 if needed
#
function z3_setup ()
{
    DIR_BASE="$(realpath "${LOC_SETUP_Z3}"/../../)"
    DIR_TOOLS="${DIR_BASE}/tools"
    LOG_Z3="${DIR_TOOLS}/z3_setup.log"

    z3_load_libraries || \
        { echo "error: failed to load libraries" 1>&2; return "${?}"; };

    z3_parse_options "${@}" && shift $((OPTIND - 1)) || return "${?}";

    z3_is_installed "${DIR_TOOLS}" && \
        { log "z3 is already installed"; return 0; };

    z3_install "${DIR_TOOLS}" "${LOG_Z3}" || \
        { error "${NAME_SETUP_Z3}" "${FUNCNAME[0]}" "$((LINENO - 1))" "setup failed" "${?}"; return "${?}"; };

    [ -s "${LOG_Z3}" ] || rm "${LOG_Z3}" &>/dev/null

    return 0;
}

###
### help functions
###

# z3_usage:
#   prints usage information for this script
#
# shellcheck disable=SC2016
function z3_usage ()
{
    echo '
NAME
    setup_z3.sh - installs z3

SYNOPSIS
    setup_z3.sh [OPTION]...

DESCRIPTION
    Downloads, patches and installas z3 in the <wcet_omt/tools> folder.

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

# z3_load_libraries:
#   loads bash libraries into environment
#
# shellcheck disable=SC1090
function z3_load_libraries ()
{
    source "${DIR_BASE}/bin/wcet_lib/generic_lib.sh" || return 1;

    return 0
}

# z3_parse_options:
#   options parsers for this script
#
# shellcheck disable=SC2034
function z3_parse_options()
{
    VERBOSE_WARNINGS=0  # print warnings [errors are always printed]
    VERBOSE_WORKFLOW=0  # print general informations along search
    VERBOSE_COMMANDS=0  # print relevant pipeline commands being executed

    OPTIND=1
    while getopts "h?wfc" opt; do
        case "${opt}" in
            h|\?)
                z3_usage; exit 0; ;;
            w)
                VERBOSE_WARNINGS=1; ;;
            f)
                VERBOSE_WORKFLOW=1; ;;
            c)
                VERBOSE_COMMANDS=1; ;;
            *)
                z3_usage; return 1; ;;
        esac
    done

    shift $((OPTIND-1))
    [ "$1" = "--" ] && shift

    return 0;
}

# z3_is_installed:
#   tests whether z3's binary is in the desired location
#       ${1}        -- full path to the location in which
#                      z3's binary should be located
#
function z3_is_installed ()
{
    BIN_Z3=$(find -L "${1}/z3" -name z3 -executable -type f 2>/dev/null)
    [ -n "${BIN_Z3}" ] || return 1;
    return 0;
}

# z3_is_downloaded:
#   tests whether z3's source code is in the desired location
#       ${1}        -- full path to the location in which
#                      z3 source code should be located
#
function z3_is_downloaded ()
{
    [ -d "${1}/z3" ] || return 1;
    return 0;
}

# z3_download:
#   clones z3's repository in the desired location
#       ${1}        -- full path to the location in which
#                      z3 should be downloaded
#       ${2}        -- full path to the installation
#                      log file
#
function z3_download ()
{
    local repository=
    repository="https://github.com/Z3Prover/z3.git"

    z3_is_downloaded "${1}" && return 0;

    mkdir -p "${1}/z3" || \
        { error "${NAME_SETUP_Z3}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${1}/z3> cannot be created" "${?}"; return "${?}"; };

    log "cloning z3 repository ..."

    log_cmd "git clone \"${repository}\" \"${1}/z3\" &>\"${2}\""

    git clone "${repository}" "${1}/z3" &>"${2}" || \
        { error "${NAME_SETUP_Z3}" "${FUNCNAME[0]}" "$((LINENO - 1))" "git: <${repository}> cannot be cloned, see <${2}>" "${?}"; return "${?}"; };

    z3_is_downloaded "${1}" || return 1;

    return 0;
}

# z3_install:
#   installs z3 in the desired location
#       ${1}        -- full path to the location in which
#                      z3 should be installed
#       ${2}        -- full path to the installation
#                      log file
#
function z3_install ()
{
    local ret= ;

    z3_is_installed "${1}" && return 0;

    echo "" > "${2}" || \
        { error "${NAME_SETUP_Z3}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${2}> cannot be cleared" "${?}"; return "${?}"; };

    z3_download "${1}" "${2}" || return "${?}";

    pushd "${1}/z3"

    (
        log_cmd "git checkout master &>\"${2}\""
        git checkout master &>"${2}" || \
            { error "${NAME_SETUP_Z3}" "${FUNCNAME[0]}" "$((LINENO - 1))" "git: checkout master failed, see <${2}>" "${?}";  return "${?}"; };

        log_cmd "git reset --hard &>\"${2}\""
        git reset --hard &>"${2}"   || \
            { error "${NAME_SETUP_Z3}" "${FUNCNAME[0]}" "$((LINENO - 1))" "git: reset --hard failed" "${?}";  return "${?}"; };

        log "configuring z3 ..."

        log_cmd "./configure &>\"${2}\""
        ./configure &>"${2}" || \
            { error "${NAME_SETUP_Z3}" "${FUNCNAME[0]}" "$((LINENO - 1))" "z3 sources cannot be configured, see <${2}>" "${?}";  return "${?}"; };

        pushd "build"

        (
            log "building z3 ..."

            log_cmd "make all &>\"${2}\""
            make all &>"${2}" || \
                { error "${NAME_SETUP_Z3}" "${FUNCNAME[0]}" "$((LINENO - 1))" "z3 sources cannot be compiled, see <${2}>" "${?}";  return "${?}"; };
        ) && ret="${?}"

        popd

        return "${ret}"
    ) && ret="${?}"

    popd

    (( ret )) && return "${ret}"

    { z3_is_installed "${1}" && log "... z3 successfully installed"; } || \
        { log "... z3's installation failed"; return 1; };

    return 0;
}

# z3_test:
#   tests access to z3's binary
#
function z3_test()
{
    which z3 &>/dev/null || \
        { error "${NAME_SETUP_Z3}" "${FUNCNAME[0]}" "$((LINENO - 1))" "z3 not found, did you forget to set \${PATH}?" "${?}"; return "${?}"; };

    log "z3: $(which z3) ($(z3 -version | cut -d\  -f 3))"
    return 0
}

###
###
###

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    z3_setup "${@}"
else
    :
fi
