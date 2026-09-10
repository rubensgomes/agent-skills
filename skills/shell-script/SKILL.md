---
name: shell-script
description: >-
  A set of guidelines to use when working on shell scripting.
---

## Overview

These guidelines are to be used in shell scripting code.

## Instructions

1. **Shebang**: Always start with `#!/usr/bin/env bash`. Never use `#!/bin/bash`
   to ensure maximum system portability.
2. **Strict Mode**: Immediately follow the shebang with `set -euo pipefail`.
3. **Global Constants**: Define paths, tools, and immutable configurations at
   the top using `readonly` or `declare -r`.
4. **Cleanup Trap**: If the script creates temporary files or resources, always
   implement a cleanup function and bind it using `trap cleanup EXIT INT TERM`.
5. **Main Function**: Wrap the core execution logic in a `main()` function and
   call it at the very bottom with `main "$@"`.
6. **File Header**: Use the following example as a guideline when adding
   file header:

  ```text
  #!/usr/bin/env bash
  # SPDX-License-Identifier: MIT
  #
  # A single line statement of what this shell script does.
  #
  # Author: Rubens Gomes
  # NOTE:   Initial implementation of this shell script may have been
  #         generated with AI assistance and subsequently reviewed and
  #         approved by the author.
  ```

7. Limit all shell script comments and code to a maximum of 80 characters per
   line.

## Code Style & Formatting

- **Line Length**: Limit each line of code to a maximum of 70 characters.
- **Indentation**: Use 2 spaces per indent level. Do not use tabs.
- **Variables**: Always wrap variable expansions in double quotes (e.g.,
  `"${var}"`) to prevent word splitting and globbing, unless explicitly
  intentional.
- **Variable Braces**: Always wrap your variables in curly braces (${variable})
  when using them, rather than just using a dollar sign ($variable).
- **Command Substitution**: Always use `$(command)` instead of backticks
  `` `command` ``.
- **Quoting**: Always quote strings containing variables, paths, or filenames to
  prevent bugs with blank spaces.
- **Test Brackets**: Use double brackets ([[ ... ]]) instead of single brackets
  ([ ... ]) for conditional checks because they are safer and handle empty
  values better.
- **Functions**: Do not use the `function` keyword when defining a function.
  Instead, use the POSIX form only (e.g., `my_func() {...}`)
- **Local Variables**: Inside a function, always declare your variables using
  the local keyword so they don't break things outside that function.
- **Built-ins**: Use `printf` instead of `echo` for more reliable and
  predictable text printing.
- **Pipelines**: If a command pipe is long, split it onto multiple lines with
  the pipe character (|) at the start of the next line. For example:

    ```text
    # All fits on one line
    command1 | command2
    
    # Long commands
    command1 \
      | command2 \
      | command3 \
      | command4
    ```

- **Control Flow**: Put `; then` and `; do` on the same line as the `if`, `for`,
  or `while`. Also, add a blank line before and after control flow statements.
  For example:

    ```text
    # If inside a function remember to declare the loop variable as
    # a local to avoid it leaking into the global environment:
    local dir
    
    for dir in "${dirs_to_cleanup[@]}"; do
    
      if [[ -d "${dir}/${SESSION_ID}" ]]; then
        log_date "Cleaning up old files in ${dir}/${SESSION_ID}"
        rm "${dir}/${SESSION_ID}/"* || error_message
      else
        mkdir -p "${dir}/${SESSION_ID}" || error_message
      fi
    
    done
    ```

## Function Requirements

- **Usage**: Always add a `usage` function to the shell script file. For
  example:

  ```text
  #####################################################################
  # Prints the usage text.
  # Globals:
  #   BACKUP_DIR_NAME
  #   PROGRAM_NAME
  # Arguments:
  #   None
  # Outputs:
  #   Usage text to STDOUT. Error paths redirect it to STDERR.
  #####################################################################
  function usage() {
    cat <<EOF
  Synchronize a source skills directory into the Claude Code skills
  directory.
  
  Usage:
    ${PROGRAM_NAME} --source <dir> [--dest <dir>] [--dry-run] [--verbose]
    ${PROGRAM_NAME} --help
  
  Options:
    -s, --source <dir>  Source skills directory to sync from (required).
    -d, --dest <dir>    Destination directory
                        (default: ${DEFAULT_DEST_DIR}).
    -n, --dry-run       Report actions without changing the filesystem.
    -v, --verbose       Print per-file progress.
    -h, --help          Print this help text and exit.
  
  Files present in the destination but absent from the source are moved to
  <dest>/${BACKUP_DIR_NAME}/ rather than deleted.
  EOF
  }
  ```

- **Logging**: Always have a logging functions for information ane error
  messages added to the shell script file.

## Naming Convention

- **Function Names**: Use lowercase with underscores (e.g.,
  `my_awesome_function()`).
- **Variable Names**: Use lowercase with underscores for standard variables (e.
  g., file_path).
