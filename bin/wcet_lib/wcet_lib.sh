#!/bin/bash

###
### GLOBALS
###

LOC_WCET_LIB="$(realpath "$(dirname "${BASH_SOURCE[0]}" )" )"

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

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [[ "${1}" =~ .c$ ]] && dst_file="${1:: -2}.bc" || dst_file="${1}.bc"

    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        log_cmd "clang -emit-llvm -c \"${1}\" -o \"${dst_file}\""
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
#                   -- full path to optimized file (ext: `.opt.bc`)
#
# shellcheck disable=SC2034
function wcet_bytecode_optimization()
{
    wcet_bytecode_optimization=
    local dst_file= ; local errmsg= ;

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
    [[ "${1}" =~ .bc$ ]] && dst_file="${1:: -3}.opt.ll" || dst_file="${1}.opt.ll"


    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        log_cmd "pagai -i \"${1}\" --dump-ll --wcet --loop-unroll > \"${dst_file}\""
        pagai -i "${1}" --dump-ll --wcet --loop-unroll > "${dst_file}" || \
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "pagai error" "${?}"; return "${?}"; };

        # pagai does not set error status
        errmsg="$(head -n 1 "${dst_file}" | grep "ERROR" | cut -d\  -f 2-)"
        if [ -n "${errmsg}" ]; then
            error "${FUNCNAME[0]}" "$((LINENO - 6))" "${errmsg:: -1}"; return "${?}";
        fi
    fi

    src_file="${dst_file}"
    dst_file="${dst_file::-3}.bc"
    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        log_cmd "llvm-as -o \"${dst_file}\" \"${src_file}\""
        llvm-as -o "${src_file}" "${dst_file}" || \
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

    if (( 0 == SKIP_EXISTING )) || test ! \( -f "${dst_file}" -a -r "${dst_file}" \) ; then
        log_cmd "pagai -i \"${1}\" -s \"${solver}\" --wcet --printformula --skipnonlinear --loop-unroll > \"${dst_file}\""
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

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"
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

    if (( SKIP_EXISTING <= 1 )) || test ! \( -f "${2}" -a -r "${2}" \) ; then
        log_cmd "optimathsat ${*:3} < \"${1}\" > \"${2}\" 2>&1"

        /usr/bin/time -f "# real-time: %e" optimathsat "${@:3}" < "${1}" > "${2}" 2>&1 ||
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "optimathsat error, see <${2}>" "${?}"; return "${?}"; };
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

    if (( SKIP_EXISTING <= 1 )) || test ! \( -f "${2}" -a -r "${2}" \) ; then
        log_cmd "z3 ${*:3} \"${1}\" > \"${2}\" 2>&1"

        sed 's/\((set-option :timeout [0-9][0-9]*\).0)/\1000.0)/;s/\((maximize .*\) \(:.* :.*)\)/\1)/' "${1}" | \
            /usr/bin/time -f "# real-time: %e" z3 -in -smt2 "${@:3}" > "${2}" 2>&1 ||
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "z3 error, see <${2}>" "${?}"; return "${?}"; };
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
    local bc_file= ; local is_unknown=  ; local is_unsat= ; local is_sat= ;
    local solver=  ; local has_timeout= ;
    declare -A args

    is_readable_file "${1}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}" # smt2 formula
    is_readable_file "${2}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}" # optimathsat/z3 output

    bc_file="${1/\.[0-9]*\.smt2/}.bc"
    [ -f "${bc_file}" ] && [ -r "${bc_file}" ] || bc_file="${1/\.[0-9]?(\.cuts)\.smt2/}"
    is_readable_file "${bc_file}" "${FUNCNAME[0]}" "${LINENO}" || return "${?}"

    args["llvm_size"]="$(llvm-dis -o - "${bc_file}"          | wc -l)"
    args["num_blocks"]="$(grep -c "declare-fun b_" "${1}" )"
    args["num_cuts"]="$(grep "NB_CUTS" "${1}"      | cut -d\  -f 4)"
    args["max_path"]="$(grep "LONGEST_PATH" "${1}" | cut -d\  -f 4)"
    args["real_time"]="$(grep "real-time" "${2}"   | cut -d\  -f 3)"
    args["smt2_file"]="${1}"
    args["out_file"]="${2}"

    # opt value + solver

    if grep -q "# Optimum:" "${2}"; then
        args["opt_value"]="$(grep "Optimum" "${2}"         | cut -d\  -f 3)"
        solver="optimathsat"
    elif grep -q "(objectives" "${2}"; then
        args["opt_value"]="$(grep "objectives" -A 1 "${2}" | tail -n 1 | cut -d\  -f 3 | sed 's/)//')"
        solver="z3"
    else
        error "${FUNCNAME[0]}" "${LINENO}" "nothing to parse" && exit "${?}"
    fi

    # status

    is_unknown="$(grep -ci "^unknown$" "${2}")"
    is_unsat="$(grep -ci "^unsat$" "${2}")"
    is_sat="$(grep -ci "^sat$" "${2}")"

    (( ( is_unknown + is_unsat + is_sat ) == 1 )) || \
        { error "${FUNCNAME[0]}" "${LINENO}" "parsed multiple search statuses, see <${2}>"; exit 1; };

    (( is_unknown )) && args["status"]="unknown"
    (( is_unsat ))   && args["status"]="unsat"
    (( is_sat ))     && args["status"]="sat"

    # timeout

    [[ "${solver}" =~ ^optimathsat$ ]] && has_timeout="$(grep -ci "Timeout reached" "${2}")"
    [[ "${solver}" =~ ^z3$ ]]          && has_timeout=$((is_unknown))
    args["timeout"]=$((has_timeout))

    if (( (has_timeout + is_unsat) >= 1 )) ; then   # discard any partial result
        args["opt_value"]="${args["max_path"]}"
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
#       [...]       -- keywords `{*}`, where `{*}` is the id
#                      of a handler with name `wcet_{*}_handler`
#
# shellcheck disable=SC2030
function wcet_run_experiment ()
{
    local file_name= ; local file_ext= ;

    is_directory "${1}" || return "${?}"
    is_directory "${2}" || return "${?}"

    set -- "$(realpath "${1}")" "$(realpath "${2}")" "${@:3}"

    find "${1}" \( -name "*.c" -o -name "*.bc" \) -print0 | \
    while read -r -d $'\0' file
    do
        file_name="${file%.*}"
        file_ext="${file##*.}"

        # skip `.bc` if original `.c` exists
        [ "${file_ext}" = "bc" ] && [ -f "${file_name}.c" ] && [ -r "${file_name}.c" ] && \
            { continue; }

        for test_conf in "${@:3}"
        do
            local dest_dir= ;
            dest_dir="${2}/${test_conf}"

            wcet_replicate_dirtree "${1}" "${dest_dir}" "${file}" || return "${?}"

            wcet_handle_file "${dest_dir}" "${file}" "${wcet_replicate_dirtree}"
        done
    done
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

    is_directory "${1}"     || return "${?}"
    is_readable_file "${3}" || return "${?}"

    mkdir -p "${2}" 2>/dev/null || \
        { error "${FUNCNAME[0]}" "$((LINENO - 1))" "unable to create directory <${2}>" "${?}"; return "${?}"; };

    dest_file="${3/"${1}"/"${2}"}"
    dest_file="${dest_file%.*}"

    mkdir -p "$(dirname "${dest_file}")" 2>/dev/null || \
        { error "${FUNCNAME[0]}" "$((LINENO - 1))" "unable to replicate folder tree" "${?}"; return "${?}"; };

    stats_file="${2}/$(basename "${2}").log"
    echo -n "" > "${stats_file}" || \
        { error "${FUNCNAME[0]}" "$((LINENO - 1))" "<${stats_file}> can not be created or overwritten" "${?}"; return "${?}"; };

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
#       return ${wcet_handle_file}
#                   -- full path to the file in which benchmark data has been logged
#
# shellcheck disable=SC2034
function wcet_handle_file ()
{
    wcet_handle_file= ;

    local func_name= ; local stats_file= ; local stat_max= ;
    local stat_opt=  ; local stat_gain=  ; local stat_ref= ;

    is_readable_file "${2}" || return "${?}"

    func_name="wcet_$(basename "${1}")_handler"
    type -t "${func_name}" 2>/dev/null 1>&2 || { error "${FUNCNAME[0]}" "$((LINENO - 1))" "<${func_name}> is not a function, built-in or command" "${?}"; return "${?}"; };

    # 1. bytecode generation if file is `.c` source code
    if [ "${2##*.}" = "c" ]; then
        wcet_gen_bytecode "${2}" || \
            { error "${FUNCNAME[0]}" "$((LINENO - 1))" "failed to generate bytecode for <${2}>" "${?}"; return "${?}"; };
    else
        wcet_gen_bytecode="${2}"
    fi

    # 2. generate smt2 + blocks file
    wcet_gen_blocks "${wcet_gen_bytecode}" || \
        { error "${FUNCNAME[0]}" "$((LINENO - 1))" "failed to generate smt2+blocks for <${wcet_gen_bytecode}>" "${?}"; return "${?}"; };

    # 3. call file handler for specific configuration
    #   - should generate omt formula of the right encoding
    #   - should run the right omt solver
    #   - should save in ${func_name} the formatted string with collected data
    eval "${func_name} \"${wcet_gen_blocks}\" \"${3}\"" || \
        { error "${FUNCNAME[0]}" "$((LINENO - 1))" "<${func_name}> unexpected error" "${?}"; return "${?}"; };

    # 4. store data
    stats_file="${1}/$(basename "${1}").log"
    [ -n "${!func_name}" ] || \
        { warning "${FUNCNAME[0]}" "$((LINENO - 1))" "<${func_name}(${1})> empty result"; return 0; };
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
