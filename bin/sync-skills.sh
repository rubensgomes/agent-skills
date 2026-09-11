#!/usr/bin/env bash
## SPDX-License-Identifier: MIT
##
## Mirrors a source skills directory into the Claude Code skills
## directory, moving aside whatever the source no longer carries.
##
## Repository:
##   https://github.com/rubensgomes/agent-skills
##
## Source:
##   <repository>/blob/main/bin/sync-skills.sh
##
## Exit codes:
##   0  Success.
##   1  Runtime error.
##   2  Usage error.
##
## Requirements:
##  1) Bash functions libraries installed at "${HOME}/lib/sh-lib".
##  2) GNU bash version 4.2 or higher.
##  3) getopt from util-linux 2.30.2 or higher. The macOS
##     /usr/bin/getopt will NOT work; put the GNU build ahead of it on
##     the PATH.
##
## Portability:
##   Running this needs bash 4.2, but the source stays parseable by
##   bash 3.2 so that "/bin/bash -n" still succeeds. That rules out
##   "[[ -v name ]]": guard array constants with "${name[*]:-}".
##
## Limitations:
##   Symlinks are ignored rather than copied or backed up. Backups are
##   not versioned: re-backing up a path replaces the earlier copy.
##
## Author: Rubens Gomes <https://rubensgomes.com/>
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

# Set to TRUE when debugging code using bassupport-pro.  This is
# required to bypass trap handlers which crashes code when running
# from debugger
readonly IS_DEBUGGER=FALSE

# temporary folder for this shell script
[[ -z "${TMP_DIR:-}" ]] && readonly TMP_DIR="/tmp/${PRG}"

# extra tools required by this script to run.
[[ -z "${REQUIRED_TOOLS[*]:-}" ]] && readonly -a REQUIRED_TOOLS=(
  "basename"
  "cmp"
  "cp"
  "dirname"
  "find"
  "getopt"
  "mkdir"
  "mv"
  "rmdir"
)

# destination used when the caller does not name one.
[[ -z "${DEFAULT_DEST_DIR:-}" ]] \
  && readonly DEFAULT_DEST_DIR="${HOME}/.claude/skills"

# Prefix of the sibling folder that orphaned files are moved into
# rather than deleted, so "<dest>" backs up into "<prefix><dest>".
[[ -z "${BACKUP_DIR_PREFIX:-}" ]] && readonly BACKUP_DIR_PREFIX="old-"

# ceiling on the pass 3 fixpoint loop, so a pathological tree cannot
# spin forever.
[[ -z "${PRUNE_MAX_ROUNDS:-}" ]] && readonly PRUNE_MAX_ROUNDS=64

# Applied to both passes, so a user's stray .DS_Store is not
# relocated on every run.
[[ -z "${SKIP_NAMES[*]:-}" ]] && readonly -a SKIP_NAMES=(
  ".git"
  ".DS_Store"
  ".idea"
)

#####################################################################
## INCLUDES #########################################################

[[ -d "${HOME}/lib/sh-lib" ]] || {
  printf "missing %s\n" "${HOME}/lib/sh-lib" >&2
  exit 1
}

# -------------------- >>> Import Basic Libraries <<< ---------------

# logging message library
# shellcheck source=/dev/null
source "${HOME}/lib/sh-lib/msg_lib.sh" || exit

# operating system library
# shellcheck source=/dev/null
source "${HOME}/lib/sh-lib/os_lib.sh" || exit

# bash library
# shellcheck source=/dev/null
source "${HOME}/lib/sh-lib/sh_lib.sh" || exit


#####################################################################
## GLOBAL VARIABLES #################################################

# Boolean flag used to run this shell script in "dry" run mode
# (no changes)
declare g_is_dry_run=FALSE

# Boolean flag used to remove temporary files in trap handler
declare g_is_force_delete=FALSE

# Source directory as the user typed it
declare g_source_arg=

# Destination directory as the user typed it
declare g_dest_arg=


#####################################################################
## FUNCTIONS ########################################################

