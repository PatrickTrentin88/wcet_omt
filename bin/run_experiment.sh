#!/bin/bash

###
### load functions library
###

LOC_RUN_EXPERIMENT="$(realpath "$(dirname "${BASH_SOURCE[0]}" )" )"

###
### run experiment
###

function main ()
{
    load_libraries             || \
        { echo "error: failed to load libraries" 1>&2 ; return "${?}"; };

    parse_options "${@}" && shift $((OPTIND - 1)) || return "${?}";

    # TODO: test components

    log "start experiment ..."

    wcet_run_experiment "${@}" || {            return "${?}"; };

    log "... end experiment."

    return 0;
}

###
### help functions
###

# load_libraries:
#   loads bash libraries into environment
#
# shellcheck disable=SC1090
function load_libraries()
{
    DIR_BASE="$(realpath "${LOC_RUN_EXPERIMENT}"/../)"

    source "${DIR_BASE}/bin/wcet_lib/generic_lib.sh"   || return 1;
    source "${DIR_BASE}/bin/wcet_lib/wcet_lib.sh"      || return 1;
    source "${DIR_BASE}/bin/wcet_lib/wcet_handlers.sh" || return 1;
    source "${DIR_BASE}/.wcet_omt.bashrc"              || \
        { error "${FUNCNAME[0]}" "$((LINENO - 1))" "please setup the environment first" "${?}"; return "${?}"; };

    return 0
}

# parse_options:
#   options parsers for this script
#
# shellcheck disable=SC2015,SC2034
function parse_options()
{
    TIMEOUT=0           # 0: disabled, else: seconds to timeout
    VERBOSE_WARNINGS=0  # print warnings [errors are always printed]
    VERBOSE_WORKFLOW=0  # print general informations along search
    VERBOSE_COMMANDS=0  # print relevant pipeline commands being executed
    SIMULATION_ONLY=0   # skip execution of pipeline commands (e.g.: clang, llvm, z3, optimathsat, etc.)
    SKIP_EXISTING=0     # 1  : skip actions which would result in a file being overwritten
                        # 2+ : skip also benchmark results that have already been done
    OPTIND=1
    while getopts "h?t:wfcos:" opt; do
        case "$opt" in
            h|\?)
                re_usage; exit 0; ;;
            t)
                [[ "${OPTARG}" =~ ^[0-9]+$ ]] && TIMEOUT=$((OPTARG))          || { re_usage; exit 1; }; ;;
            w)
                VERBOSE_WARNINGS=1; ;;
            f)
                VERBOSE_WORKFLOW=1; ;;
            c)
                VERBOSE_COMMANDS=1; ;;
            o)
                SIMULATION_ONLY=1; ;;
            s)
                [[ "${OPTARG}" =~ ^[0-9]+$ ]] && SKIP_EXISTING=$((OPTARG))    || { re_usage; exit 1; }; ;;
            *)
                re_usage; exit 1; ;;
        esac
    done

    shift $((OPTIND-1))
    [ "$1" = "--" ] && shift

    (( 3 <= ${#} ))            || { re_usage ; return 1; };
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

    -o      skip execution of any external command

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

main "${@}"
