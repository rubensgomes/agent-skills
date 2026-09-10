#!/usr/bin/env bash
## SPDX-License-Identifier: MIT
##
## This is a sample shell script to serve as a template model for
## agents when generating and modifying bash shell scripts.
##
## Requirements:
##  1) Bash functions libraries installed at "${HOME}/lib/sh-lib".
##  2) GNU bash version 4.2 or higher required by associative arrays.
##  3) curl 8.7.1 or higher.
#   4) getopt from util-linux 2.30.2 or higher.
##  5) jq jq-1.8.2 or higher.
##  6) sha256sum from GNU coreutils 8.22 or higher.
##
## Author: Rubens Gomes
## NOTE:   Initial implementation was generated with AI assistance
##         and subsequently reviewed and approved by the author.


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

# minimum Bash major / minor version required
# shellcheck disable=SC2034
readonly BASH_MAJOR_VERSION="4"
# shellcheck disable=SC2034
readonly BASH_MINOR_VERSION="2"

# Set to TRUE when debuggin code using bassupport-pro.  This is
# required to bypass trap handlers which crashes code when running
# from debugger
readonly IS_DEBUGGER=FALSE

# UNIT_TESTING is set to TRUE when running unit testing.
readonly UNIT_TESTING=FALSE

# temporary folder for this shell script
[[ -z "${TMP_DIR:-}" ]] && readonly TMP_DIR="/tmp/${PRG}"

# extra tools required by this script to run.
[[ -z "${REQUIRED_TOOLS:-}" ]] && readonly -a REQUIRED_TOOLS=(
  "curl"
  "jq"
  "sha256sum"
  "tar"
  "getopt"
  "unzip"
)

#####################################################################
## INCLUDES #########################################################

[[ -d "${HOME}/lib/sh-lib" ]] || {
  printf "missing %s\n" "${HOME}/lib/sh-lib" >&2
  exit 1
}

# -------------------- >>> Import Basic Libraries <<< ---------------

# logging message library
source "${HOME}/lib/sh-lib/msg_lib.sh" || exit

# operating system library
source "${HOME}/lib/sh-lib/os_lib.sh" || exit

# bash library
source "${HOME}/lib/sh-lib/sh_lib.sh" || exit


#####################################################################
## GLOBAL VARIABLES #################################################

# Boolean flag used to run this shell script in "dry" run mode
# (no changes)
declare g_is_dry_run=FALSE

# Boolean flag used to remove temporary files in trap handler
declare g_is_force_delete=FALSE

# URL path to be used for this project
declare g_proj_url=

# The topics to be associated with this project GitHub repository
declare g_topics=


#####################################################################
## FUNCTIONS ########################################################

#####################################################################
## Prints help to stdout.
## Globals:
##  PRG
## Arguments:
##  none.
## Returns:
##   0 always
#####################################################################
help() {
  cat <<EOF

"${PRG}" is used to (use header short description).

Usage:
  ${PRG} -t <topics> [options]

General Non Argument Options:

  -d, --debug                  prints debug messages
  -h, --help                   prints this help
  -q, --quiet                  prints only error|fatal messages
  -n, --dry-run                inspects only, does NOT deploy
  -v, --verbose                adds extra details to messages
  -x, --trace                  traces commands

Argument Options:

  -t, --topics <topics>        comma separated list of  topics
  -u, --proj-url <proj_url>    URL of this project on the internet

topics (**required**):
  The different topics to be associate with the project GitHub
  repository.

proj_url:
  The public URL to get to this project page on the Internet

EOF
}

#####################################################################
## Prints usage to stderr.
## Globals:
##  PRG
## Arguments:
##  none.
## Exits:
##   2 always
#####################################################################
usage() {
  cat <<EOF
Usage:  ${PRG} [options]
More information with: "${PRG} -h"
EOF

  # return an error status
  return 2
} >&2

#####################################################################
## Initializes global variables to their initial state. That is,
## reset them.
## Globals:
##  g_is_dry_run
##  g_is_force_delete
##  g_proj_url
##  g_topics
## Arguments:
##  None
#  Returns:
##   0 if okay; something else if fails.
#####################################################################
reset_globals() {
  g_topics=
  g_proj_url=
  g_is_dry_run=FALSE
  g_is_force_delete=FALSE
}

