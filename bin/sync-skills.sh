#!/usr/bin/env bash
#
# Synchronize a source skills directory into the Claude Code skills
# directory (${HOME}/.claude/skills by default).
#
# Repository:
#   https://github.com/rubensgomes/agent-skills
#
# Source:
#   https://github.com/rubensgomes/agent-skills/blob/main/bin/sync-skills.sh
#
# Description:
#   Performs a recursive, per-file mirror of a source directory into a
#   destination directory, in three passes:
#
#     Pass 1  Every regular file under the source is copied to the same
#             relative path under the destination, overwriting whatever is
#             already there. Files whose contents already match are left
#             untouched so repeat runs cause no needless writes.
#     Pass 2  Every regular file under the destination that has no
#             counterpart at the same relative path in the source is moved
#             to <dest>/old/<relative-path>. Nothing is ever deleted. A
#             previous backup at the same relative path is replaced.
#     Pass 3  Directories left empty by pass 2 are removed, so a renamed or
#             retired skill does not leave a hollow directory behind.
#
#   The backup directory <dest>/old is pruned from the pass 2 scan. Without
#   that exclusion every run would back up its own backups and nest them
#   one level deeper each time.
#
# Usage:
#   sync-skills.sh --source <dir> [--dest <dir>] [--dry-run] [--verbose]
#   sync-skills.sh --help
#
# Options:
#   -s, --source <dir>  Source skills directory. Required; no default.
#   -d, --dest <dir>    Destination directory. Defaults to
#                       ${HOME}/.claude/skills. Provided mainly so the
#                       script can be rehearsed against a throwaway tree.
#   -n, --dry-run       Report every action without touching the
#                       filesystem.
#   -v, --verbose       Log per-file progress to STDOUT.
#   -h, --help          Print this help text and exit.
#
# Exit codes:
#   0  Success.
#   1  Runtime error: unreadable source, failed copy or move, or an
#      overlapping source and destination.
#   2  Usage error: missing --source, unknown option, or an option that is
#      missing its argument.
#
# Portability:
#   The Google Shell Style Guide prescribes '#!/bin/bash'. This script uses
#   '#!/usr/bin/env bash' instead because on macOS /bin/bash is frozen at
#   3.2.57 while a current bash is normally earlier on PATH. Because that
#   3.2 fallback is a real possibility, the script is written strictly to
#   the bash 3.2 feature set: no mapfile/readarray, no associative arrays,
#   no ${var,,}, no globstar. Enforce with:
#
#     /bin/bash -n sync-skills.sh
#
# Limitations:
#   Symlinks are neither copied nor treated as orphans; they are reported
#   under --verbose and otherwise ignored. Text and binary files are
#   treated alike. Backups are not versioned: re-backing up the same
#   relative path replaces the earlier copy.
#
# Author: Rubens Gomes <https://rubensgomes.com/>

set -euo pipefail

if [[ -z "${BASH_VERSINFO[0]:-}" ]]; then
  echo "This script must be run with bash." >&2
  exit 1
fi

#######################################
# Constants.
#######################################
PROGRAM_NAME="$(basename -- "${BASH_SOURCE[0]}")"
readonly PROGRAM_NAME
readonly DEFAULT_DEST_DIR="${HOME}/.claude/skills"
readonly BACKUP_DIR_NAME="old"
readonly PRUNE_MAX_ROUNDS=64

# Path segments never copied in, and never treated as orphans on the way
# out. Applying the same list to both passes is what keeps the script from
# relocating a user's stray .DS_Store on every run.
SKIP_NAMES=(".git" ".DS_Store" ".idea")

#######################################
# Mutable script-scope state. Declared here because bash 3.2 has no
# 'declare -g' with which a function could create them.
#######################################
VERBOSE=0
DRY_RUN=0
SOURCE_ARG=""
DEST_ARG="${DEFAULT_DEST_DIR}"
SOURCE_DIR=""
DEST_DIR=""
BACKUP_DIR=""
COUNT_ADDED=0
COUNT_UPDATED=0
COUNT_UNCHANGED=0
COUNT_BACKED_UP=0
COUNT_PRUNED=0
COUNT_SKIPPED=0

