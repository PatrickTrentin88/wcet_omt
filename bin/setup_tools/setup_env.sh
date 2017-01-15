#!/bin/bash

###
###
###

LOC_SETUP_ENV="$(realpath "$(dirname "${BASH_SOURCE[0]}")" )"
NAME_SETUP_ENV="$(basename "${BASH_SOURCE[0]}" )"

###
### main
###

# env_setup:
#   installs environment if needed
#
function env_setup ()
{
    local args=;

    DIR_BASE="$(realpath "${LOC_SETUP_ENV}"/../../)"
    DIR_TOOLS="${DIR_BASE}/tools"
    BASHRC="${DIR_BASE}/.wcet_omt.bashrc"

    inargs=("${@}")

    env_load_libraries "${DIR_BASE}" || \
        { echo "error: failed to load libraries" 1>&2; return "${?}"; };

    env_parse_options "${@}" && shift $((OPTIND - 1)) || return "${?}";

    env_is_installed "${DIR_TOOLS}" "${BASHRC}" && \
            { log "env is already installed"; return 0; };

    env_install "${DIR_TOOLS}" "${BASHRC}" "${inargs[@]}" || \
        { error "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "setup failed" "${?}"; return "${?}"; };

    return 0;
}

###
### help functions
###

# env_usage:
#   prints usage information for this script
#
# shellcheck disable=SC2016
function env_usage ()
{
    echo '
NAME
    setup_env.sh - installs env

SYNOPSIS
    setup_env.sh [OPTION]...

DESCRIPTION
    Downloads, patches and installas env in the <wcet_omt/tools> folder.

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

# env_load_libraries:
#   loads bash libraries into environment
#       ${1}        -- full path to project's base directory
#
# shellcheck disable=SC1090
function env_load_libraries ()
{
    source "${1}/bin/wcet_lib/generic_lib.sh"          || return 1;
    source "${1}/bin/setup_tools/setup_pagai.sh"       || return 1;
    source "${1}/bin/setup_tools/setup_z3.sh"          || return 1;
    source "${1}/bin/setup_tools/setup_optimathsat.sh" || return 1;

    return 0
}

# env_parse_options:
#   options parsers for this script
#
# shellcheck disable=SC2034
function env_parse_options()
{
    VERBOSE_WARNINGS=0  # print warnings [errors are always printed]
    VERBOSE_WORKFLOW=0  # print general informations along search
    VERBOSE_COMMANDS=0  # print relevant pipeline commands being executed

    OPTIND=1
    while getopts "h?wfc" opt; do
        case "${opt}" in
            h|\?)
                env_usage; exit 0; ;;
            w)
                VERBOSE_WARNINGS=1; ;;
            f)
                VERBOSE_WORKFLOW=1; ;;
            c)
                VERBOSE_COMMANDS=1; ;;
            *)
                env_usage; return 1; ;;
        esac
    done

    shift $((OPTIND-1))
    [ "$1" = "--" ] && shift

    return 0;
}

# env_is_installed:
#   tests whether environment is installed
#       ${1}        -- ful path to the location in which
#                      tools should be located
#       ${2}        -- full path to the bashrc file
#
function env_is_installed ()
{
    pagai_is_installed "${1}"       || return 1;
    z3_is_installed "${1}"          || return 1;
    optimathsat_is_installed "${1}" || return 1;
    [ -f "${2}" ] || return 1;
    [ -r "${2}" ] || return 1;
    return 0;
}

