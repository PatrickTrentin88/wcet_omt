#!/bin/bash

###
###
###

LOC_SETUP_OPTIMATHSAT="$(realpath "$(dirname "${BASH_SOURCE[0]}" )" )"
NAME_SETUP_OPTIMATHSAT="$(basename "${BASH_SOURCE[0]}" )"

###
### main
###

# optimathsat_setup:
#   installs optimathsat if needed
#
function optimathsat_setup ()
{
    DIR_BASE="$(realpath "${LOC_SETUP_OPTIMATHSAT}"/../../)"
    DIR_TOOLS="${DIR_BASE}/tools/"
    LOG_OPTIMATHSAT="${DIR_TOOLS}/optimathsat_setup.log"

    optimathsat_load_libraries || \
        { echo "error: failed to load libraries" 1>&2; return "${?}"; };

    optimathsat_parse_options "${@}" && shift $((OPTIND - 1)) || return "${?}";

    optimathsat_is_installed "${DIR_TOOLS}" && \
        { log "optimathsat is already installed"; return 0; };

    optimathsat_install "${DIR_TOOLS}" "${LOG_OPTIMATHSAT}" || \
        { error "${NAME_SETUP_OPTIMATHSAT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "setup failed" "${?}"; return "${?}"; };

    [ -s "${LOG_OPTIMATHSAT}" ] || rm "${LOG_OPTIMATHSAT}" &>/dev/null

    return 0;
}

###
### help functions
###

# optimathsat_usage:
#   prints usage information for this script
#
# shellcheck disable=SC2016
function optimathsat_usage ()
{
    echo '
NAME
    setup_optimathsat.sh - installs optimathsat

SYNOPSIS
    setup_optimathsat.sh [OPTION]...

DESCRIPTION
    Downloads, patches and installas optimathsat in the <wcet_omt/tools> folder.

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

# optimathsat_load_libraries:
#   loads bash libraries into environment
#
# shellcheck disable=SC1090
function optimathsat_load_libraries ()
{
    source "${DIR_BASE}/bin/wcet_lib/generic_lib.sh" || return 1;

    return 0
}

# optimathsat_parse_options:
#   options parsers for this script
#
# shellcheck disable=SC2034
function optimathsat_parse_options()
{
    VERBOSE_WARNINGS=0  # print warnings [errors are always printed]
    VERBOSE_WORKFLOW=0  # print general informations along search
    VERBOSE_COMMANDS=0  # print relevant pipeline commands being executed

    OPTIND=1
    while getopts "h?wfc" opt; do
        case "${opt}" in
            h|\?)
                optimathsat_usage; exit 0; ;;
            w)
                VERBOSE_WARNINGS=1; ;;
            f)
                VERBOSE_WORKFLOW=1; ;;
            c)
                VERBOSE_COMMANDS=1; ;;
            *)
                optimathsat_usage; return 1; ;;
        esac
    done

    shift $((OPTIND-1))
    [ "$1" = "--" ] && shift

    return 0;
}

# optimathsat_is_installed:
#   tests whether optimathsat's binary is in the desired location
#       ${1}        -- full path to the location in which
#                      optimathsat's binary should be located
#
function optimathsat_is_installed ()
{
    local optimathsat=

    [[ "${OSTYPE}" =~ msys* ]] && optimathsat="optimathsat.exe" || optimathsat="optimathsat"

    BIN_OPTIMATHSAT=$(find -L "${1}" -name "${optimathsat}" -executable -type f 2>/dev/null)

    [ -n "${BIN_OPTIMATHSAT}" ] || return 1;
    return 0;
}

# optimathsat_is_downloaded:
#   tests whether optimathsat is in the desired location
#       ${1}        -- full path to the location in which
#                      optimathsat should be located
#
function optimathsat_is_downloaded ()
{
    DIR_OPTIMATHSAT=$(find -L "${DIR_TOOLS}" -name "optimathsat-*" -executable -type d 2>/dev/null)

    [ -n "${DIR_OPTIMATHSAT}" ] || return 1;
    return 0;
}

