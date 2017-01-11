#!/bin/bash

###
### GLOBALS
###

LOC_WCET_HANDLERS="$(realpath "$(dirname "${BASH_SOURCE[0]}" )" )"

TIMEOUT=$((60))

###
### global options for omt solvers
###

optimathsat_globals=""
optimathsat_globals+=" -optimization.dpll.print_partial_sol=True" # True: prints each search interval improvement
optimathsat_globals+=" -optimization.dpll.search_strategy=0"      # 0: linear, 1: binary, 2: adaptive

z3_globals=""
z3_globals+=""

###
### "inline" help function
###

# wcet_generic_handler:
#   runs an omt solver over a given problem, and returns the parsed results
#       ${1}        -- full path to smt2+blocks file (ext: `.gen`)
#       ${2}        -- encoding type (0: default, 1: assert-soft, 2: difference-logic)
#       ${3}        -- if != 0 then cuts are disabled
#       ${4}        -- omt solver identifier (e.g. 'z3', 'optimathsat')
#       ${5}        -- full path to benchmark file under statistics folder
#                      stripped of the file extension
#       ...         -- solver specific options
#       return ${wcet_generic_handler}
#                   -- the parsed benchmark statitics
#
# shellcheck disable=SC2154,SC2034,SC2068
function wcet_generic_handler()
{
    wcet_generic_handler=

    wcet_gen_omt "${1}" "${2}" 0 "${3}" 0 0 || \
        { error "${FUNCNAME[1]}" "$((LINENO - 1))" "formula generation error" "${?}"; return "${?}"; };
    wcet_update_timeout "${wcet_gen_omt}" "${TIMEOUT}" || \
        { error "${FUNCNAME[1]}" "$((LINENO - 1))" "formula timeout update error" "${?}"; return "${?}"; };
    wcet_run_omt_solver "${4}" "${wcet_gen_omt}" "${5}.log" ${@:6} || \
        { error "${FUNCNAME[1]}" "$((LINENO - 1))" "omt solver error at <${wcet_gen_omt}>" "${?}"; return "${?}"; };
    wcet_parse_output "${wcet_gen_omt}" "${wcet_run_omt_solver}" || \
        { error "${FUNCNAME[1]}" "$((LINENO - 1))" "parsing error" "${?}"; return "${?}"; };

    wcet_generic_handler="${wcet_parse_output}"
    return 0;
}

###
### config-specific handlers
###

# wcet_{*}_handler:
#   runs an omt solver over a given problem, and returns the parsed results
#       ${1}        -- full path to smt2+blocks file (ext: `.gen`)
#       ${2}        -- full path to benchmark file under statistics folder
#                      stripped of the file extension
#       return ${wcet_{*}_handler}
#                   -- the parsed benchmark statitics

###
### Z3 + DEFAULT ENCODING
###