# env_install:
#   installs env in the desired location
#       ${1}        -- ful path to the location in which
#                      tools should be installed
#       ${2}        -- full path to the bashrc file
#       ...         -- list of options for setup scripts
#
function env_install ()
{
    local errors=;

    env_is_installed "${1}" "${2}" && return 0;

    errors=$((0))

    log "installing tools ..."

    pagai_setup "${@:3}" || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "pagai setup failed" "${?}"; errors=$((errors + 1)); };

    z3_setup "${@:3}" || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "z3 setup failed" "${?}"; errors=$((errors + 1)); };

    optimathsat_setup "${@:3}" || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "optimathsat setup failed" "${?}"; errors=$((errors + 1)); };

    (( errors <= 0 )) || \
        { error "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "one or more failed setup"; return 1; };

    log "saving environment ..."

    env_get_resources "${1}" || \
        { error "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "unable to collect resource paths" "${?}"; return "${?}"; };


    env_print_bashrc "${env_get_resources}" > "${2}"

    log "testing environment ..."

    env_test "${2}" || \
        { error "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "environment test failed" "${?}"; return "${?}"; };

    { env_is_installed "${1}" "${2}" && log "... env successfully installed"; } || \
        { log "... env's installation failed"; return 1; };

    return 0;
}

# env_get_resources:
#   collects in an associative array all relevant resources
#   within the environment and returns it
#       ${env_get_resources}
#               -- associative array with environment paths
#
function env_get_resources ()
{
    env_get_resources= ;
    local optimathsat= ;

    declare -A args

    args["pagai"]="$(realpath "${1}/pagai/src")"                    || return 1
    args["llvm"]="$(realpath "${1}/pagai/external/llvm/bin")"       || return 1
    args["pagai_z3_lib"]="$(realpath "${1}/pagai/external/z3/lib")" || return 1
    args["pagai_z3"]="$(realpath "${1}/pagai/external/z3/bin")"     || return 1
    args["smtopt"]="$(realpath "${1}/pagai/WCET/smtopt")"           || return 1

    args["z3"]="$(realpath "${1}/z3/build")" || return 1

    [[ "${OSTYPE}" =~ msys* ]] && optimathsat="optimathst.exe" || optimathsat="optimathsat"
    args["optimathsat"]="$(realpath "$(dirname "$(find "${1}" -name "${optimathsat}" -executable -type f 2>/dev/null)" )" )" || return 1;

    args["wcet_lib"]="$(realpath "${1}/../bin/wcet_lib")"       || return 1
    args["setup_tools"]="$(realpath "${1}/../bin/setup_tools")" || return 1

    env_get_resources="$(declare -p args)"
    return 0;
};

# env_print_bashrc:
#   prints the bashrc for the installed environment
#
# shellcheck disable=SC2016
function env_print_bashrc ()
{
    eval "declare -A args=${1#*=}"

    echo -e -n "#!/bin/bash\n"
    echo -e '
pathappend()
{
  for ARG in "$@"
  do
    if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
        PATH="${PATH:+"$PATH:"}$ARG"
    fi
  done
  # credits: Guillaume Perrault-Archambault@superuser.com
}

pathprepend()
{
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
    echo "export PATH_PAGAI=\"${args["pagai"]}\""
    echo "export PATH_LLVM=\"${args["llvm"]}\""
    echo "export PATH_SMTOPT=\"${args["smtopt"]}\""
    echo 'pathprepend "${PATH_PAGAI}" "${PATH_LLVM}" "${PATH_SMTOPT}"'
    echo ""
    echo "export PATH_Z3=\"${args["z3"]}\""
    echo "export PATH_OPTIMATHSAT=\"${args["optimathsat"]}\""
    echo 'pathprepend "${PATH_Z3}" "${PATH_OPTIMATHSAT}"'
    echo ""
    echo "export WCET_LIB_PATH=\"${args["wcet_lib"]}\""
    echo "export SETUP_TOOLS_PATH=\"${args["setup_tools"]}\""
    echo 'export PYTHONPATH="${PYTHONPATH}":"${WCET_LIB_PATH}"'
    echo 'pathprepend "${WCET_LIB_PATH}" "${SETUP_TOOLS_PATH}"'

    return 0;
}

# env_test:
#   tests access to all environment resources
#
# shellcheck disable=SC1090
function env_test ()
{
    local errors=

    errors=$((0))

    source "${1}" || \
        { error "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${1}> could not be sourced" "${?}"; return "${?}"; };

    pagai_test || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "pagai not found" "${?}"; errors=$((errors + 1)); };

    clang_test || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "clang not found" "${?}"; errors=$((errors + 1)); };

    opt_test || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "opt not found" "${?}"; errors=$((errors + 1)); };

    llvmas_test || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "llvm-as not found" "${?}"; errors=$((errors + 1)); };

    z3_test || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "z3 test failed" "${?}"; errors=$((errors + 1)); };

    smtopt_test || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "smtopt not found" "${?}"; errors=$((errors + 1)); };

    optimathsat_test || \
        { warning "${NAME_SETUP_ENV}" "${FUNCNAME[0]}" "$((LINENO - 1))" "optimathsat test failed" "${?}"; errors=$((errors + 1)); };

    return "${errors}";
}

###
###
###

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    env_setup "${@}"
else
    :
fi