- **Constants**: Use ALL CAPS with underscores for constants defined at the top
  of the file (e.g., READONLY_PATH="/var/log"). Ensure that

## Defensive Programming Guidelines

- **Dependency Checks**: Before executing external commands that are not core
  utilities, check if they exist using `command -v tool_name >/dev/null 2>&1`
  and exit with an error message if missing.
- **Logging**: Use a dedicated `log()` or `error()` function that includes
  standard formatting (e.g., `[TIMESTAMP] [LEVEL] Message`) and redirects errors
  to `>&2`.
- **File System Operations**: Always check if directories exist before writing
  to them (`[[ -d "$dir" ]]`). Always check if files exist before reading them
  (`[[ -f "$file" ]]`).

## Code Verification

- **Linter**: All code generated must strictly pass **ShellCheck** static
  analysis validation.

## Example Output Template

When asked to write a complete script, use the template below as a guideline.

```bash
#!/usr/bin/env bash
## SPDX-License-Identifier: MIT
##
## Short description of the script's purpose
##
## Requirements:
##  1) GNU bash, version 4.2 or higher. Required by associative arrays or maps.
##
## Author: Rubens Gomes
## NOTE:   Initial implementation was generated with AI assistance and
##         subsequently reviewed and approved by the author.

################################################################################
## GLOBAL CONSTANTS ############################################################

# shell script program name
readonly PRG="$(basename -- "${0}")"

# minimum Bash major / minor version required
readonly BASH_MAJOR_VERSION="4"
readonly BASH_MINOR_VERSION="2"

# Set to TRUE when debuggin code using bassupport-pro.  This is required
# to bypass trap handlers which crashes code when running from debugger 
readonly IS_DEBUGGER=FALSE

# UNIT_TESTING is set to TRUE when running unit testing.
readonly UNIT_TESTING=FALSE

# temporary folder for this shell script
[[ -z "${TMP_DIR:-}" ]] && readonly TMP_DIR="/tmp/${PRG}"

###############################################################################
## INCLUDES ###################################################################

[[ ! -d "${HOME}/lib/sh-lib" ]] || {
  printf "missing %s\n" "${HOME}/lib/sh-lib" >&2
  exit 1 
}

# -------------------- >>> Import Basic Libraries <<< -------------------------

# logging message library
source "${HOME}/lib/sh-lib/msg_lib.sh" || exit

# operating system library
source "${HOME}/lib/sh-lib/os_lib.sh" || exit

# bash library
source "${HOME}/lib/sh-lib/sh_lib.sh" || exit

################################################################################
## GLOBAL VARIABLES ############################################################

# Boolean flag used to run this shell script in "dry" run mode (no changes)
declare g_is_dry_run=FALSE

# Boolean flag used to remove temporary files in trap handler
declare g_is_force_delete=FALSE

# URL path to be used for this project
declare g_proj_url_path=

# The topics to be associated with this project GitHub repository
declare g_topics=


################################################################################
## FUNCTIONS ###################################################################

################################################################################
## Prints help to stdout.
## Globals:
##  PRG
## Arguments:
##  none.
## Returns:
##   0 always
################################################################################
help() {
  cat <<EOF

"${PRG}" is used to (use header short description).

Usage:
  ${PRG} [options]

General Options:

  -d, --debug                             prints debug messages
  -h, --help                              prints this help
  -q, --quiet                             prints only error|fatal messages
  -n, --dry-run                           inspects only, does NOT deploy
  -v, --verbose                           adds extra details to messages
  -x, --trace                             traces commands

Specific Options:
 
  -t, --topics <topics>                   comma separated list of topics
  -u, --proj-url <proj_url>               URL of this project on the internet

topics:
  The different topics to be associate with the project GitHub repository.

proj_url:
  The public URL to get to this project page on the Internet

EOF
}

################################################################################
## Prints usage to stderr.
## Globals:
##  PRG
## Arguments:
##  none.
## Exits:
##   2 always
################################################################################
usage() {
  cat <<EOF
Usage:  ${PRG} [options]
More information with: "${PRG} -h"
EOF

  # return an error status
  return 2
} >&2

################################################################################
## Initializes global variables to their initial state. That is, reset them.
## Globals:
##  g_is_dry_run
##  g_is_force_delete
##  g_proj_url
##  g_topics
## Arguments:
##  None
#  Returns:
##   0 if okay; something else if fails.
################################################################################
reset_globals() {
  g_topics=
  g_proj_url=
  g_is_dry_run=FALSE
  g_is_force_delete=FALSE
}

################################################################################
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
################################################################################
parse_options() {

  # reset globals so that I can call this function multiple times from within
  # same unit test function stack frame, and not have previous global values
  # impact the next tests within the same stack function frame.
  reset_globals

  local temp

  if ! temp=$(
    getopt \
      --o 'dhnqvxt:u:' \
      --long 'debug,dry-run,help,quiet,proj-url:,topics:,trace,verbose'\
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

      ########## --debug #######################################################
      '-d' | '--debug')
        if [[ "${quiet}" == TRUE ]]; then
          msg::warn "-q option has been passed, and it overrides -d"
        else
          msg::enable_debug
        fi
        shift
        continue
        ;;

      ########## --help ########################################################
      '-h' | '--help')
        deploy::help
        exit 0
        ;;

      ########## --dryrun ######################################################
      '-n' | '--dry-run')
        g_is_dry_run=TRUE
        shift
        continue
        ;;

      ########## --quiet #######################################################
      '-q' | '--quiet')
        quiet=TRUE
        msg::enable_quiet
        shift
        continue
        ;;

      ########## --topics  ####################################################
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

      ########## --proj-url ###################################################
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

      ########## --verbose #####################################################
      '-v' | '--verbose')
        msg::enable_verbose
        shift
        continue
        ;;

      ########## --trace #######################################################
      '-x' | '--trace')
        msg::enable_tracing
        shift
        continue
        ;;

      ########## -- ############################################################
      '--')
        shift
        break
        ;;

      ########## * #############################################################
      *)
        msg::arg_error "invalid option [%s].\n" "${1}"
        usage
        return 2
        ;;

    esac
  done

  msg::debug "%s completed successfully.\n" "${FUNCNAME[0]}"
}

################################################################################
## Catches and handles signals defined in the "trap" command. Any cleanup
## necessary can go inside this function.
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
################################################################################
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
      msg::warn "the shell controlling terminal was hang up: %s\n" "SIGHUP"
      exit_code=129 # 1+128
      ;;
    INT)
      msg::warn "current execution interrupted by the user (control-c): %s\n" \
        "SIGINT"
      exit_code=130 # 2+128
      ;;
    QUIT)
      msg::warn "current execution interrupted due to unexpected event: %s\n" \
        "SIGQUIT"
      exit_code=131 # 3+128
      ;;
    TERM)
      msg::warn "someone asked the current execution to stop: %s\n" "SIGTERM"
      exit_code=130
      ;;
    ERR)
      msg::warn "execution interrupted by Bash ERR signal: %s\n" "SIGERR"
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
      # logging or other display message should go to stderr because the
      # dtdout is reserved to pass data between functions.
      printf "\nWARNING! This will remove folder:\n%s\n" "${folder}" >&2
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

################################################################################
## Main function.
## Globals:
##  IS_DEBUGGER
##  PRG
##  TMP_DIR
##  g_is_dry_run
##  g_is_force_delete
##  g_proj_url
##  g_topics
## Arguments:
##  Bash shell CLI input arguments.
## Returns:
##   0 if okay; something else if fails.
################################################################################
main() {
  # sanity: start main function stack with a clean global state.
  reset_globals

  # --------------- >>> Parse CLI Input Arguments <<< --------------------------

  parse_options "${@:-}" || return

  msg::debug "Bash version: %s\n" "${BASH_VERSION}"
  msg::info "Running %s\n" "${PRG}"

  # --------------- >>>  Basic Shell Init / Trap Handlers <<< -----------------

  # bassupport-pro debugger crashes if following code is run
  if [[ "${IS_DEBUGGER}" != TRUE ]]; then
    sh::init || return
    local -ar signals=("ERR" "HUP" "INT" "TERM" "QUIT" "EXIT")
    sh::curry_trap_command "signal_handler" "${signals[*]}" || return
  fi

  # --------------- >>> Print Script State  <<<  ------------------------------

  msg::debug "[%s]: %s\n" "IS_DEBUGGER" "${IS_DEBUGGER}"
  msg::debug "[%s]: %s\n" "PRG" "${PRG}"
  msg::debug "[%s]: %s\n" "TMP_DIR" "${TMP_DIR}"
  msg::debug "[%s]: %s\n" "g_is_dry_run" "${g_is_dry_run}"
  msg::debug "[%s]: %s\n" "g_is_force_delete" "${g_is_force_delete}"
  msg::debug "[%s]: %s\n" "g_proj_url" "${g_proj_url}"
  msg::debug "[%s]: %s\n" "g_topics" "${g_topics}"

  # --------------- >>> Is this a Dry Run Only  <<< ----------------------------

  if [[ "${g_is_dry_run}" != TRUE ]]; then
    # !!! ONLY RUN THE FOLLOWING IF THIS IS NOT A DRY RUN !!!
    msg::debug "I am running real code that can change the state.\n" 
  else
    msg::debug "I am running in dry-run mode.\n"
  fi

}

################################################################################
## -----------------------------------------------------------------------------
## -------------------- >>> Main Program Body <<< ------------------------------
## -----------------------------------------------------------------------------

# UNIT_TESTING is set to TRUE when running with (-t option argument)
# or during unit testing.
# simply return when this program is being sourced by a unit test framework
[[ "${UNIT_TESTING:-}" == TRUE ]] && printf "Runing unit tests.\n" && return 0

if ! main "${@:-}"; then
  printf "\n%s failed!\n" "${PRG}" >&2
  exit 1
fi

printf "done\n"
```