# optimathsat_download:
#   downloads optimathsat in the desired location
#       ${1}        -- full path to the location in which
#                      optimathsat should be downloaded
#       ${2}        -- full path to the installation
#                      log file
#
function optimathsat_download ()
{
    local ret= ; local package= ;

    optimathsat_is_downloaded "${1}" && return 0;

    log "downloading optimathsat ..."

    optimathsat_get_download_url ||
        { error "${NAME_SETUP_OPTIMATHSAT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "cannot obtain optimathsat download url" "${?}"; return "${?}"; };

    pushd "${1}"

    (
        package="$(basename "${optimathsat_get_download_url}")"

        [ -f "${package}" ] || [ -r "${package}" ] || \
            { log_cmd "wget \"${optimathsat_get_download_url}\" &> \"${2}\""; \
              wget "${optimathsat_get_download_url}" &> "${2}"; } || \
            { error "${NAME_SETUP_OPTIMATHSAT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "wget: failed download, see <${2}>" "${?}"; return "${?}"; };

        if [[ "${package}" =~ tar.gz$ ]] ; then
            log_cmd "tar -xf \"${package}\" &> \"${2}\""
            tar -xf "${package}" &> "${2}" || \
                { error "${NAME_SETUP_OPTIMATHSAT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "cannot extract optimathsat package, see <${2}>" "${?}"; return "${?}"; };
        elif [[ "${package}" =~ zip$ ]]; then
            log_cmd "unzip \"${package}\" &> \"${2}\""
            unzip "${package}" &> "${2}" || \
                { error "${NAME_SETUP_OPTIMATHSAT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "cannot extract optimathsat package, see <${2}>" "${?}"; return "${?}"; };
        else
                { error "${NAME_SETUP_OPTIMATHSAT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${package}> could not be extracted"; return 1; };
        fi

        rm "${package}" &>/dev/null

    ) && ret="${?}"

    popd

    (( ret )) && return "${ret}"

    optimathsat_is_downloaded "${1}" || return 1;

    return 0;
}

# optimathsat_get_download_url:
#   returns the remove url reference to the optimathsat
#   resource to be used on the system
#      return ${optimathsat_get_download_url}
#               -- the url to the remote resource
#
# shellcheck disable=SC2034
function optimathsat_get_download_url ()
{
    optimathsat_get_download_url=
    local repository= ; local version=   ; local platform= ;
    local arch=       ; local extension= ;

    repository="http://optimathsat.disi.unitn.it/releases"
    version="1.4.2"

    # get platform
    case "${OSTYPE}" in
        linux*)  platform="linux";  extension="tar.gz" ;;
        darwin*) platform="macos";  extension="tar.gz" ;;
        msys*)   platform="windows" extension="zip"    ;;
    esac
    [ -n "${platform}" ] || \
        { error "${NAME_SETUP_OPTIMATHSAT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${OSTYPE}> unsupported operating system"; return 1; };

    # get arch
    [[ $(uname -m) =~ 64$ ]] && arch="64-bit" || arch="32-bit"
    [ "${platform}" == "windows" ] && arch="${arch}-mingw"

    optimathsat_get_download_url="${repository}/optimathsat-${version}/optimathsat-${version}-${platform}-${arch}.${extension}"
    return 0;
}

# optimathsat_install:
#   installs optimathsat in the desired location
#       ${1}        -- full path to the location in which
#                      optimathsat should be installed
#       ${2}        -- full path to the installation
#                      log file
#
function optimathsat_install ()
{
    local ret= ;

    optimathsat_is_installed "${1}" && return 0;

    echo "" > "${2}" || \
        { error "${NAME_SETUP_OPTIMATHSAT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${2}> cannot be cleared" "${?}"; return "${?}"; };

    optimathsat_download "${1}" "${2}" || return "${?}";

    { optimathsat_is_installed "${1}" && log "... optimathsat successfully installed"; } || \
        { log "... optimathsat's installation failed"; return 1; };

    return 0
}

# optimathsat_test:
#   tests access to optimahtsat's binary
#
function optimathsat_test()
{
    local optimathsat=

    [[ "${OSTYPE}" =~ msys* ]] && optimathsat="optimathsat.exe" || optimathsat="optimathsat"

    which "${optimathsat}" &>/dev/null || \
        { error "${NAME_SETUP_OPTIMATHSAT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "${optimathsat} not found, did you forget to set \${PATH}?" "${?}"; return "${?}"; };

    log "optimathsat: $(which ${optimathsat}) ($(${optimathsat} -version | cut -d\  -f 3))"
    return 0
}

###
###
###

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    optimathsat_setup "${@}"
else
    :
fi