#####################################################################
## Prints help to stdout.
## Globals:
##  BACKUP_DIR_PREFIX
##  DEFAULT_DEST_DIR
##  PRG
## Arguments:
##  none.
## Returns:
##   0 always
#####################################################################
help() {
  cat <<EOF

"${PRG}" mirrors a source skills directory into the Claude Code
skills directory.

Usage:
  ${PRG} -s <source> [options]

General Non Argument Options:

  -d, --debug                  prints debug messages
  -h, --help                   prints this help
  -q, --quiet                  prints only error|fatal messages
  -n, --dry-run                inspects only, does NOT change anything
  -v, --verbose                adds extra details to messages
  -x, --trace                  traces commands

Argument Options:

  -s, --source <dir>           skills directory to sync from
      --dest <dir>             directory to sync into

source (**required**):
  The skills directory this run reads from. Nothing under it is
  modified.

dest:
  The directory this run writes into. Defaults to
  ${DEFAULT_DEST_DIR}. Provided mainly so the script can be
  rehearsed against a throwaway tree.

Files present in the destination but absent from the source are moved
to a sibling folder of <dest> carrying the "${BACKUP_DIR_PREFIX}"
prefix, rather than deleted. The default destination therefore backs
up into ${HOME}/.claude/${BACKUP_DIR_PREFIX}skills.

EOF
}

#####################################################################
## Prints usage to stderr.
## Globals:
##  PRG
## Arguments:
##  none.
## Returns:
##   2 always
#####################################################################
usage() {
  cat <<EOF
Usage:  ${PRG} -s <source> [options]
More information with: "${PRG} -h"
EOF

  # return an error status
  return 2
} >&2

#####################################################################
## Resets the global variables to their initial state.
## Globals:
##  g_dest_arg
##  g_is_dry_run
##  g_is_force_delete
##  g_source_arg
## Arguments:
##  None
## Returns:
##   0 if okay; something else if fails.
#####################################################################
reset_globals() {
  g_is_dry_run=FALSE
  g_is_force_delete=FALSE
  g_source_arg=
  g_dest_arg=
}