#######################################
# Prints the usage text.
# Outputs:
#   Usage text to STDOUT. Error paths redirect it to STDERR.
#######################################
usage() {
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

#######################################
# Prints a timestamped error message.
# Arguments:
#   Message words.
# Outputs:
#   Message to STDERR.
#######################################
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# Prints a timestamped error message and exits with status 1.
# Arguments:
#   Message words.
# Outputs:
#   Message to STDERR.
#######################################
die() {
  err "$@"
  exit 1
}

#######################################
# Prints an unconditional message.
# Arguments:
#   Message words.
# Outputs:
#   Message to STDOUT.
#######################################
log_info() {
  echo "$*"
}

#######################################
# Prints a message only when verbose mode is on.
# Globals:
#   VERBOSE
# Arguments:
#   Message words.
# Outputs:
#   Message to STDOUT when VERBOSE is 1.
#######################################
log_verbose() {
  if [[ "${VERBOSE}" -eq 1 ]]; then
    echo "$*"
  fi
}

#######################################
# Logs one per-file action, tagging it when running in dry-run mode. This
# is the single place the dry-run prefix is applied.
# Globals:
#   DRY_RUN
# Arguments:
#   Verb describing the action, e.g. "added".
#   Detail, normally a relative path.
# Outputs:
#   Formatted line to STDOUT when verbose.
#######################################
log_action() {
  local verb="$1"
  local detail="$2"
  local prefix=""

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    prefix="[dry-run] "
  fi
  log_verbose "$(printf '%s%-10s %s' "${prefix}" "${verb}" "${detail}")"
}

#######################################
# Resolves a directory to its canonical absolute path. Handles relative
# paths, trailing slashes, "." and ".." and symlinked ancestors, without
# depending on realpath(1).
# Arguments:
#   Directory path.
# Outputs:
#   Absolute path, without a trailing slash, to STDOUT.
# Returns:
#   0 if the directory is traversable, non-zero otherwise.
#######################################
to_absolute_path() {
  (cd -- "$1" 2>/dev/null && pwd -P)
}

#######################################
# Parses command-line arguments.
# Globals:
#   SOURCE_ARG, DEST_ARG, DRY_RUN, VERBOSE
# Arguments:
#   All command-line arguments.
#######################################
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s | --source)
        if [[ $# -lt 2 ]]; then
          err "Option requires an argument: $1"
          usage >&2
          exit 2
        fi
        SOURCE_ARG="$2"
        shift 2
        ;;
      --source=*)
        SOURCE_ARG="${1#--source=}"
        shift
        ;;
      -d | --dest)
        if [[ $# -lt 2 ]]; then
          err "Option requires an argument: $1"
          usage >&2
          exit 2
        fi
        DEST_ARG="$2"
        shift 2
        ;;
      --dest=*)
        DEST_ARG="${1#--dest=}"
        shift
        ;;
      -n | --dry-run)
        DRY_RUN=1
        shift
        ;;
      -v | --verbose)
        VERBOSE=1
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        err "Unknown option: $1"
        usage >&2
        exit 2
        ;;
      *)
        err "Unexpected argument: $1"
        usage >&2
        exit 2
        ;;
    esac
  done

  if [[ $# -gt 0 ]]; then
    err "Unexpected argument: $1"
    usage >&2
    exit 2
  fi
}

#######################################
# Verifies the source directory exists and is readable, then resolves it.
# Globals:
#   SOURCE_ARG (read), SOURCE_DIR (written)
# Outputs:
#   Error message to STDERR on failure.
#######################################
validate_source_dir() {
  local resolved

  if [[ -z "${SOURCE_ARG}" ]]; then
    err "Missing required option: --source"
    usage >&2
    exit 2
  fi
  if [[ ! -e "${SOURCE_ARG}" ]]; then
    die "Source directory does not exist: ${SOURCE_ARG}"
  fi
  if [[ ! -d "${SOURCE_ARG}" ]]; then
    die "Source is not a directory: ${SOURCE_ARG}"
  fi
  if [[ ! -r "${SOURCE_ARG}" ]]; then
    die "Source directory is not readable: ${SOURCE_ARG}"
  fi
  if [[ ! -x "${SOURCE_ARG}" ]]; then
    die "Source directory is not traversable: ${SOURCE_ARG}"
  fi

  resolved="$(to_absolute_path "${SOURCE_ARG}")" \
    || die "Cannot resolve source directory: ${SOURCE_ARG}"
  SOURCE_DIR="${resolved}"
}

#######################################
# Creates the destination directory when needed, verifies it is writable,
# and resolves it. In dry-run mode a missing destination is synthesized
# from its parent rather than created.
# Globals:
#   DEST_ARG, DRY_RUN (read); DEST_DIR, BACKUP_DIR (written)
# Outputs:
#   Error message to STDERR on failure.
#######################################
prepare_dest_dir() {
  local resolved
  local parent
  local base

  if [[ -e "${DEST_ARG}" && ! -d "${DEST_ARG}" ]]; then
    die "Destination exists but is not a directory: ${DEST_ARG}"
  fi

  if [[ ! -d "${DEST_ARG}" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      parent="$(dirname -- "${DEST_ARG}")"
      base="$(basename -- "${DEST_ARG}")"
      resolved="$(to_absolute_path "${parent}")" \
        || die "Cannot resolve destination parent: ${parent}"
      DEST_DIR="${resolved}/${base}"
      BACKUP_DIR="${DEST_DIR}/${BACKUP_DIR_NAME}"
      return 0
    fi
    mkdir -p -- "${DEST_ARG}" \
      || die "Cannot create destination directory: ${DEST_ARG}"
  fi

  if [[ ! -w "${DEST_ARG}" || ! -x "${DEST_ARG}" ]]; then
    die "Destination directory is not writable: ${DEST_ARG}"
  fi

  resolved="$(to_absolute_path "${DEST_ARG}")" \
    || die "Cannot resolve destination directory: ${DEST_ARG}"
  DEST_DIR="${resolved}"
  BACKUP_DIR="${DEST_DIR}/${BACKUP_DIR_NAME}"
}

#######################################
# Rejects a source and destination that overlap. Either nesting would make
# one of the passes operate on its own output.
# Globals:
#   SOURCE_DIR, DEST_DIR
# Outputs:
#   Error message to STDERR on failure.
#######################################
assert_paths_disjoint() {
  if [[ "${SOURCE_DIR}" == "${DEST_DIR}" ]]; then
    die "Source and destination are the same directory: ${SOURCE_DIR}"
  fi
  if [[ "${SOURCE_DIR}" == "${DEST_DIR}"/* ]]; then
    die "Source is inside the destination: ${SOURCE_DIR}"
  fi
  if [[ "${DEST_DIR}" == "${SOURCE_DIR}"/* ]]; then
    die "Destination is inside the source: ${DEST_DIR}"
  fi
}

#######################################
# Rejects a source that owns the name reserved for the backup directory.
# Such an entry would be copied straight into the backup area and then be
# hidden from orphan tracking by the pass 2 prune.
# Globals:
#   SOURCE_DIR, BACKUP_DIR_NAME
# Outputs:
#   Error message to STDERR on failure.
#######################################
assert_no_reserved_collision() {
  if [[ -e "${SOURCE_DIR}/${BACKUP_DIR_NAME}" ]]; then
    die "Source contains the reserved entry" \
      "'${BACKUP_DIR_NAME}', which collides with the backup directory."
  fi
}

#######################################
# Reports whether a relative path contains an excluded segment.
# Globals:
#   SKIP_NAMES
# Arguments:
#   Relative path.
# Returns:
#   0 if the path should be skipped, 1 otherwise.
#######################################
should_skip_rel_path() {
  local remainder="$1"
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

#######################################
# Copies one source file to the destination, skipping the write when the
# contents already match.
# Globals:
#   DEST_DIR, DRY_RUN, COUNT_ADDED, COUNT_UPDATED, COUNT_UNCHANGED
# Arguments:
#   Absolute path of the source file.
#   Path of the file relative to the source directory.
#######################################
copy_one_file() {
  local src_file="$1"
  local rel_path="$2"
  local target="${DEST_DIR}/${rel_path}"
  local verb

  if [[ -f "${target}" ]] && cmp -s -- "${src_file}" "${target}"; then
    log_action "unchanged" "${rel_path}"
    COUNT_UNCHANGED=$((COUNT_UNCHANGED + 1))
    return 0
  fi

  if [[ -e "${target}" ]]; then
    verb="updated"
  else
    verb="added"
  fi
  log_action "${verb}" "${rel_path}"

  if [[ "${DRY_RUN}" -eq 0 ]]; then
    mkdir -p -- "$(dirname -- "${target}")" \
      || die "Cannot create destination directory for: ${rel_path}"
    cp -f -- "${src_file}" "${target}" \
      || die "Failed to copy: ${rel_path}"
  fi

  if [[ "${verb}" == "added" ]]; then
    COUNT_ADDED=$((COUNT_ADDED + 1))
  else
    COUNT_UPDATED=$((COUNT_UPDATED + 1))
  fi
}

#######################################
# Pass 1. Copies every regular file from the source into the destination.
# Globals:
#   SOURCE_DIR, COUNT_SKIPPED
#######################################
sync_source_to_dest() {
  local src_file
  local rel_path

  log_verbose "Pass 1: copying source files into the destination"

  while IFS= read -r -d '' src_file; do
    rel_path="${src_file#"${SOURCE_DIR}/"}"
    if should_skip_rel_path "${rel_path}"; then
      log_action "skipped" "${rel_path}"
      COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
      continue
    fi
    copy_one_file "${src_file}" "${rel_path}"
  done < <(find "${SOURCE_DIR}" -type f -print0)

  # Symlinks are out of scope, but report them so their absence from the
  # destination is visible rather than silent.
  while IFS= read -r -d '' src_file; do
    rel_path="${src_file#"${SOURCE_DIR}/"}"
    log_action "skipped" "${rel_path} (symlink)"
    COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
  done < <(find "${SOURCE_DIR}" -type l -print0)
}

#######################################
# Pass 2. Moves destination files with no source counterpart into the
# backup directory. The backup directory itself is pruned from the scan.
# Globals:
#   SOURCE_DIR, DEST_DIR, BACKUP_DIR, DRY_RUN, COUNT_BACKED_UP
#######################################
backup_orphans() {
  local dest_file
  local rel_path
  local backup_target
  local note

  log_verbose "Pass 2: backing up destination-only files"

  if [[ ! -d "${DEST_DIR}" ]]; then
    return 0
  fi

  while IFS= read -r -d '' dest_file; do
    rel_path="${dest_file#"${DEST_DIR}/"}"
    if should_skip_rel_path "${rel_path}"; then
      log_action "skipped" "${rel_path}"
      continue
    fi
    if [[ -f "${SOURCE_DIR}/${rel_path}" ]]; then
      continue
    fi

    backup_target="${BACKUP_DIR}/${rel_path}"
    note=""
    if [[ -e "${backup_target}" ]]; then
      note=" (replaces previous backup)"
    fi
    log_action "backup" \
      "${rel_path} -> ${BACKUP_DIR_NAME}/${rel_path}${note}"

    if [[ "${DRY_RUN}" -eq 0 ]]; then
      mkdir -p -- "$(dirname -- "${backup_target}")" \
        || die "Cannot create backup directory for: ${rel_path}"
      mv -f -- "${dest_file}" "${backup_target}" \
        || die "Failed to back up: ${rel_path}"
    fi
    COUNT_BACKED_UP=$((COUNT_BACKED_UP + 1))
  done < <(find "${DEST_DIR}" -path "${BACKUP_DIR}" -prune -o \
    -type f -print0)
}

#######################################
# Pass 3. Removes directories left empty by pass 2. A parent only becomes
# empty once its children are gone, so this loops to a fixpoint.
# Globals:
#   DEST_DIR, BACKUP_DIR, DRY_RUN, PRUNE_MAX_ROUNDS, COUNT_PRUNED
#######################################
prune_empty_dirs() {
  local dir
  local rel_path
  local round=0
  local removed_this_round

  log_verbose "Pass 3: pruning empty directories"

  if [[ ! -d "${DEST_DIR}" ]]; then
    return 0
  fi

  while [[ "${round}" -lt "${PRUNE_MAX_ROUNDS}" ]]; do
    round=$((round + 1))
    removed_this_round=0

    while IFS= read -r -d '' dir; do
      rel_path="${dir#"${DEST_DIR}/"}"
      if [[ "${DRY_RUN}" -eq 0 ]]; then
        rmdir -- "${dir}" 2>/dev/null || continue
      fi
      log_action "pruned" "${rel_path}/"
      removed_this_round=$((removed_this_round + 1))
      COUNT_PRUNED=$((COUNT_PRUNED + 1))
    done < <(find "${DEST_DIR}" -mindepth 1 -depth -type d -empty \
      -not -path "${BACKUP_DIR}" -not -path "${BACKUP_DIR}/*" -print0)

    # In dry-run mode nothing is removed, so a second round would report
    # the same directories forever.
    if [[ "${removed_this_round}" -eq 0 || "${DRY_RUN}" -eq 1 ]]; then
      break
    fi
  done
}

#######################################
# Prints the run summary.
# Globals:
#   All COUNT_* counters, DRY_RUN
# Outputs:
#   Summary line to STDOUT.
#######################################
print_summary() {
  local mode="live"

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    mode="dry-run"
  fi
  log_info "Sync complete (${mode}):" \
    "added=${COUNT_ADDED}" \
    "updated=${COUNT_UPDATED}" \
    "unchanged=${COUNT_UNCHANGED}" \
    "backed_up=${COUNT_BACKED_UP}" \
    "pruned=${COUNT_PRUNED}" \
    "skipped=${COUNT_SKIPPED}"
}

#######################################
# Entry point.
# Arguments:
#   All command-line arguments.
#######################################
main() {
  parse_args "$@"

  validate_source_dir
  prepare_dest_dir
  assert_paths_disjoint
  assert_no_reserved_collision
  readonly SOURCE_DIR DEST_DIR BACKUP_DIR

  log_verbose "Source:      ${SOURCE_DIR}"
  log_verbose "Destination: ${DEST_DIR}"
  log_verbose "Backup:      ${BACKUP_DIR}"

  sync_source_to_dest
  backup_orphans
  prune_empty_dirs
  print_summary
}

main "$@"
