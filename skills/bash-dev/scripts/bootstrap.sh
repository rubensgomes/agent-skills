#!/usr/bin/env bash
## SPDX-License-Identifier: MIT
##
## Verifies that the Bash function libraries required by the
## "bash-dev" skill are installed at "${HOME}/lib/sh-lib".
##
## Requirements:
##  1) Bash version 3.2 or higher
##
## Author: Rubens Gomes


#####################################################################
## GLOBAL CONSTANTS #################################################

# shell script program name
declare PRG
PRG="$(
  basename -- "${0}" || {
    printf "failed to determine the program basename." >&2
    exit 1
  }
)"

# folder where the Bash function libraries must be installed
[[ -z "${SH_LIB_DIR:-}" ]] && readonly SH_LIB_DIR="${HOME}/lib/sh-lib"

# library files that must be present in "${SH_LIB_DIR}"
if ! declare -p SH_LIB_FILES >/dev/null 2>&1; then
  readonly -a SH_LIB_FILES=(
    "misc_lib.sh"
    "msg_lib.sh"
    "os_lib.sh"
    "sed_lib.sh"
    "sh_lib.sh"
  )
fi

#####################################################################
## BOOTSTRAP ########################################################

#####################################################################
## Ensures the libraries sourced below are readable. It runs before
## the message library is available, hence the plain "printf" calls.
## Globals:
##  PRG
##  SH_LIB_DIR
##  SH_LIB_FILES
## Arguments:
##  None
## Returns:
##   0 if okay; something else if fails.
#####################################################################
bootstrap_check() {

  if [[ ! -d "${SH_LIB_DIR}" ]]; then
    printf "%s: missing library folder [%s].\n" \
      "${PRG}" "${SH_LIB_DIR}" >&2
    return 1
  fi

  local file
  local -i missing=0

  for file in "${SH_LIB_FILES[@]}"; do

    if [[ ! -f "${SH_LIB_DIR}/${file}" ]]; then
      printf "%s: missing library file [%s].\n" \
        "${PRG}" "${SH_LIB_DIR}/${file}" >&2
      missing+=1
    fi

  done

  (( missing == 0 ))
}

bootstrap_check || exit 1