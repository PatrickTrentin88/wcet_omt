#!/bin/bash

###
### GLOBALS
###

LOC_WCET_LIB="$(realpath "$(dirname "${BASH_SOURCE[0]}" )" )"
NAME_WCET_LIB="$(basename "${BASH_SOURCE[0]}" )"

VERBOSE_WARNINGS=$((0))
VERBOSE_COMMANDS=$((0))
VERBOSE_WORKFLOW=$((0))
SKIP_EXISTING=$((0))

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

    is_readable_file "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [[ "${1}" =~ .c$ ]] && dst_file="${1:: -2}.bc" || dst_file="${1}.bc"

    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        log_cmd "clang -emit-llvm -c \"${1}\" -o \"${dst_file}\""
        clang -emit-llvm -c "${1}" -o "${dst_file}" || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "unable to generate bytecode" "${?}"; return "${?}"; };
    fi

    wcet_gen_bytecode="${dst_file}"
    return 0;
}

# wcet_bytecode_optimization:
#   applies optimization techniques to bytecode
#       ${1}        -- full path to bytecode file (ext: `.bc`)
#       return ${wcet_bytecode_optimization}
#                   -- full path to optimized file (ext: `.opt.bc`)
#
# shellcheck disable=SC2034
function wcet_bytecode_optimization()
{
    wcet_bytecode_optimization=
    local dst_file= ; local errmsg= ;

    is_readable_file "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [[ "${1}" =~ .bc$ ]] && dst_file="${1:: -3}.opt.ll" || dst_file="${1}.opt.ll"

    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        log_cmd "pagai -i \"${1}\" --dump-ll --wcet --loop-unroll > \"${dst_file}\""
        pagai -i "${1}" --dump-ll --wcet --loop-unroll > "${dst_file}" || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "pagai error" "${?}"; return "${?}"; };

        # pagai does not set error status
        errmsg="$(head -n 1 "${dst_file}" | grep "ERROR" | cut -d\  -f 2-)"
        if [ -n "${errmsg}" ]; then
            error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 6))" "${errmsg:: -1}"; return "${?}";
        fi
    fi

    src_file="${dst_file}"
    dst_file="${dst_file::-3}.bc"
    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        log_cmd "llvm-as -o \"${dst_file}\" \"${src_file}\""
        llvm-as -o "${dst_file}" "${src_file}" || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "llvm-as error" "${?}"; return "${?}"; };
    fi

    wcet_bytecode_optimization="${dst_file}"
    return 0;
}

