#!/bin/bash

###
### GLOBALS
###

LOC_GENERIC_LIB="$(realpath "$(dirname "${BASH_SOURCE[0]}" )" )"

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
    echo -e -n "[error]   $(basename "${0}"): " 1>&2
    [ -n "${1}" ] && echo -e -n "${1}: " 1>&2
    [ -n "${2}" ] && echo -e -n "row ${2}: " 1>&2
    [ -n "${3}" ] && echo -e -n "\n[error]       ${3}. " 1>&2
    [ -n "${4}" ] && echo -e -n "(exit code: ${4})" 1>&2
    echo -e    "${NORMAL}"
    [ -n "${4}" ] && return "${4}" || return 1
}

function warning()
{
    (( 0 == VERBOSE_WARNINGS )) && return 1
    echo -e -n "${YELLOW}"
    echo -e -n "[warning] $(basename "${0}"): " 1>&2
    [ -n "${1}" ] && echo -e -n "${1}: " 1>&2
    [ -n "${2}" ] && echo -e -n "row ${2}: " 1>&2
    [ -n "${3}" ] && echo -e -n "\n[warning]     ${3}." 1>&2
    echo -e    "${NORMAL}"
    return 0
}

function log_cmd()
{
    (( 0 == VERBOSE_COMMANDS )) && return 1
    echo -e "${GREEN}[log]  ~\$${NORMAL} ${1}"
    return 0
}

function log()
{
    (( 0 == VERBOSE_WORKFLOW )) && return 1
    echo -e "${BLUE}[log]  <<${NORMAL} ${1}"
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