#####################################################################
## Parses user's command line input option arguments.
## Globals:
##  g_is_dry_run
##  g_is_force_delete
##  g_proj_url
##  g_topics
## Arguments:
##  Bash shell CLI input arguments.
#  Returns:
##   0 if okay; something else if fails.
#####################################################################
parse_options() {

  # reset globals so that I can call this function multiple times
  # from within same unit test function stack frame, and not have
  # previous global values impact the next tests within the same
  # stack function frame.
  reset_globals

  local temp

  if ! temp=$(
    getopt \
      --o 'dhnqvxt:u:' \
      --long 'debug,dry-run,help,quiet,\
proj-url:,topics:,trace,verbose'\
      --name "${PRG}" \
      -- "${@}"
  ); then
    msg::error "failed to parse CLI inpuit arguments."
    usage
    return 2
  fi

  eval set -- "${temp}"
  local quiet=FALSE

  while true; do

    case "${1}" in

      ########## --debug ############################################
      '-d' | '--debug')
        if [[ "${quiet}" == TRUE ]]; then
          msg::warn "-q option has been passed, and it overrides -d"
        else
          msg::enable_debug
        fi
        shift
        continue
        ;;

      ########## --help #############################################
      '-h' | '--help')
        deploy::help
        exit 0
        ;;

      ########## --dryrun ###########################################
      '-n' | '--dry-run')
        g_is_dry_run=TRUE
        shift
        continue
        ;;

      ########## --quiet ############################################
      '-q' | '--quiet')
        quiet=TRUE
        msg::enable_quiet
        shift
        continue
        ;;

      ########## --topics  ##########################################
      '-t' | '--topics')
        if [[ -z "${2:-}" || -z "${2//[[:space:]]/}" ]]; then
          msg::error "topics is missing or blank."
          deploy::usage
          return 2
        fi
        g_topics="$(sh::trim_space "${2}")" || return
        msg::debug "topics=%s\n" "${g_topics}"
        shift 2
        continue
        ;;

      ########## --proj-url #########################################
      '-u' | '--proj-url')
        if [[ -z "${2:-}" || -z "${2//[[:space:]]/}" ]]; then
          msg::error "proj_url is missing or blank."
          usage
          return 2
        fi
        local tmp_url=
        tmp_url="$(sh::trim_space "${2}")" || return
        sh::is_valid_url "${tmp_url}" || return
        g_proj_url="${tmp_url}"
        msg::debug "proj_url=%s\n" "${g_proj_url}"
        shift 2
        continue
        ;;

      ########## --verbose ##########################################
      '-v' | '--verbose')
        msg::enable_verbose
        shift
        continue
        ;;

      ########## --trace ############################################
      '-x' | '--trace')
        msg::enable_tracing
        shift
        continue
        ;;

      ########## -- #################################################
      '--')
        shift
        break
        ;;

      ########## * ##################################################
      *)
        msg::arg_error "invalid option [%s].\n" "${1}"
        usage
        return 2
        ;;

    esac
  done

  # ensure mandatory CLI option "-t, --topics" was provided by the
  # user.
  if [[ -z "${g_topics:-}" ]]; then
    msg::error "missing [%s] CLI option argument.\n" \
    "--topics <topics>"
    return 2
  fi

  msg::debug "%s completed successfully.\n" "${FUNCNAME[0]}"
}

#####################################################################
## Checks required tool.
## Globals:
##  REQUIRED_TOOLS
## Arguments:
##  None
## Returns:
##   0 if okay, somethine else if fails.
#####################################################################
check_required_tool() {
  msg::debug "entering %s:%s\n" "${FUNCNAME[0]}" "${LINENO}"

  local tool
  for tool in "${REQUIRED_TOOLS[@]}"; do

    if ! os::is_installed "${tool}"; then
      msg::warn "Missing a required tool [%s].\n" "${tool}"
      return 127
    fi

  done

}