#####################################################################
## Parses user's command line input option arguments.
## Globals:
##  DEFAULT_DEST_DIR
##  PRG
##  g_dest_arg
##  g_is_dry_run
##  g_source_arg
## Arguments:
##  Bash shell CLI input arguments.
## Returns:
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
      --o 'dhnqvxs:' \
      --long 'debug,dest:,dry-run,help,quiet,source:,trace,verbose' \
      --name "${PRG}" \
      -- "${@}"
  ); then
    msg::error "failed to parse CLI input arguments."
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
        help
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

      ########## --source ###########################################
      '-s' | '--source')
        if [[ -z "${2:-}" || -z "${2//[[:space:]]/}" ]]; then
          msg::error "source is missing or blank."
          usage
          return 2
        fi
        g_source_arg="$(sh::trim_space "${2}")" || return
        msg::debug "source=%s\n" "${g_source_arg}"
        shift 2
        continue
        ;;

      ########## --dest #############################################
      '--dest')
        if [[ -z "${2:-}" || -z "${2//[[:space:]]/}" ]]; then
          msg::error "dest is missing or blank."
          usage
          return 2
        fi
        g_dest_arg="$(sh::trim_space "${2}")" || return
        msg::debug "dest=%s\n" "${g_dest_arg}"
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

  # reject any positional leftovers: this script takes options only.
  if [[ ${#} -gt 0 ]]; then
    msg::arg_error "unexpected argument [%s].\n" "${1}"
    usage
    return 2
  fi

  # ensure mandatory CLI option "-s, --source" was provided by the
  # user.
  if [[ -z "${g_source_arg:-}" ]]; then
    msg::error "missing [%s] CLI option argument.\n" \
      "--source <dir>"
    usage
    return 2
  fi

  # apply the default destination when the user named none.
  if [[ -z "${g_dest_arg:-}" ]]; then
    g_dest_arg="${DEFAULT_DEST_DIR}"
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
##   0 if okay, something else if fails.
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

  return 0
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
  local -r rc=$?
  msg::debug "entering %s:%s\n" "${FUNCNAME[0]}" "${LINENO}"

  local -r signal="${1:-}"
  msg::debug "handling signal [%s].\n" "${signal}"

  # disables following signals to avoid looping
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
        "the shell controlling terminal was hung: %s\n" \
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
      exit_code=143 # 15+128
      ;;
    ERR)
      msg::warn "execution interrupted by Bash ERR signal: %s\n" \
        "SIGERR"
      exit_code=${rc}
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
      # the stdout is reserved to pass data between functions.
      printf "\nWARNING! This will remove folder:\n%s\n" \
        "${folder}" >&2
      msg::yes_no && is_rm_local=TRUE
    fi

    if [[ "${is_rm_local}" == TRUE ]]; then
      msg::debug "removing tmp folder [%s].\n" "${folder}"
      rm -fr "${folder}"
    fi

  fi

  if [[ -n "${exit_code:-}" ]]; then
    exit "${exit_code}"
  fi

  exit
}

#####################################################################
## Logs one per-file action. The single place the dry-run prefix is
## applied.
## Globals:
##  g_is_dry_run
## Arguments:
##   1 [required]: verb describing the action, e.g. "added".
##   2 [required]: detail, normally a relative path.
## Outputs:
##   Formatted line to stderr when verbose.
## Returns:
##   0 always.
#####################################################################
log_action() {
  local -r verb="${1:-}"
  local -r detail="${2:-}"
  local prefix=""

  msg::is_verbose || return 0

  if [[ "${g_is_dry_run}" == TRUE ]]; then
    prefix="[dry-run] "
  fi

  msg::info "%s%-10s %s\n" "${prefix}" "${verb}" "${detail}"
}

#####################################################################
## Resolves a directory to a canonical absolute path, without
## depending on realpath(1).
## Globals:
##  None.
## Arguments:
##   1 [required]: directory path.
## Outputs:
##   Absolute path, without a trailing slash, to stdout.
## Returns:
##   0 if the directory is traversable, something else otherwise.
#####################################################################
to_absolute_path() {
  (cd -- "${1:-}" 2>/dev/null && pwd -P)
}

#####################################################################
## Vets and resolves the source directory.
## Globals:
##  None.
## Arguments:
##   1 [required]: source directory as the user typed it.
## Outputs:
##   Resolved absolute source directory to stdout.
## Returns:
##   0 if okay; 1 if the source is unusable.
#####################################################################
validate_source_dir() {
  local -r source_arg="${1:-}"
  local resolved

  if [[ ! -e "${source_arg}" ]]; then
    msg::error "source directory does not exist: %s\n" \
      "${source_arg}"
    return 1
  fi

  if [[ ! -d "${source_arg}" ]]; then
    msg::error "source is not a directory: %s\n" "${source_arg}"
    return 1
  fi

  if [[ ! -r "${source_arg}" ]]; then
    msg::error "source directory is not readable: %s\n" \
      "${source_arg}"
    return 1
  fi

  if [[ ! -x "${source_arg}" ]]; then
    msg::error "source directory is not traversable: %s\n" \
      "${source_arg}"
    return 1
  fi

  if ! resolved="$(to_absolute_path "${source_arg}")"; then
    msg::error "cannot resolve source directory: %s\n" \
      "${source_arg}"
    return 1
  fi

  printf "%s\n" "${resolved}"
}

#####################################################################
## Creates, vets and resolves the destination directory. In dry-run
## mode a missing one is synthesized rather than created.
## Globals:
##  g_is_dry_run
## Arguments:
##   1 [required]: destination directory as the user typed it.
## Outputs:
##   Resolved absolute destination directory to stdout.
## Returns:
##   0 if okay; 1 if the destination is unusable.
#####################################################################
prepare_dest_dir() {
  local -r dest_arg="${1:-}"
  local resolved
  local parent
  local base

  if [[ -e "${dest_arg}" && ! -d "${dest_arg}" ]]; then
    msg::error "destination exists but is not a directory: %s\n" \
      "${dest_arg}"
    return 1
  fi

  if [[ ! -d "${dest_arg}" ]]; then

    if [[ "${g_is_dry_run}" == TRUE ]]; then
      parent="$(dirname -- "${dest_arg}")"
      base="$(basename -- "${dest_arg}")"

      if ! resolved="$(to_absolute_path "${parent}")"; then
        msg::error "cannot resolve destination parent: %s\n" \
          "${parent}"
        return 1
      fi

      printf "%s/%s\n" "${resolved}" "${base}"
      return 0
    fi

    if ! mkdir -p -- "${dest_arg}"; then
      msg::error "cannot create destination directory: %s\n" \
        "${dest_arg}"
      return 1
    fi

  fi

  if [[ ! -w "${dest_arg}" || ! -x "${dest_arg}" ]]; then
    msg::error "destination directory is not writable: %s\n" \
      "${dest_arg}"
    return 1
  fi

  if ! resolved="$(to_absolute_path "${dest_arg}")"; then
    msg::error "cannot resolve destination directory: %s\n" \
      "${dest_arg}"
    return 1
  fi

  printf "%s\n" "${resolved}"
}

#####################################################################
## Rejects two trees that overlap: either nesting would make a pass
## operate on its own output.
## Globals:
##  None.
## Arguments:
##   1 [required]: first absolute directory.
##   2 [required]: label naming the first directory.
##   3 [required]: second absolute directory.
##   4 [required]: label naming the second directory.
## Returns:
##   0 if disjoint; exits 1 otherwise.
#####################################################################
assert_pair_disjoint() {
  local -r first="${1:-}"
  local -r first_name="${2:-}"
  local -r second="${3:-}"
  local -r second_name="${4:-}"

  if [[ "${first}" == "${second}" ]]; then
    msg::die "%s and %s are the same directory: %s\n" \
      "${first_name}" "${second_name}" "${first}"
  fi

  if [[ "${first}" == "${second}"/* ]]; then
    msg::die "%s is inside the %s: %s\n" \
      "${first_name}" "${second_name}" "${first}"
  fi

  if [[ "${second}" == "${first}"/* ]]; then
    msg::die "%s is inside the %s: %s\n" \
      "${second_name}" "${first_name}" "${second}"
  fi
}

#####################################################################
## Rejects any overlap among the source, destination and backup
## trees.
## Globals:
##  None.
## Arguments:
##   1 [required]: resolved absolute source directory.
##   2 [required]: resolved absolute destination directory.
##   3 [required]: resolved absolute backup directory.
## Returns:
##   0 if all three are disjoint; exits 1 otherwise.
#####################################################################
assert_paths_disjoint() {
  local -r source_dir="${1:-}"
  local -r dest_dir="${2:-}"
  local -r backup_dir="${3:-}"

  assert_pair_disjoint "${source_dir}" "source" \
    "${dest_dir}" "destination"
  assert_pair_disjoint "${source_dir}" "source" \
    "${backup_dir}" "backup"
  assert_pair_disjoint "${dest_dir}" "destination" \
    "${backup_dir}" "backup"
}

#####################################################################
## Derives the backup directory for a destination: a sibling folder
## carrying the backup prefix, so a rehearsal --dest keeps its backups
## beside it instead of in the real skills tree.
## Globals:
##  BACKUP_DIR_PREFIX
## Arguments:
##   1 [required]: resolved absolute destination directory.
## Outputs:
##   Absolute backup directory to stdout.
## Returns:
##   0 if okay; 1 if the destination has no usable parent.
#####################################################################
backup_dir_for() {
  local -r dest_dir="${1:-}"
  local parent
  local base

  parent="$(dirname -- "${dest_dir}")"
  base="$(basename -- "${dest_dir}")"

  if [[ -z "${base}" || "${base}" == "/" ]]; then
    msg::error "cannot derive a backup directory for: %s\n" \
      "${dest_dir}"
    return 1
  fi

  printf "%s/%s%s\n" "${parent}" "${BACKUP_DIR_PREFIX}" "${base}"
}

#####################################################################
## Reports whether a relative path contains an excluded segment.
## Globals:
##  SKIP_NAMES
## Arguments:
##   1 [required]: relative path.
## Returns:
##   0 if the path should be skipped, 1 otherwise.
#####################################################################
should_skip_rel_path() {
  local remainder="${1:-}"
  local segment
  local skip_name

  while [[ -n "${remainder}" ]]; do
    segment="${remainder%%/*}"

    for skip_name in "${SKIP_NAMES[@]}"; do

      if [[ "${segment}" == "${skip_name}" ]]; then
        return 0
      fi

    done

    if [[ "${remainder}" == */* ]]; then
      remainder="${remainder#*/}"
    else
      remainder=""
    fi

  done

  return 1
}

#####################################################################
## Copies one source file, skipping the write when contents match.
## Globals:
##  g_is_dry_run
## Arguments:
##   1 [required]: absolute path of the source file.
##   2 [required]: path of the file relative to the source directory.
##   3 [required]: resolved absolute destination directory.
## Outputs:
##   The action taken - "added", "updated" or "unchanged" - to stdout.
## Returns:
##   0 if okay; 1 if the copy fails.
#####################################################################
copy_one_file() {
  local -r src_file="${1:-}"
  local -r rel_path="${2:-}"
  local -r dest_dir="${3:-}"
  local -r target="${dest_dir}/${rel_path}"
  local verb

  if [[ -f "${target}" ]] && cmp -s -- "${src_file}" "${target}"; then
    log_action "unchanged" "${rel_path}"
    printf "unchanged\n"
    return 0
  fi

  if [[ -e "${target}" ]]; then
    verb="updated"
  else
    verb="added"
  fi

  log_action "${verb}" "${rel_path}"

  if [[ "${g_is_dry_run}" != TRUE ]]; then

    if ! mkdir -p -- "$(dirname -- "${target}")"; then
      msg::error "cannot create destination directory for: %s\n" \
        "${rel_path}"
      return 1
    fi

    if ! cp -f -- "${src_file}" "${target}"; then
      msg::error "failed to copy: %s\n" "${rel_path}"
      return 1
    fi

  fi

  printf "%s\n" "${verb}"
}

#####################################################################
## Pass 1. Copies every regular file from the source into the
## destination.
## Globals:
##  None.
## Arguments:
##   1 [required]: resolved absolute source directory.
##   2 [required]: resolved absolute destination directory.
## Outputs:
##   "<added> <updated> <unchanged> <skipped>" to stdout.
## Returns:
##   0 if okay; 1 if a copy fails.
#####################################################################
sync_source_to_dest() {
  local -r source_dir="${1:-}"
  local -r dest_dir="${2:-}"
  local src_file
  local rel_path
  local verb
  local -i added=0
  local -i updated=0
  local -i unchanged=0
  local -i skipped=0

  msg::debug "pass 1: copying source files into the destination\n"

  while IFS= read -r -d '' src_file; do
    rel_path="${src_file#"${source_dir}/"}"

    if should_skip_rel_path "${rel_path}"; then
      log_action "skipped" "${rel_path}"
      skipped=$((skipped + 1))
      continue
    fi

    verb="$(
      copy_one_file "${src_file}" "${rel_path}" "${dest_dir}"
    )" || return 1

    case "${verb}" in
      added) added=$((added + 1)) ;;
      updated) updated=$((updated + 1)) ;;
      *) unchanged=$((unchanged + 1)) ;;
    esac

  done < <(find "${source_dir}" -type f -print0)

  # Symlinks are out of scope, but report them so their absence from
  # the destination is visible rather than silent.
  while IFS= read -r -d '' src_file; do
    rel_path="${src_file#"${source_dir}/"}"
    log_action "skipped" "${rel_path} (symlink)"
    skipped=$((skipped + 1))
  done < <(find "${source_dir}" -type l -print0)

  printf "%d %d %d %d\n" \
    "${added}" "${updated}" "${unchanged}" "${skipped}"
}