# wcet_unroll_loops:
#   attempts a removal of graph loops through unrolling
#       ${1}        -- full path to bytecode file (ext: `.bc`)
#       return ${wcet_bytecode_optimization}
#                   -- full path to optimized file (ext: `.unr.bc`)
#
# shellcheck disable=SC2034
function wcet_unroll_loops()
{
    wcet_unroll_loops=
    local dst_file= ; local err_file= ; local errmsg= ;

    is_readable_file "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [[ "${1}" =~ .bc$ ]] && dst_file="${1:: -3}.unr.bc" || dst_file="${1}.unr.bc"
    [[ "${1}" =~ .bc$ ]] && err_file="${1:: -3}.unr.err" || err_file="${1}.unr.err"

    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        # NOTE: the following options are omitted since result in partial unrolling
        # -unroll-allow-partial
        # -unroll-count=N
        log_cmd "opt -mem2reg -simplifycfg -loops -lcssa -loop-rotate -loop-unroll -debug -unroll-threshold=1000000000 \"${1}\" -o \"${dst_file}\" &>\"${err_file}\""

        opt -mem2reg -simplifycfg -loops -lcssa -loop-rotate -loop-unroll -debug -unroll-threshold=1000000000 "${1}" -o "${dst_file}" &>"${err_file}" || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "opt error, see <${err_file}>" "${?}"; return "${?}"; };
    fi

    wcet_unroll_loops="${dst_file}"
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

    is_readable_file "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [[ "${1}" =~ .bc$ ]] && dst_file="${1:: -3}.gen" || dst_file="${1}.gen"
    (( ${#} == 2 )) && solver="${2}" || solver="z3";

    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        pagai -i "${1}" --wcet --skipnonlinear --loop-unroll &>/dev/null # preliminary sig-sev test
        if (( "${?}" == 139 )); then
            warning "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 2))" "pagai segmentation fault with  <${1}>"; return 139;
        fi

        log_cmd "pagai -i \"${1}\" --wcet --printformula --skipnonlinear --loop-unroll > \"${dst_file}\""
        pagai -i "${1}" --wcet --printformula --skipnonlinear --loop-unroll > "${dst_file}" || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "pagai error" "${?}"; return "${?}"; };

        # pagai does not set error status
        errmsg="$(head -n 1 "${dst_file}" | grep "ERROR" | cut -d\  -f 2-)"
        if [ -n "${errmsg}" ]; then
            error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 6))" "${errmsg:: -1}"; return "${?}";
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
#                           1: assert-soft based
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

    is_readable_file "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [ -n "${2}" ] && (( 0 <= "${2}" )) && (( "${2}" <= 2 )) && encoding=$((${2})) || encoding=$((0))
    [ -n "${3}" ] && (( 0 <= "${3}" )) && timeout=$((${3})) || timeout=$((0))
    [ -n "${4}" ] && no_summaries=$((${4}))   || no_summaries=$((0))
    [ -n "${5}" ] && print_matching=$((${5})) || print_matching=$((0))
    [ -n "${6}" ] && print_maxpath=$((${6}))  || print_maxpath=$((0))
    [[ "${1}" =~ .gen$ ]] && dst_base="${1:: -4}" || dst_base="${1}"

    if (( 0 != no_summaries )); then
        dst_file="${dst_base}.${encoding}.smt2"
    else
        dst_file="${dst_base}.${encoding}.cuts.smt2"
    fi

    options=("--encoding" "${encoding}")
    (( 0 != timeout ))        && options+=("--timeout" "${timeout}")
    (( 0 != no_summaries ))   && options+=("--nosummaries")
    (( 0 != print_matching )) && options+=("--smtmatching" "${dst_base}.llvmtosmtmatch")
    (( 0 != print_maxpath ))  && options+=("--printlongestsyntactic" "${dst_base}.longestsyntactic")

    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        log_cmd "wcet_generator.py ${options[*]} \"${1}\" > \"${dst_file}\""
        wcet_generator.py "${options[@]}" "${1}" > "${dst_file}" || \
        {
            errmsg="$(grep ";; ERROR" "${dst_file}" | cut -d\  -f 3-)";
            if [ -n "${errmsg}" ]; then
                error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 5))" "${errmsg:: -1}"; return "${?}";
            else
                error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "wcet_generator.py error" "${?}"; return "${?}";
            fi
        };
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
    is_readable_file "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    [ -z "${2}" ] && set -- "${1}" "0"

    if (( 0 < ${2} )); then
        if grep -q "set-option :timeout ${2}.0" "${1}"; then
            :   # avoid unecessary overwrite
        elif grep -q "set-option :timeout" "${1}"; then
            sed -i "s/[; ]*\((set-option :timeout\)  *\([0-9]*\.[0-9]*\)/\1 ${2}.0/" "${1}"
        else
            sed -i "1s/^/(set-option :timeout ${2}.0)\n/" "${1}"
        fi
    else
        if grep -q "set-option :timeout" "${1}"; then
            sed -i 's/^ *\((set-option :timeout  *[0-9]*\.[0-9]*)\)//' "${1}"
        else
            :   # avoid unecessary overwrite
        fi
    fi
    return 0;
}

###
### OMT SOLVER EXECUTION
###

# wcet_run_optimathsat:
#   runs optimathsat over an OMT formula
#       ${1}        -- seconds to timeout, 0: disabled
#       ${2}        -- full path to OMT formula (ext: `.smt2`)
#       ${3}        -- full path to output file (ext: any)
#       [...]       -- optimathsat options
#   return ${wcet_run_optimathsat}
#                   -- full path to output file (= ${3})
#
# shellcheck disable=SC2034
function wcet_run_optimathsat ()
{
    wcet_run_optimathsat=
    local ret=

    is_readable_file "${2}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    is_directory "$(dirname "${3}")" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    if (( SKIP_EXISTING <= 1 )) || test ! \( -f "${3}" -a -r "${3}" \) ; then
        log_cmd "optimathsat ${*:4} < \"${2}\" &> \"${3}\""

        timeout "${1}" /usr/bin/time -f "# real-time: %e" optimathsat "${@:4}" < "${2}" &> "${3}"
        ret="${?}"

        if (( ret != 0 )); then
            if (( ret == 124 )); then # timeout
                echo -e "\ntimeout\n# real-time: ${1}.01" >> "${3}"
            else
                { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 7))" "optimathsat error, see <${3}>" "${?}"; return "${?}"; };
            fi
        fi
    fi

    wcet_run_optimathsat="${3}"
    return 0;
}

