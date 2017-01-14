#!/bin/bash

###
###
###

LOC_RUN_EXPERIMENT="$(realpath "$(dirname "${BASH_SOURCE[0]}" )" )"
NAME_RUN_EXPERIMENT="$(basename "${BASH_SOURCE[0]}" )"

###
### run experiment
###

function re_main ()
{
    re_load_libraries || \
        { echo "error: failed to load libraries" 1>&2 ; return "${?}"; };

    re_parse_options "${@}" && shift $((OPTIND - 1)) || return "${?}";

    env_test || \
        { error "${NAME_RUN_EXPERIMENT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "please setup the environment first" "${?}"; return "${?}"; };

    wcet_run_experiment "${@}" || { return "${?}"; };

    return 0;
}

###
### help functions
###

# re_load_libraries:
#   loads bash libraries into environment
#
# shellcheck disable=SC1090
function re_load_libraries()
{
    DIR_BASE="$(realpath "${LOC_RUN_EXPERIMENT}"/../)"

    source "${DIR_BASE}/bin/wcet_lib/generic_lib.sh"   || return 1;
    source "${DIR_BASE}/bin/wcet_lib/wcet_lib.sh"      || return 1;
    source "${DIR_BASE}/bin/wcet_lib/wcet_handlers.sh" || return 1;
    source "${DIR_BASE}/bin/setup_tools/setup_env.sh"  || return 1;
    source "${DIR_BASE}/.wcet_omt.bashrc"              || \
        { error "${NAME_RUN_EXPERIMENT}" "${FUNCNAME[0]}" "$((LINENO - 1))" "please setup the environment first" "${?}"; return "${?}"; };

    return 0
}

# re_parse_options:
#   options parsers for this script
#
# shellcheck disable=SC2015,SC2034
function re_parse_options()
{
    TIMEOUT=0           # 0: disabled, else: seconds to timeout
    VERBOSE_WARNINGS=0  # print warnings [errors are always printed]
    VERBOSE_WORKFLOW=0  # print general informations along search
    VERBOSE_COMMANDS=0  # print relevant pipeline commands being executed
    SKIP_EXISTING=0     # 1  : skip actions which would result in a file being overwritten
                        # 2+ : skip also benchmark results that have already been done
    OPTIND=1
    while getopts "h?t:wfcs:r:" opt; do
        case "${opt}" in
            h|\?)
                re_usage; exit 0; ;;
            t)
                [[ "${OPTARG}" =~ ^[0-9]+$ ]] && TIMEOUT=$((OPTARG))          || { re_usage; return 1; }; ;;
            w)
                VERBOSE_WARNINGS=1; ;;
            f)
                VERBOSE_WORKFLOW=1; ;;
            c)
                VERBOSE_COMMANDS=1; ;;
            s)
                [[ "${OPTARG}" =~ ^[0-9]+$ ]] && SKIP_EXISTING=$((OPTARG))    || { re_usage; return 1; }; ;;
            r)
                is_directory "${OPTARG}" "${FUNCNAME[@]}" "${LINENO}" || return 1;
                wcet_delete_files "${OPTARG}" || return 1;
                exit 0;
            ;;
            *)
                re_usage; return 1; ;;
        esac
    done

    shift $((OPTIND-1))
    [ "$1" = "--" ] && shift

    (( 3 <= ${#} ))            || { re_usage ; return 1; };

    return 0;
}

# re_usage:
#   prints usage information for this script
#
# shellcheck disable=SC2016
function re_usage ()
{
    echo '
NAME
    run_experiment.sh - runs an experimental evaluation

SYNOPSIS
    run_experiment.sh [OPTION]... BENCHMARKS_DIR STATISTICS_DIR HANDLER_UID...

DESCRIPTION
    Runs, for each UID, the associated benchmark handler on each benchmark found
    in BENCHMARKS_DIR and stores the results in STATISTICS_DIR.

    -h, -?  display this help and exit

    -t N    timeout value for each omt solver (seconds)

    -w      enable print of warnings [errors are always enabled]

    -f      enable print of general information

    -c      enable print of calls to external commands

    -s N    skip command execution which would cause a file being overwritten
                - 0 : disabled
                - 1 : skip execution of all external commands except omt solvers
                - 2 : skip also omt solvers when result is already available
            summary results files are always overwritten

HANDLER UIDS
    z3_0                    -- z3          + default encoding
    z3_0_cuts               -- z3          + default encoding + cuts
    optimathsat_0           -- optimathsat + default encoding
    optimathsat_0_cuts      -- optimathsat + default encoding + cuts
    optimathsat_1_sn        -- optimathsat + assert-soft enc. +      + sorting networks
    optimathsat_1_cuts_sn   -- optimathsat + assert-soft enc. + cuts + sorting networks
    optimathsat_2           -- optimathsat + diff. logic enc.
    optimathsat_2_cuts      -- optimathsat + diff. logic enc. + cuts
    optimathsat_2_dl_1      -- optimathsat + diff. logic enc. +      + dlSolver + short tlemmas
    optimathsat_2_cuts_dl_1 -- optimathsat + diff. logic enc. + cuts + dlSolver + short tlemmas
    optimathsat_2_dl_2      -- optimathsat + diff. logic enc. +      + dlSolver + long  tlemmas
    optimathsat_2_cuts_dl_2 -- optimathsat + diff. logic enc. + cuts + dlSolver + long  tlemmas
    optimathsat_2_dl_3      -- optimathsat + diff. logic enc. +      + dlSolver + both  tlemmas
    optimathsat_2_cuts_dl_3 -- optimathsat + diff. logic enc. + cuts + dlSolver + both  tlemmas

    for more, see `wcet_omt/wcet_lib/wcet_handlers.sh`

AUTHOR
    Written by Patrick Trentin.

REPORTING BUGS
    GitHub: https://github.com/PatrickTrentin88/wcet_omt
'
    return 0;
}

###
###
###

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    re_main "${@}"
else
    :
fi