#####################################################################
## Pass 2. Moves destination-only files into the backup directory,
## which is itself pruned from the scan.
## Globals:
##  g_is_dry_run
## Arguments:
##   1 [required]: resolved absolute source directory.
##   2 [required]: resolved absolute destination directory.
##   3 [required]: resolved absolute backup directory.
## Outputs:
##   Count of files backed up to stdout.
## Returns:
##   0 if okay; 1 if a move fails.
#####################################################################
backup_orphans() {
  local -r source_dir="${1:-}"
  local -r dest_dir="${2:-}"
  local -r backup_dir="${3:-}"
  local dest_file
  local rel_path
  local backup_target
  local note
  local backup_name
  local -i backed_up=0

  msg::debug "pass 2: backing up destination-only files\n"

  backup_name="$(basename -- "${backup_dir}")"

  if [[ ! -d "${dest_dir}" ]]; then
    printf "%d\n" "${backed_up}"
    return 0
  fi

  while IFS= read -r -d '' dest_file; do
    rel_path="${dest_file#"${dest_dir}/"}"

    if should_skip_rel_path "${rel_path}"; then
      log_action "skipped" "${rel_path}"
      continue
    fi

    if [[ -f "${source_dir}/${rel_path}" ]]; then
      continue
    fi

    backup_target="${backup_dir}/${rel_path}"
    note=""

    if [[ -e "${backup_target}" ]]; then
      note=" (replaces previous backup)"
    fi

    log_action "backup" \
      "${rel_path} -> ${backup_name}/${rel_path}${note}"

    if [[ "${g_is_dry_run}" != TRUE ]]; then

      if ! mkdir -p -- "$(dirname -- "${backup_target}")"; then
        msg::error "cannot create backup directory for: %s\n" \
          "${rel_path}"
        return 1
      fi

      if ! mv -f -- "${dest_file}" "${backup_target}"; then
        msg::error "failed to back up: %s\n" "${rel_path}"
        return 1
      fi

    fi

    backed_up=$((backed_up + 1))
  done < <(find "${dest_dir}" -type f -print0)

  printf "%d\n" "${backed_up}"
}