# wcet_run_z3:
#   runs z3 over an OMT formula
#       ${1}        -- seconds to timeout, 0: disabled
#       ${2}        -- full path to OMT formula (ext: `.smt2`)
#       ${3}        -- full path to output file (ext: any)
#       [...]       -- z3 options
#   return ${wcet_run_z3}
#                   -- full path to output file (= ${3})
#
# shellcheck disable=SC2034
function wcet_run_z3 ()
{
    wcet_run_z3=
    local ret=

    is_readable_file "${2}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    is_directory "$(dirname "${3}")" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    if (( SKIP_EXISTING <= 1 )) || test ! \( -f "${3}" -a -r "${3}" \) ; then
        log_cmd "z3 ${*:4} \"${2}\" &> \"${3}\""

        sed 's/\((set-option :timeout [0-9][0-9]*\).0)/\1000.0)/;s/\((maximize .*\) \(:.* :.*)\)/\1)/' "${2}" | \
            timeout "${1}" /usr/bin/time -f "# real-time: %e" z3 -in -smt2 "${@:4}" &> "${3}"
        ret="${?}"

        if (( ret != 0 )); then
            if (( ret == 124 )); then # timeout
                echo -e "\ntimeout\n# real-time: ${1}.01" >> "${3}"
            else
                { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 7))" "z3 error, see <${3}>" "${?}"; return "${?}"; };
            fi
        fi
    fi

    wcet_run_z3="${3}"
    return 0;
}

# wcet_run_smtopt:
#   runs smtopt over an OMT formula
#       ${1}        -- seconds to timeout, 0: disabled
#       ${2}        -- full path to OMT formula (ext: `.smt2`)
#       ${3}        -- full path to output file (ext: any)
#       [...]       -- smtopt options
#   return ${wcet_run_smtopt}
#                   -- full path to output file (= ${3})
#
# shellcheck disable=SC2034
function wcet_run_smtopt ()
{
    wcet_run_smtopt=
    local ret= ; local cost_var= ; local max= ;

    is_readable_file "${2}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    is_directory "$(dirname "${3}")" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    if (( SKIP_EXISTING <= 1 )) || test ! \( -f "${3}" -a -r "${3}" \) ; then
        cost_var="$(grep maximize "${2}" | cut -d\  -f 2 | sed 's/)//')"
        [ -n "${cost_var}" ] || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 2))" "unable to parse cost variable"; return "${?}"; };

        max="$(grep LONGEST_PATH "${2}" | cut -d\  -f 4)"
        [ -n "${max}" ] || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 2))" "unable to parse longest syntactic path"; return "${?}"; };

        log_cmd "smtopt - \"${cost_var}\" -v -M \"${max}\" ${*:4} \"${2}\" &> \"${3}\""

        sed 's/\((set-option :timeout [0-9][0-9]*\).0)/\1000.0)/;s/(maximize .*)//' "${2}" | \
            timeout "${1}" /usr/bin/time -f "\n# real-time: %e" smtopt - "${cost_var}" -v -M "${max}" "${@:4}" &> "${3}"
        ret="${?}"

        if (( ret != 0 )); then
            if (( ret == 124 )); then # timeout
                echo -e "\ntimeout\n# real-time: ${1}.01" >> "${3}"
            else
                { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 7))" "smtopt error, see <${3}>" "${?}"; return "${?}"; };
            fi
        fi
    fi

    wcet_run_smtopt="${3}"
    return 0;
}