# shellcheck disable=SC2034
function wcet_z3_0_handler
{
    wcet_z3_0_handler= ;

    z3_locals=""
    wcet_generic_handler "${1}" 0 1 "z3" "${2}" "${z3_globals}" "${z3_locals}" || return "${?}"

    wcet_z3_0_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_z3_0_cuts_handler
{
    wcet_z3_0_cuts_handler= ;

    z3_locals=""
    wcet_generic_handler "${1}" 0 0 "z3" "${2}" "${z3_globals}" "${z3_locals}" || return "${?}"

    wcet_z3_0_cuts_handler="${wcet_generic_handler}"
    return 0;
}


###
### OPTIMATHSAT + DEFAULT ENCODING
###


# shellcheck disable=SC2034
function wcet_optimathsat_0_handler
{
    wcet_optimathsat_0_handler= ;

    optimathsat_locals=""
    wcet_generic_handler "${1}" 0 1 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_0_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_optimathsat_0_cuts_handler
{
    wcet_optimathsat_0_cuts_handler= ;

    optimathsat_locals=""
    wcet_generic_handler "${1}" 0 0 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_0_cuts_handler="${wcet_generic_handler}"
    return 0;
}


###
### OPTIMATHSAT + ASSERT-SOFT ENCODING
###

# TODO: maxres vs sorting networks configs [?]

# shellcheck disable=SC2034
function wcet_optimathsat_1_sn_handler
{
    wcet_optimathsat_1_sn_handler= ;

    optimathsat_locals=""
    optimathsat_locals+=" -optimization.card_constr_encoding=2"
    optimathsat_locals+=" -optimization.circuit_limit=20"
    optimathsat_locals+=" -optimization.maxsmt_encoding=31"
    wcet_generic_handler "${1}" 1 1 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_1_sn_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_optimathsat_1_cuts_sn_handler
{
    wcet_optimathsat_1_cuts_sn_handler= ;

    optimathsat_locals=""
    optimathsat_locals+=" -optimization.card_constr_encoding=2"
    optimathsat_locals+=" -optimization.circuit_limit=20"
    optimathsat_locals+=" -optimization.maxsmt_encoding=31"
    wcet_generic_handler "${1}" 1 0 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_1_cuts_sn_handler="${wcet_generic_handler}"
    return 0;
}


###
### OPTIMATHSAT + DIFFERENCE LOGIC ENCODING
###


# shellcheck disable=SC2034
function wcet_optimathsat_2_handler
{
    wcet_optimathsat_2_handler= ;

    optimathsat_locals=""
    wcet_generic_handler "${1}" 2 1 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_2_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_optimathsat_2_cuts_handler
{
    wcet_optimathsat_2_cuts_handler= ;

    optimathsat_locals=""
    wcet_generic_handler "${1}" 2 0 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_2_cuts_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_optimathsat_2_dl_1_handler
{
    wcet_optimathsat_2_dl_1_handler= ;

    optimathsat_locals=""
    optimathsat_locals+=" -theory.la.dl_enabled=True"
    optimathsat_locals+=" -theory.la.dl_filter_tlemmas=False"
    optimathsat_locals+=" -theory.la.dl_interpolation_mode=1"
    optimathsat_locals+=" -theory.la.dl_similarity_threshold=0.5"
    wcet_generic_handler "${1}" 2 1 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_2_dl_1_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_optimathsat_2_cuts_dl_1_handler
{
    wcet_optimathsat_2_cuts_dl_1_handler= ;

    optimathsat_locals=""
    optimathsat_locals+=" -theory.la.dl_enabled=True"
    optimathsat_locals+=" -theory.la.dl_filter_tlemmas=False"
    optimathsat_locals+=" -theory.la.dl_interpolation_mode=1"
    optimathsat_locals+=" -theory.la.dl_similarity_threshold=0.5"
    wcet_generic_handler "${1}" 2 0 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_2_cuts_dl_1_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_optimathsat_2_dl_2_handler
{
    wcet_optimahtsat_2_dl_2_handler= ;

    optimathsat_locals=""
    optimathsat_locals+=" -theory.la.dl_enabled=True"
    optimathsat_locals+=" -theory.la.dl_filter_tlemmas=False"
    optimathsat_locals+=" -theory.la.dl_interpolation_mode=2"
    optimathsat_locals+=" -theory.la.dl_similarity_threshold=0.5"
    wcet_generic_handler "${1}" 2 1 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_2_dl_2_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_optimathsat_2_cuts_dl_2_handler
{
    wcet_optimathsat_2_cuts_dl_2_handler= ;

    optimathsat_locals=""
    optimathsat_locals+=" -theory.la.dl_enabled=True"
    optimathsat_locals+=" -theory.la.dl_filter_tlemmas=False"
    optimathsat_locals+=" -theory.la.dl_interpolation_mode=2"
    optimathsat_locals+=" -theory.la.dl_similarity_threshold=0.5"
    wcet_generic_handler "${1}" 2 0 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_2_cuts_dl_2_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_optimathsat_2_dl_3_handler
{
    wcet_optimathsat_2_dl_3_handler= ;

    optimathsat_locals=""
    optimathsat_locals+=" -theory.la.dl_enabled=True"
    optimathsat_locals+=" -theory.la.dl_filter_tlemmas=False"
    optimathsat_locals+=" -theory.la.dl_interpolation_mode=3"
    optimathsat_locals+=" -theory.la.dl_similarity_threshold=0.5"
    wcet_generic_handler "${1}" 2 1 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_2_dl_3_handler="${wcet_generic_handler}"
    return 0;
}

# shellcheck disable=SC2034
function wcet_optimathsat_2_cuts_dl_3_handler
{
    wcet_optimathsat_2_cuts_dl_3_handler= ;

    optimathsat_locals=""
    optimathsat_locals+=" -theory.la.dl_enabled=True"
    optimathsat_locals+=" -theory.la.dl_filter_tlemmas=False"
    optimathsat_locals+=" -theory.la.dl_interpolation_mode=3"
    optimathsat_locals+=" -theory.la.dl_similarity_threshold=0.5"
    wcet_generic_handler "${1}" 2 0 "optimathsat" "${2}" "${optimathsat_globals}" "${optimathsat_locals}" || return "${?}"

    wcet_optimathsat_2_cuts_dl_3_handler="${wcet_generic_handler}"
    return 0;
}

###
### TESTING
###

function test_handlers () {

    DIR_BASE="$(realpath "${LOC_WCET_HANDLERS}"/../../)"
    source "${DIR_BASE}/bin/wcet_lib/wcet_lib.sh"

    source "${DIR_BASE}/.wcet_omt.bashrc" || \
        { error "${FUNCNAME[0]}" "$((LINENO - 1))" "please setup the environment first" "${?}"; return "${?}"; };

    log "Handlers Test ..."

    wcet_run_experiment "${DIR_BASE}/test/bench" "${DIR_BASE}/test/stats" \
        "z3_0" \
        "z3_0_cuts" \
        "optimathsat_0" \
        "optimathsat_0_cuts" \
        "optimathsat_1_sn" \
        "optimathsat_1_cuts_sn" \
        "optimathsat_2" \
        "optimathsat_2_cuts" \
        "optimathsat_2_dl_1" \
        "optimathsat_2_cuts_dl_1" \
        || { log "... failure!"; return 1; };
#       "optimathsat_2_dl_2" \
#       "optimathsat_2_cuts_dl_2" \
#       "optimathsat_2_dl_3" \
#       "optimathsat_2_cuts_dl_3" \

    log "... success!"

    return 0;
}