#####################################################################
## Pass 3. Removes directories left empty by pass 2, looping to a
## fixpoint because a parent empties only after its children.
## Globals:
##  PRUNE_MAX_ROUNDS
##  g_is_dry_run
## Arguments:
##   1 [required]: resolved absolute destination directory.
## Outputs:
##   Count of directories pruned to stdout.
## Returns:
##   0 if okay; something else if fails.
#####################################################################
prune_empty_dirs() {
  local -r dest_dir="${1:-}"
  local dir
  local rel_path
  local -i round=0
  local -i removed_this_round
  local -i pruned=0

  msg::debug "pass 3: pruning empty directories\n"

  if [[ ! -d "${dest_dir}" ]]; then
    printf "%d\n" "${pruned}"
    return 0
  fi

  while [[ "${round}" -lt "${PRUNE_MAX_ROUNDS}" ]]; do
    round=$((round + 1))
    removed_this_round=0

    while IFS= read -r -d '' dir; do
      rel_path="${dir#"${dest_dir}/"}"

      if [[ "${g_is_dry_run}" != TRUE ]]; then
        rmdir -- "${dir}" 2>/dev/null || continue
      fi

      log_action "pruned" "${rel_path}/"
      removed_this_round=$((removed_this_round + 1))
      pruned=$((pruned + 1))
    done < <(find "${dest_dir}" -mindepth 1 -depth -type d -empty \
      -print0)

    # In dry-run mode nothing is removed, so a second round would
    # report the same directories forever.
    if [[ "${removed_this_round}" -eq 0 ]] \
      || [[ "${g_is_dry_run}" == TRUE ]]; then
      break
    fi

  done

  printf "%d\n" "${pruned}"
}