# wcet_run_omt_solver:
#   runs an OMT solver over an OMT formula
#       ${1}        -- omt solver to be used (e.g. "optimathsat", "z3")
#       ${2}        -- seconds to timeout, 0: disabled
#       ${3}        -- full path to OMT formula (ext: `.smt2`)
#       ${4}        -- full path to output file (ext: any)
#       [...]       -- omt solver options
#   return ${wcet_run_omt_solver}
#                   -- full path to output file (= ${4})
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
    elif [[ "${1}" =~ ^smtopt$ ]]; then
        wcet_run_smtopt "${@:2}" || return "${?}"
        wcet_run_omt_solver="${wcet_run_smtopt}"
    else
        error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" "unknown smt2 solver <${1}>" && exit "${?}"
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

    printf "| %-12s | %-12s | %-12s | %-12s | %-12s | %-12s | %-12s | %-12s | %-12s | %-12s | %-64s | %-64s |\n" \
        "${argArr["max_path"]}"   \
        "${argArr["opt_value"]}"  \
        "${argArr["gain"]}"       \
        "${argArr["num_cuts"]}"   \
        "${argArr["real_time"]}"  \
        "${argArr["status"]}"     \
        "${argArr["timeout"]}"    \
        "${argArr["errors"]}"     \
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
    args["status"]="status"
    args["timeout"]="timeout"
    args["errors"]="# errors"

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
    local bc_file= ; local is_unknown=  ; local is_unsat= ; local is_sat= ;
    local solver=  ; local has_timeout= ;
    declare -A args

    is_readable_file "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}" # smt2 formula
    is_readable_file "${2}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}" # optimathsat/z3 output

    bc_file="${1/\.[0-9]*\.smt2/}.bc"
    [ -f "${bc_file}" ] && [ -r "${bc_file}" ] || bc_file="${1/\.[0-9]?(\.cuts)\.smt2/}"
    is_readable_file "${bc_file}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    args["llvm_size"]="$(llvm-dis -o - "${bc_file}"          | wc -l)"
    args["num_blocks"]="$(grep -c "declare-fun b_" "${1}" )"
    args["num_cuts"]="$(grep "NB_CUTS" "${1}"      | cut -d\  -f 4)"
    args["max_path"]="$(grep "LONGEST_PATH" "${1}" | cut -d\  -f 4)"
    args["real_time"]="$(grep "real-time" "${2}"   | cut -d\  -f 3)"
    args["smt2_file"]="${1}"
    args["out_file"]="${2}"

    # status

    is_unknown="$(grep -Eci -m 1 "^(timeout|unknown|# Timeout reached!)$" "${2}")"
    is_unsat="$(grep -Eci -m 1 "(^unsat$|No solution was found)" "${2}")"
    is_sat="$(grep -Eci -m 1 "(^sat$|The maximum value of)" "${2}")"
    (( is_unknown )) && is_sat=$((0)) # optimathsat prints sat for partially optimized problems

    (( ( is_unknown + is_unsat + is_sat ) == 1 )) || \
        { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" "parsed multiple search statuses, see <${2}>"; exit 1; };

    (( is_unknown )) && args["status"]="unknown"
    (( is_unsat ))   && args["status"]="unsat"
    (( is_sat ))     && args["status"]="sat"

    args["timeout"]=$((is_unknown))

    # opt value + solver

    if (( (is_unknown + is_unsat) >= 1 )) ; then
        args["opt_value"]="${args["max_path"]}"
    else
        if grep -q "# Optimum:" "${2}"; then
            args["opt_value"]="$(grep "Optimum" "${2}"           | cut -d\  -f 3)"
            solver="optimathsat"
        elif grep -q "(objectives" "${2}"; then
            args["opt_value"]="$(grep "objectives" -A 1 "${2}"   | tail -n 1 | cut -d\  -f 3 | sed 's/)//')"
            solver="z3"
        elif grep -q "maximum value of " "${2}"; then
            args["opt_value"]="$(grep "maximum value of " "${2}" | cut -d\  -f 7)"
            solver="smtopt"
        else
            error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" "nothing to parse" && exit "${?}"
        fi
    fi

    # error

    num_errors="$(awk '{ s=tolower($0) } s~/error/ && s!~/# error/ { count++ } END { print count }' "${2}")"
    args["errors"]=$((num_errors))

    args["gain"]=$(awk -v MAX="${args["max_path"]}" -v OPT="${args["opt_value"]}" \
        "BEGIN {printf \"%.2f\", ((MAX - OPT) * 100 / MAX)}")

    wcet_parse_output="$(wcet_print_data "$(declare -p args)")"
    return 0
}

###
###
###

# wcet_run_experiment:
#   recursively explores a benchmark directory looking for `.c` and `.bc`
#   files, applying to each file a function `wcet_{*}_handler` and storing
#   the result within a similar folder structure in the target directory
#       ${1}        -- full path to the benchmark directory
#       ${2}        -- full path to the statistics directory
#       ${3}        -- if != 0, then attempt unroll of all formulas
#       [...]       -- keywords `{*}`, where `{*}` is the id
#                      of a handler with name `wcet_{*}_handler`
#
function wcet_run_experiment ()
{
    local file_name= ; local file_ext= ;

    is_directory "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    is_directory "${2}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    set -- "$(realpath "${1}")" "$(realpath "${2}")" "${@:3}"

    find "${2}" -name "*.txt" -type f -delete &>/dev/null

    while read -r file
    do
        file_name="${file%.*}"
        file_ext="${file##*.}"

        [[ "${file}" =~ /.ignore/ ]] && continue;

        # skip `.bc` if original `.c` exists
        [ "${file_ext}" = "bc" ] && [ -f "${file_name}.c" ] && [ -r "${file_name}.c" ] && \
            { continue; }

        # skip generated `.opt.bc` and `.unr.bc` files
        [[ "${file}" =~ .opt.bc$ ]] && continue;
        [[ "${file}" =~ .unr.bc$ ]] && continue;

        for test_conf in "${@:4}"
        do
            local dest_dir= ;
            dest_dir="${2}/${test_conf}"

            wcet_replicate_dirtree "${1}" "${dest_dir}" "${file}" || return "${?}"

            wcet_handle_file "${dest_dir}" "${file}" "${wcet_replicate_dirtree}" "${3}"
        done
    done < <(find "${1}" \( -name "*.c" -o -name "*.bc" \) )
}

# wcet_replicate_dirtree:
#   replicates folder structure used by a benchmark file within
#   the statistics folder
#       ${1}        -- full path to benchmarks directory
#       ${2}        -- full path to statistics directory for a given configuration
#       ${3}        -- full path to the benchmark file
#       return ${wcet_replicate_dirtree}
#                   -- full path to benchmark file under statistics folder tree
#                      stripped of its extension
#
# shellcheck disable=SC2034
function wcet_replicate_dirtree ()
{
    wcet_replicate_dirtree= ;

    local dest_file=

    is_directory "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}"     || return "${?}"
    is_readable_file "${3}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    mkdir -p "${2}" 2>/dev/null || \
        { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "unable to create directory <${2}>" "${?}"; return "${?}"; };

    dest_file="${3/"${1}"/"${2}"}"
    dest_file="${dest_file%.*}"

    mkdir -p "$(dirname "${dest_file}")" 2>/dev/null || \
        { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "unable to replicate folder tree" "${?}"; return "${?}"; };

    stats_file="${2}/$(basename "${2}").txt"
    [ -f "${stats_file}" ] || \
        wcet_print_header > "${stats_file}" || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${stats_file}> can not be created or overwritten" "${?}"; return "${?}"; };

    wcet_replicate_dirtree="${dest_file}"
    return 0
}

# wcet_handle_file:
#   given a `.bc` or `.c` file and a configuration, it runs the associated
#   file handler over the file, and logs the experimental results
#       ${1}        -- full path to statistics directory for a given configuration
#       ${2}        -- full path to the benchmark file
#       ${3}        -- full path to benchmark file under statistics folder tree
#                      stripped of its extension
#       ${4}        -- if != 0, then attempt unroll of all formulas
#       return ${wcet_handle_file}
#                   -- full path to the file in which benchmark data has been logged
#
# shellcheck disable=SC2034
function wcet_handle_file ()
{
    wcet_handle_file= ;

    local func_name= ; local stats_file= ; local stat_max= ;
    local stat_opt=  ; local stat_gain=  ; local stat_ref= ;

    is_readable_file "${2}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    func_name="wcet_$(basename "${1}")_handler"
    type -t "${func_name}" 2>/dev/null 1>&2 || \
        { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${func_name}> is not a function, built-in or command" "${?}"; return "${?}"; };

    # 1. bytecode generation if file is `.c` source code
    if [ "${2##*.}" = "c" ]; then
        wcet_gen_bytecode "${2}" || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "failed to generate bytecode for <${2}>" "${?}"; return "${?}"; };
    else
        wcet_gen_bytecode="${2}"
    fi

    # Optional: attempt to remove loops from code
    if (( ${4} )); then
        wcet_unroll_loops "${wcet_gen_bytecode}" || \
            { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "failed to unroll loops for <${wcet_gen_bytecode}>" "${?}"; return "${?}"; };
        wcet_gen_bytecode="${wcet_unroll_loops}"
    fi

    # 2. generate smt2 + blocks file
    wcet_gen_blocks "${wcet_gen_bytecode}" || \
        { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "failed to generate smt2+blocks for <${wcet_gen_bytecode}>" "${?}"; return "${?}"; };

    # 3. call file handler for specific configuration
    #   - should generate omt formula of the right encoding
    #   - should run the right omt solver
    #   - should save in ${func_name} the formatted string with collected data
    eval "${func_name} \"${wcet_gen_blocks}\" \"${3}\"" || \
        { error "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${func_name}> unexpected error" "${?}"; return "${?}"; };

    # 4. store data
    stats_file="${1}/$(basename "${1}").txt"
    [ -n "${!func_name}" ] || \
        { warning "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "$((LINENO - 1))" "<${func_name}(${1})> empty result"; return 0; };
    echo "${!func_name}" >> "${stats_file}"

    # 5. log test
    stat_max="$(echo "${!func_name}"  | cut -d\| -f 2 | sed 's/ //g')"
    stat_opt="$(echo "${!func_name}"  | cut -d\| -f 3 | sed 's/ //g')"
    stat_gain="$(echo "${!func_name}" | cut -d\| -f 4 | sed 's/ //g')"
    stat_time="$(echo "${!func_name}" | cut -d\| -f 6 | sed 's/ //g')"
    stat_ref="$(basename "${2%.*}")"
    prefix="${BLUE}$(basename "${1%.*}")(${NORMAL}${stat_ref}${BLUE}) ${NORMAL}"
    suffix="-- max: ${RED}${stat_max}${NORMAL}, opt: ${BLUE}${stat_opt}${NORMAL}, gain: ${GREEN}${stat_gain} %${NORMAL}, time: ${BLUE}${stat_time}s${NORMAL}"
    log_str="$(printf "%-80s %s" "${prefix}" "${suffix}")"
    log "${log_str}"

    wcet_handle_file="${stats_file}"
    return 0
}

# wcet_test_handler:
#   a dummy file handler for testing purposes
#
# shellcheck disable=SC2034
function wcet_test_handler()
{
    wcet_test_handler=

    wcet_test_handler="100 | 80 | 20.0 | stuff "
    return 0;
}

# wcet_delete_files:
#   removes any file generated by `wcet_run_experiment` within the benchmark
#   directory
#       ${1}        -- full path to the benchmark directory
#
function wcet_delete_files ()
{
    local file_name= ; local file_ext= ; local errors=$((0))

    is_directory "${1}" "${NAME_WCET_LIB}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    set -- "$(realpath "${1}")"

    while read -r file
    do
        file_name="${file%.*}"
        file_ext="${file##*.}"

        [[ "${file}" =~ /.ignore/ ]] && continue;

        # skip `.bc` if there is no `.c` (unless it is `.opt.bc` or `.unr.bc`)
        [ "${file_ext}" != "bc" ] || [[ "${file}" =~ .opt.bc$ ]] || [[ "${file}" =~ .unr.bc$ ]] \
                                  || [ -f "${file_name}.c" ] || [ -r "${file_name}.c" ] || \
            { continue; }

        rm -v "${file}" || errors=$((errors + 1))
    done < <(find "${1}" \( -name "*.bc" -o -name "*.gen" -o -name "*.ll" -o -name "*.smt2" -o -name "*.smt" -o -name "*.longestsyntactic" -o -name "*.llvmtosmtmatch" \) -type f)

    return $((errors))
}