#####################################################################
## Catches and handles signals defined in the "trap" command. Any
## cleanup necessary can go inside this function.
## Globals:
##  FUNCNAME
##  LINENO
##  TMP_DIR
##  FUNCNAME : Bash array for function names in the stack.
##  ERR  : trap any non-zero exit status
##  EXIT : trap sigspec for signal   (0) On exit from shell
##  HUP  : trap sigspec for SIGHUP   (1) Clean tidyup
##  INT  : trap sigspec for SIGINT   (2) Interrupt (CTRL-C)
##  QUIT : trap sigspec for SIGQUIT  (3) Quit
##  TERM : trap sigspec for SIGTERM (15) Terminate
##  g_is_force_delete
## Arguments:
##  None.
## Exits:
##   exit status code based on signal being handled.
#####################################################################
signal_handler() {
  msg::debug "entering %s:%s\n" "${FUNCNAME[0]}" "${LINENO}"

  local -r signal="${1:-}"
  msg::debug "handling signal [%s].\n" "${signal}"

  # disables following signals to avoid loooping
  trap - ERR
  trap - EXIT
  trap - HUP  # signal 1
  trap - INT  # signal 2
  trap - QUIT # signal 3
  trap - TERM # signal 15

  local exit_code

  case "${signal}" in
    HUP)
      msg::warn \
        "the shell controlling terminal was hang up: %s\n" \
       "SIGHUP"
      exit_code=129 # 1+128
      ;;
    INT)
      msg::warn \
        "execution interrupted by the user (control-c): %s\n" \
        "SIGINT"
      exit_code=130 # 2+128
      ;;
    QUIT)
      msg::warn \
        "execution interrupted due to unexpected event: %s\n" \
        "SIGQUIT"
      exit_code=131 # 3+128
      ;;
    TERM)
      msg::warn "someone asked the current execution to stop: %s\n" \
        "SIGTERM"
      exit_code=130
      ;;
    ERR)
      msg::warn "execution interrupted by Bash ERR signal: %s\n" \
        "SIGERR"
      ;;
    EXIT)
      msg::debug "handling %s event\n" "SIGEXIT"
      ;;
    *)
      msg::warn "unexpected signal: %s\n" "${signal}"
      ;;
  esac

  msg::debug "attempting to delete tmp files at [%s].\n" "${TMP_DIR}"
  local folder
  folder="${TMP_DIR}"

  if [[ -d "${folder}" ]]; then
    local is_rm_local=FALSE

    # shellcheck disable=SC2154
    if [[ "${g_is_force_delete}" == TRUE ]]; then
      is_rm_local=TRUE
    else
      # logging or other display message should go to stderr because
      # the dtdout is reserved to pass data between functions.
      printf "\nWARNING! This will remove folder:\n%s\n" \
        "${folder}" >&2
      msg::yes_no && is_rm_local=TRUE
    fi

    if [[ "${is_rm_local}" == TRUE ]]; then
      msg::debug "removing tmp folder [%s].\n" "${folder}"
      #rm -fr "${folder}"
      # for sanity I want to use -i for now
      rm -ri "${folder}"
    fi

  fi

  if [[ -n "${exit_code:-}" ]]; then
    exit ${exit_code}
  fi

  exit
}

#####################################################################
## Main function.
## Globals:
##  IS_DEBUGGER
##  PRG
##  REQUIRED_TOOLS
##  TMP_DIR
##  g_is_dry_run
##  g_is_force_delete
##  g_proj_url
##  g_topics
## Arguments:
##  Bash shell CLI input arguments.
## Returns:
##   0 if okay; something else if fails.
#####################################################################
main() {
  # sanity: start main function stack with a clean global state.
  reset_globals

  # --------------- >>> Check Required Tools <<< --------------------

  check_required_tool || return

  # --------------- >>> Parse CLI Input Arguments <<< ---------------

  parse_options "${@:-}" || return

  msg::debug "Bash version: %s\n" "${BASH_VERSION}"
  msg::info "Running %s\n" "${PRG}"

  # --------------- >>>  Basic Shell Init / Trap Handlers <<< -------

  # bassupport-pro debugger crashes if following code is run
  if [[ "${IS_DEBUGGER}" != TRUE ]]; then
    sh::init || return
    local -ar signals=("ERR" "HUP" "INT" "TERM" "QUIT" "EXIT")
    sh::curry_trap_command "signal_handler" "${signals[*]}" || return
  fi

  # --------------- >>> Print Script State  <<<  --------------------

  msg::debug "[%s]: %s\n" "IS_DEBUGGER" "${IS_DEBUGGER}"
  msg::debug "[%s]: %s\n" "PRG" "${PRG}"
  msg::debug "[%s]: %s\n" "TMP_DIR" "${TMP_DIR}"
  msg::debug "[%s]: %s\n" "g_is_dry_run" "${g_is_dry_run}"
  msg::debug "[%s]: %s\n" "g_is_force_delete" "${g_is_force_delete}"
  msg::debug "[%s]: %s\n" "g_proj_url" "${g_proj_url}"
  msg::debug "[%s]: %s\n" "g_topics" "${g_topics}"

  # --------------- >>> Is this a Dry Run Only  <<< -----------------

  if [[ "${g_is_dry_run}" != TRUE ]]; then
    # !!! ONLY RUN THE FOLLOWING IF THIS IS NOT A DRY RUN !!!
    msg::debug "I am running real code that can change the state.\n"
  else
    msg::debug "I am running in dry-run mode.\n"
  fi

}

#####################################################################
## ------------------------------------------------------------------
## -------------------- >>> Main Program Body <<< -------------------
## ------------------------------------------------------------------

# UNIT_TESTING is set to TRUE when running with (-t option argument)
# or during unit testing. simply return when this program is being
# sourced by a unit test framework
[[ "${UNIT_TESTING:-}" == TRUE ]] && \
  printf "Runing unit tests.\n" && \
  return 0

if ! main "${@:-}"; then
  printf "\n%s failed!\n" "${PRG}" >&2
  exit 1
fi

printf "done\n"