#####################################################################
## Prints the run summary.
## Globals:
##  g_is_dry_run
## Arguments:
##   1 [required]: count of files added.
##   2 [required]: count of files updated.
##   3 [required]: count of files left unchanged.
##   4 [required]: count of files backed up.
##   5 [required]: count of directories pruned.
##   6 [required]: count of entries skipped.
## Outputs:
##   Summary lines to stderr.
## Returns:
##   0 always.
#####################################################################
print_summary() {
  local -r added="${1:-0}"
  local -r updated="${2:-0}"
  local -r unchanged="${3:-0}"
  local -r backed_up="${4:-0}"
  local -r pruned="${5:-0}"
  local -r skipped="${6:-0}"
  local mode="live"

  if [[ "${g_is_dry_run}" == TRUE ]]; then
    mode="dry-run"
  fi

  msg::info "sync complete (%s):\n" "${mode}"
  msg::info "  added=%d updated=%d unchanged=%d\n" \
    "${added}" "${updated}" "${unchanged}"
  msg::info "  backed_up=%d pruned=%d skipped=%d\n" \
    "${backed_up}" "${pruned}" "${skipped}"
}

#####################################################################
## Runs the three passes and reports the totals. The counts live here
## as locals: each pass returns its own tallies on stdout.
## Globals:
##  None.
## Arguments:
##   1 [required]: resolved absolute source directory.
##   2 [required]: resolved absolute destination directory.
##   3 [required]: resolved absolute backup directory.
## Returns:
##   0 if okay; something else if a pass fails.
#####################################################################
run_passes() {
  local -r source_dir="${1:-}"
  local -r dest_dir="${2:-}"
  local -r backup_dir="${3:-}"
  local counts
  local -i added=0
  local -i updated=0
  local -i unchanged=0
  local -i skipped=0
  local -i backed_up=0
  local -i pruned=0

  counts="$(sync_source_to_dest "${source_dir}" "${dest_dir}")" \
    || return

  read -r added updated unchanged skipped <<<"${counts}"

  backed_up="$(
    backup_orphans "${source_dir}" "${dest_dir}" "${backup_dir}"
  )" || return

  pruned="$(prune_empty_dirs "${dest_dir}")" || return

  print_summary "${added}" "${updated}" "${unchanged}" \
    "${backed_up}" "${pruned}" "${skipped}"
}

