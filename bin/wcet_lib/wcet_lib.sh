#!/bin/bash

###
### GLOBALS
###

VERBOSE_CMD=$((1))
SIMULATE=$((0))

###
### COLORS
###

# shellcheck disable=SC2034
function def_colors ()
{
    GREEN="\\033[1;32m"
    NORMAL="\\033[0;39m"
    RED="\\033[1;31m"
    PINK="\\033[1;35m"
    BLUE="\\033[1;34m"
    WHITE="\\033[0;02m"
    WHITE2="\\033[1;08m"
    YELLOW="\\033[1;33m"
    CYAN="\\033[1;36m"
}
def_colors

###
### OUTPUT HANDLING
###

function error()
{
    echo -e -n "${RED}"
    echo -e -n "[error] $(basename "${0}"): " 1>&2
    [ -n "${1}" ] && echo -e -n "${1}: " 1>&2
    [ -n "${2}" ] && echo -e -n "row ${2}: " 1>&2
    [ -n "${3}" ] && echo -e -n "\n[error] ${3}. " 1>&2
    [ -n "${4}" ] && echo -e -n "(exit code: ${4})" 1>&2
    echo -e    "${NORMAL}"
    [ -n "${4}" ] && return "${4}" || return 1
}

function warning()
{
    echo -e -n "${YELLOW}"
    echo -e -n "[warning] $(basename "${0}"): " 1>&2
    [ -n "${1}" ] && echo -e -n "${1}: " 1>&2
    [ -n "${2}" ] && echo -e -n "row ${2}: " 1>&2
    [ -n "${3}" ] && echo -e -n "\n[warning] ${3}." 1>&2
    echo -e    "${NORMAL}"
    return 0
}

function log_cmd()
{
    (( 0 == VERBOSE_CMD )) && return 1
    echo -e "${GREEN}[log] ~\$${NORMAL} ${1}"
    return 0
}

###
### PATH TESTS
###