#####################################################################
## Main function.
## Globals:
##  IS_DEBUGGER
##  PRG
##  REQUIRED_TOOLS
##  TMP_DIR
##  g_dest_arg
##  g_is_dry_run
##  g_is_force_delete
##  g_source_arg
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

  parse_options "$@" || return

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
  msg::debug "[%s]: %s\n" "g_source_arg" "${g_source_arg}"
  msg::debug "[%s]: %s\n" "g_dest_arg" "${g_dest_arg}"

  # --------------- >>> Resolve And Vet The Two Trees <<< -----------

  # Resolved paths are locals, not globals: every function below
  # receives what it needs as an argument.
  local source_dir
  local dest_dir
  local backup_dir

  source_dir="$(validate_source_dir "${g_source_arg}")" || return
  dest_dir="$(prepare_dest_dir "${g_dest_arg}")" || return
  backup_dir="$(backup_dir_for "${dest_dir}")" || return

  assert_paths_disjoint "${source_dir}" "${dest_dir}" \
    "${backup_dir}" || return

  msg::debug "[%s]: %s\n" "source_dir" "${source_dir}"
  msg::debug "[%s]: %s\n" "dest_dir" "${dest_dir}"
  msg::debug "[%s]: %s\n" "backup_dir" "${backup_dir}"

  # --------------- >>> Is this a Dry Run Only  <<< -----------------

  if [[ "${g_is_dry_run}" != TRUE ]]; then
    # !!! ONLY RUN THE FOLLOWING IF THIS IS NOT A DRY RUN !!!
    msg::debug "I am running real code that can change the state.\n"
  else
    msg::debug "I am running in dry-run mode.\n"
  fi

  # --------------- >>> Run The Three Passes <<< --------------------

  run_passes "${source_dir}" "${dest_dir}" "${backup_dir}" || return
}

#####################################################################
## ------------------------------------------------------------------
## -------------------- >>> Main Program Body <<< -------------------
## ------------------------------------------------------------------

declare -i rc=0
main "$@" || rc=${?}

# The template collapses every failure to "exit 1". This script
# documents distinct exit codes (2 for a usage error, 1 for a runtime
# error), so propagate whatever main returned instead.
if [[ "${rc}" -ne 0 ]]; then
  printf "\n%s failed!\n" "${PRG}" >&2
  exit "${rc}"
fi

printf "done\n"