function is_readable_file()
{
    (( ${#} < 1 ))  && { error "${2}" "${3}" "missing parameter"; return "${?}"; };
    [ ! -f "${1}" ] && { error "${2}" "${3}" "<${1}> does not exist or is not a regular file"; return "${?}"; };
    [ ! -r "${1}" ] && { error "${2}" "${3}" "<${1}> cannot be read"; return "${?}"; };
    return 0;
}

function is_directory()
{
    (( ${#} < 1 ))  && { error "${2}" "${3}" "missing parameter"; return "${?}"; };
    [ ! -d "${1}" ] && { error "${2}" "${3}" "<${1}> does not exist or is not a directory"; return "${?}"; };
    [ ! -x "${1}" ] && { error "${2}" "${3}" "<${1}> cannot be accessed"; return "${?}"; };
    return 0;
}

###
### FORMULAS GENERATION
###

# wcet_gen_bytecode:
#   generates bytecode from a C source code file
#       ${1}        -- full path to C file (ext: `.c`)
#       return ${wcet_gen_bytecode}
#                   -- full path to bytecode file (ext: `.bc`)
#
# shellcheck disable=SC2034
function wcet_gen_bytecode()
{
    wcet_gen_bytecode=
    local dst_file=

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [[ "${1}" =~ .c$ ]] && dst_file="${1:: -2}.bc" || dst_file="${1}.bc"

    log_cmd "clang -emit-llvm -c \"${1}\" -o \"${dst_file}\""
    if (( 0 == SIMULATE )); then
        clang -emit-llvm -c "${1}" -o "${dst_file}" || \
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "unable to generate bytecode" "${?}"; return "${?}"; };
    fi

    wcet_gen_bytecode="${dst_file}"
    return 0;
}

# wcet_bytecode_optimization:
#   applies optimization techniques to bytecode
#       ${1}        -- full path to bytecode file (ext: `.bc`)
#       return ${wcet_bytecode_optimization}
#                   -- full path to optimized file (ext: `.opt.ll`)
#
# shellcheck disable=SC2034
function wcet_bytecode_optimization()
{
    wcet_bytecode_optimization=
    local dst_file= ; local errmsg= ;

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [[ "${1}" =~ .bc$ ]] && dst_file="${1:: -3}.opt.ll" || dst_file="${1}.opt.ll"


    log_cmd "pagai -i \"${1}\" --dump-ll --wcet --loop-unroll > \"${dst_file}\""
    if (( 0 == SIMULATE )); then
        pagai -i "${1}" --dump-ll --wcet --loop-unroll > "${dst_file}" || \
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "pagai error" "${?}"; return "${?}"; };

        # pagai does not set error status
        errmsg="$(head -n 1 "${dst_file}" | grep "ERROR" | cut -d\  -f 2-)"
        if [ -n "${errmsg}" ]; then
            error "${FUNCNAME[0]}" "$((LINENO - 6))" "${errmsg:: -1}"; return "${?}";
        fi
    fi

    log_cmd "llvm-as \"${dst_file}\""
    if (( 0 == SIMULATE )); then
        llvm-as "${dst_file}" || \
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "llvm-as error" "${?}"; return "${?}"; };
    fi

    wcet_bytecode_optimization="${dst_file}"
    return 0;
}

# wcet_gen_blocks:
#   generates SMT2 formula + Basic Blocks starting from bytecode
#       ${1}        -- full path to bytecode file (ext: `.bc`)
#       [${2}]      -- pagai smt2 solver [default: "z3"]
#       return ${wcet_gen_blocks}
#                   -- full path to generated file (ext: `.gen`)
#
# shellcheck disable=SC2034
function wcet_gen_blocks()
{
    wcet_gen_blocks=
    local dst_file= ; local errmsg= ;

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [[ "${1}" =~ .bc$ ]] && dst_file="${1:: -3}.gen" || dst_file="${1}.gen"
    (( ${#} == 2 )) && solver="${2}" || solver="z3";

    log_cmd "pagai -i \"${1}\" -s \"${solver}\" --wcet --printformula --skipnonlinear --loop-unroll > \"${dst_file}\""
    if (( 0 == SIMULATE )); then
        pagai -i "${1}" -s "${solver}" --wcet --printformula --skipnonlinear --loop-unroll > "${dst_file}" || \
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "pagai error" "${?}"; return "${?}"; };

        # pagai does not set error status
        errmsg="$(head -n 1 "${dst_file}" | grep "ERROR" | cut -d\  -f 2-)"
        if [ -n "${errmsg}" ]; then
            error "${FUNCNAME[0]}" "$((LINENO - 6))" "${errmsg:: -1}"; return "${?}";
        fi
    fi

    wcet_gen_blocks="${dst_file}"
    return 0;
}

# wcet_gen_omt:
#   generates OMT formula starting from the blocks file
#       ${1}        -- full path to blocks file (ext: `.gen`)
#       [${2}]      -- encoding type
#                           0: default, [same as Henry:2014:CWE:2597809.2597817]
#                           1: assert-soft base
#                           2: difference-logic based
#       [${3}]      -- timeout in seconds
#       [${4}]      -- disable summaries if non-zero
#       [${5}]      -- dump matchings to file if non-zero (ext: `.llvmtosmtmatch`)
#       [${6}]      -- dump longest execution path to file if non-zero (ext: `.longestsyntactic`)
#       return ${wcet_gen_omt}
#                   -- full path to OMT formula file (ext: `.smt2`)
#
# shellcheck disable=SC2034
function wcet_gen_omt()
{
    wcet_gen_omt=
    local encoding=      ; local timeout=  ; local no_summaries= ; local print_matching= ;
    local print_maxpath= ; local dst_base= ; local dst_file=     ; declare -a options    ;

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [ -n "${2}" ] && (( 0 <= "${2}" )) && (( "${2}" <= 2 )) && encoding=$((${2})) || encoding=$((0))
    [ -n "${3}" ] && (( 0 <= "${3}" )) && timeout=$((${3})) || timeout=$((0))
    [ -n "${4}" ] && no_summaries=$((${4}))   || no_summaries=$((0))
    [ -n "${5}" ] && print_matching=$((${5})) || print_matching=$((0))
    [ -n "${6}" ] && print_maxpath=$((${6}))  || print_maxpath=$((0))
    [[ "${1}" =~ .gen$ ]] && dst_base="${1:: -4}" || dst_base="${1}"
    dst_file="${dst_base}.${encoding}.smt2"

    options=("--encoding" "${encoding}")
    (( 0 != timeout ))        && options+=("--timeout" "${timeout}")
    (( 0 != no_summaries ))   && options+=("--nosummaries")
    (( 0 != print_matching )) && options+=("--smtmatching" "${dst_base}.llvmtosmtmatch")
    (( 0 != print_maxpath ))  && options+=("--printlongestsyntactic" "${dst_base}.longestsyntactic")

    log_cmd "wcet_generator.py ${options[*]} \"${1}\" > \"${dst_file}\""
    if (( 0 == SIMULATE )); then
        # ignore shellcheck: expansions intended
        wcet_generator.py "${options[@]}" "${1}" > "${dst_file}" || \
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "wcet_generator.py error" "${?}"; return "${?}"; };
    fi

    wcet_gen_omt="${dst_file}"
    return 0;
}

# wcet_update_timeout:
#   performs an inline update of the timeout value in an OMT formula
#       ${1}        -- full path to the OMT formula (ext: `.smt2`)
#       [${2}]      -- new timeout value, in seconds
#
function wcet_update_timeout ()
{
    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    [ -z "${2}" ] && set -- "${1}" "0"

    if grep -q "set-option :timeout" "${1}"; then
        if (( 0 < ${2} )); then
            sed -i "s/[; ]*\((set-option :timeout\)  *\([0-9]*\.[0-9]*\)/\1 ${2}.0/" "${1}"
        else
            sed -i 's/^ *\((set-option :timeout  *[0-9]*\.[0-9]*)\)/;\1/' "${1}"
        fi
    else
        if (( 0 < ${2} )); then
            sed -i "1s/^/(set-option :timeout ${2}.0)\n/" "${1}"
        fi
    fi
}

###
### OMT SOLVER EXECUTION
###

# wcet_run_optimathsat:
#   runs optimathsat over an OMT formula
#       ${1}        -- full path to OMT formula (ext: `.smt2`)
#       ${2}        -- full path to output file (ext: any)
#       [...]       -- optimathsat options
#   return ${wcet_run_optimathsat}
#                   -- full path to output file (= ${2})
#
# shellcheck disable=SC2034
function wcet_run_optimathsat ()
{
    wcet_run_optimathsat=

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    is_directory "$(dirname "${2}")" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    log_cmd "optimathsat ${*:3} < \"${1}\" > \"${2}\" 2>&1"

    if (( 0 == SIMULATE )); then
        /usr/bin/time -f "# real-time: %e" optimathsat "${@:3}" < "${1}" > "${2}" 2>&1 ||
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "optimathsat error" "${?}"; return "${?}"; };
    fi

    wcet_run_optimathsat="${2}"
    return 0;
}

# wcet_run_z3:
#   runs z3 over an OMT formula
#       ${1}        -- full path to OMT formula (ext: `.smt2`)
#       ${2}        -- full path to output file (ext: any)
#       [...]       -- z3 options
#   return ${wcet_run_z3}
#                   -- full path to output file (= ${2})
#
# shellcheck disable=SC2034
function wcet_run_z3 ()
{
    wcet_run_z3=

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    is_directory "$(dirname "${2}")" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    log_cmd "z3 ${*:3} \"${1}\" > \"${2}\" 2>&1"

    if (( 0 == SIMULATE )); then
        sed 's/\((maximize .*\) \(:.* :.*)\)/\1)/' "${1}" | /usr/bin/time -f "# real-time: %e" z3 -in -smt2 "${@:3}" > "${2}" 2>&1 ||
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "z3 error" "${?}"; return "${?}"; };
    fi

    wcet_run_z3="${2}"
    return 0;
}

# wcet_run_omt_solver:
#   runs an OMT solver over an OMT formula
#       ${1}        -- omt solver to be used (e.g. "optimathsat", "z3")
#       ${2}        -- full path to OMT formula (ext: `.smt2`)
#       ${3}        -- full path to output file (ext: any)
#       [...]       -- omt solver options
#   return ${wcet_run_omt_solver}
#                   -- full path to output file (= ${2})
#
# shellcheck disable=SC2034
function wcet_run_omt_solver ()
{
    wcet_run_omt_solver=

    if [[ "${1}" =~ ^z3$ ]]; then
        wcet_run_z3 "${@:2}" || return "${?}"
        wcet_run_omt_solver="${wcet_run_z3}"
    elif [[ "${1}" =~ ^optimathsat$ ]]; then
        wcet_run_optimathsat "${@:2}" || return "${?}"
        wcet_run_omt_solver="${wcet_run_optimathsat}"
    else
        error "${FUNCNAME[0]}" "${LINENO}" "unknown smt2 solver <${1}>" && exit "${?}"
    fi

    return 0;
}

###
### OMT OUTPUT PARSING AND PRESENTATION
###

# wcet_print_data:
#   prints data collected from OMT execution on stdout
#       ${1}        -- associative array with appropriate values
#
# shellcheck disable=SC2154
function wcet_print_data()
{
    eval "declare -A argArr=${1#*=}"

    printf "| %-12s | %-12s | %-12s | %-12s | %-12s | %-12s | %-12s | %-32s | %-32s |\n" \
        "${argArr["max_path"]}"   \
        "${argArr["opt_value"]}"  \
        "${argArr["gain"]}"       \
        "${argArr["num_cuts"]}"   \
        "${argArr["real_time"]}"  \
        "${argArr["llvm_size"]}"  \
        "${argArr["num_blocks"]}" \
        "${argArr["smt2_file"]}"  \
        "${argArr["out_file"]}"
}

# wcet_print_header:
#   prints header for `wcet_print_data`
#
function wcet_print_header()
{
    declare -A args
    args["llvm_size"]="llvm size"
    args["num_blocks"]="# blocks"
    args["num_cuts"]="# cuts"
    args["max_path"]="syn. length"
    args["opt_value"]="sem. length"
    args["real_time"]="time (s.)"
    args["smt2_file"]="smt2 file"
    args["out_file"]="output file"
    args["gain"]="gain (%)"

    wcet_print_data "$(declare -p args)"
}

# wcet_parse_output:
#   parses output of an OMT solver and collects relevant information
#       ${1}        -- full path to OMT formula (ext: `.smt2`)
#       ${2}        -- full path to output data (ext: any)
#       return ${wcet_parse_output}
#                   -- formatted string with relevant information
#
# shellcheck disable=SC2034
function wcet_parse_output ()
{
    wcet_parse_output=
    local bc_file= ;
    declare -A args

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}" # smt2 formula
    is_readable_file "${2}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}" # optimathsat output

    bc_file="${1:: -7}.bc"
    [ -f "${bc_file}" ] && [ -r "${bc_file}" ] || bc_file="${1:: -7}"
    is_readable_file "${bc_file}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    args["llvm_size"]="$(llvm-dis -o - "${bc_file}"          | wc -l)"
    args["num_blocks"]="$(grep -c "declare-fun b_" "${1}" )"
    args["num_cuts"]="$(grep "NB_CUTS" "${1}"      | cut -d\  -f 4)"
    args["max_path"]="$(grep "LONGEST_PATH" "${1}" | cut -d\  -f 4)"
    args["real_time"]="$(grep "real-time" "${2}"   | cut -d\  -f 3)"
    args["smt2_file"]="${1}"
    args["out_file"]="${2}"


    if grep -q "# Optimum:" "${2}"; then
        args["opt_value"]="$(grep "Optimum" "${2}"         | cut -d\  -f 3)"
    elif grep "(objectives" "${2}"; then
        args["opt_value"]="$(grep "objectives" -A 1 "${2}" | tail -n 1 | cut -d\  -f 3 | sed 's/)//')"
    else
        error "${FUNCNAME[0]}" "${LINENO}" "nothing to parse" && exit "${?}"
    fi

    args["gain"]=$(awk -v MAX="${args["max_path"]}" -v OPT="${args["opt_value"]}" \
        "BEGIN {printf \"%.2f\", ((MAX - OPT) * 100 / MAX)}")

    # TODO: set flags for files with errors / timeouts

    wcet_parse_output="$(wcet_print_data "$(declare -p args)")"
    return 0
}
