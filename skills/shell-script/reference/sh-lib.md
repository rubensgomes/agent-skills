# sh-lib Function Reference

Public functions of the Bash libraries installed at `${HOME}/lib/sh-lib`.
Prefer these over hand-rolled equivalents. See `template/template.sh` for a
working example.

Functions whose name starts with an underscore (`msg::_msg`,
`os::_check_rm_files_args`, ...) are private. Do not call them.

## Sourcing

| File          | Provides  | Auto-sources                           |
|---------------|-----------|----------------------------------------|
| `msg_lib.sh`  | `msg::*`  | —                                      |
| `os_lib.sh`   | `os::*`   | `msg_lib.sh`                           |
| `sh_lib.sh`   | `sh::*`   | `msg_lib.sh`                           |
| `misc_lib.sh` | `misc::*` | `msg_lib.sh`, `os_lib.sh`, `sh_lib.sh` |
| `sed_lib.sh`  | `sed::*`  | `msg_lib.sh`, `os_lib.sh`              |

```bash
source "${HOME}/lib/sh-lib/msg_lib.sh" || exit
source "${HOME}/lib/sh-lib/os_lib.sh" || exit
source "${HOME}/lib/sh-lib/sh_lib.sh" || exit
```

Each library sets a `<NAME>_LIB_SOURCED` guard, so sourcing twice is a no-op.

**Order matters for the Bash version check.** `sh_lib.sh` defines
`BASH_MAJOR_VERSION` / `BASH_MINOR_VERSION` with the guarded-constant idiom,
defaulting to `3` / `2`. To require a newer Bash, declare them *before*
sourcing `sh_lib.sh`:

```bash
# shellcheck disable=SC2034
readonly BASH_MAJOR_VERSION="4"
# shellcheck disable=SC2034
readonly BASH_MINOR_VERSION="2"
```

## Conventions

- `TRUE=0` and `FALSE=1` — shell truth, not C truth. A predicate
  "returns 0" when the answer is yes.
- **Every `msg::*` function writes to stderr**, never stdout. stdout is
  reserved for passing data between functions.
- `msg::*` printing functions accept either a plain string or a `printf`
  format string followed by its arguments:
  `msg::debug "topics=%s\n" "${g_topics}"`.
- Functions that produce a *value* write it to stdout; capture with
  `$(...)`: `os::merge_paths`, `sh::trim_space`, `sh::version`,
  `sh::max_arg_length`, `sh::elapsed_time_min`, `misc::git_proj_root`,
  `misc::property_value`.
- `DEFAULT_TZ` defaults to `America/Chicago`; `sh::init` exports `TZ` from
  it when `TZ` is unset.

## msg_lib.sh — messages

All output goes to stderr. All accept `printf`-style format + arguments.

| Function                   | Purpose                                                                                                                |
|----------------------------|------------------------------------------------------------------------------------------------------------------------|
| `msg::info "fmt" ...`      | Informational message.                                                                                                 |
| `msg::warn "fmt" ...`      | Warning message.                                                                                                       |
| `msg::error "fmt" ...`     | Error message. Returns, does not exit.                                                                                 |
| `msg::debug "fmt" ...`     | Only printed when debug mode is enabled.                                                                               |
| `msg::fatal "fmt" ...`     | Fatal message. Printed before dying; does not exit.                                                                    |
| `msg::arg_error "fmt" ...` | Argument error. Like `msg::error` but the message argument is required. Use for bad or missing CLI/function arguments. |
| `msg::die "fmt" ...`       | `msg::error` then **`exit 1`**.                                                                                        |

Mode flags — each has an `enable`, a `disable`, and a predicate:

| Enable                | Disable                | Predicate         | Effect                              |
|-----------------------|------------------------|-------------------|-------------------------------------|
| `msg::enable_debug`   | `msg::disable_debug`   | `msg::is_debug`   | Emit `msg::debug` output.           |
| `msg::enable_quiet`   | `msg::disable_quiet`   | `msg::is_quiet`   | Suppress all but errors.            |
| `msg::enable_verbose` | `msg::disable_verbose` | `msg::is_verbose` | Add caller/line detail to messages. |
| `msg::enable_tracing` | `msg::disable_tracing` | `msg::is_tracing` | `set -x` command tracing.           |

Wire these to the `-d`, `-q`, `-v`, `-x` CLI options as `parse_options()`
does in `template/template.sh`.

| Function      | Purpose                                           |
|---------------|---------------------------------------------------|
| `msg::yes_no` | Prompt the user Y/N. Returns 0 for yes, 1 for no. |

## os_lib.sh — operating system

| Function                     | Arguments                                                     | Purpose                                                                                                   |
|------------------------------|---------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| `os::is_installed`           | 1: space-separated command list (e.g. `"docker java unzip"`)  | 0 if all are on `PATH`. A `gnu-<cmd>` name checks for the GNU variant. Use it in `check_required_tool()`. |
| `os::is_gnu_cmd`             | 1: command                                                    | 0 if that command is the GNU build.                                                                       |
| `os::is_macos`               | none                                                          | 0 on macOS, 1 otherwise.                                                                                  |
| `os::info`                   | none                                                          | Prints host/OS/Bash details.                                                                              |
| `os::merge_paths`            | 1, 2: `:`-separated paths                                     | **stdout:** the two paths merged, duplicates removed.                                                     |
| `os::set_java_home`          | 1: path                                                       | Validates it, sets `JAVA_HOME`, prepends to `PATH`.                                                       |
| `os::rm_files`               | 1: parent dir, 2: name patterns (e.g. `"*build local *.out"`) | Deletes matching files owned by `${UID}` under the parent, recursively.                                   |
| `os::rm_files_prompt_user`   | same as above                                                 | Same, but asks first.                                                                                     |
| `os::rm_subdirs`             | 1: parent dir, 2: name patterns                               | Deletes matching subdirectories owned by `${UID}`, recursively.                                           |
| `os::rm_subdirs_prompt_user` | same as above                                                 | Same, but asks first.                                                                                     |

## sh_lib.sh — shell

| Function                 | Arguments                                                | Purpose                                                                                                                                                                                                               |
|--------------------------|----------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `sh::init`               | none                                                     | **Strict mode and shell setup.** Checks the Bash version, `unalias -a`, sets `errexit`/`nounset`/`pipefail`, exports `TZ`, verifies the basic tools. Call it from `main()`; do not write `set -euo pipefail` by hand. |
| `sh::curry_trap_command` | 1: handler function name, 2: space-separated signal list | Installs the handler for each signal, passing the signal *name* to it as `$1`. This is how `signal_handler()` gets registered — never call the handler directly.                                                      |
| `sh::check_version`      | none                                                     | 0 if the running Bash satisfies `BASH_MAJOR_VERSION`/`BASH_MINOR_VERSION`. Already called by `sh::init`.                                                                                                              |
| `sh::version`            | none                                                     | **stdout:** Bash version as `major.feature.patch`.                                                                                                                                                                    |
| `sh::trim_space`         | 1: string                                                | **stdout:** the string with leading/trailing blanks and newlines removed. Interior spaces are kept.                                                                                                                   |
| `sh::is_valid_url`       | 1: URL                                                   | 0 if it looks like a URL. Basic syntactic check only.                                                                                                                                                                 |
| `sh::set_g_split_by_arr` | 1: delimiter (non-alphanumeric), 2: delimited list       | Splits and trims into the global array **`g_split_by_arr`** — the result is not on stdout.                                                                                                                            |
| `sh::elapsed_time_min`   | 1: start timestamp from `date +%s`                       | **stdout:** whole minutes elapsed.                                                                                                                                                                                    |
| `sh::max_arg_length`     | none                                                     | **stdout:** `ARG_MAX`, the argument-length ceiling.                                                                                                                                                                   |

Registering a trap handler, as in `template/template.sh`:

```bash
local -ar signals=("ERR" "HUP" "INT" "TERM" "QUIT" "EXIT")
sh::curry_trap_command "signal_handler" "${signals[*]}" || return
```

## misc_lib.sh — archives, Git, properties

| Function               | Arguments                            | Purpose                                                              |
|------------------------|--------------------------------------|----------------------------------------------------------------------|
| `misc::git_proj_root`  | none                                 | **stdout:** the Git project root. Must be run inside a working tree. |
| `misc::property_value` | 1: properties file, 2: property name | **stdout:** the value. Errors if the key appears more than once.     |
| `misc::tgz_test`       | 1: `.tgz` file                       | 0 if the tarball is readable and valid.                              |
| `misc::unzip_file`     | 1: destination dir, 2: archive       | Unzips into the destination.                                         |
| `misc::unzip_list`     | 1: zip archive                       | Lists the archive contents.                                          |
| `misc::unzip_test`     | 1: zip archive                       | 0 if the archive is valid.                                           |

## sed_lib.sh — portable sed

| Function       | Arguments                          | Purpose                                                                                                                                                                   |
|----------------|------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `sed::replace` | 1: file, 2: regexp, 3: replacement | In-place `s\|regexp\|replacement\|g`, using the right in-place syntax for BSD vs GNU sed. Extended regex. `\|` may not appear in the regexp; escape other metacharacters. |
| `sed::is_gnu`  | none                               | 0 if the `sed` on `PATH` is GNU, 1 if not, 2 if absent.                                                                                                                   |
| `sed::is_mac`  | none                               | 0 if the `sed` on `PATH` is the macOS build, 1 if not, 2 if absent.                                                                                                       |

## Gotchas

- `sh::init` turns on `errexit`, so from that point on any unchecked
  non-zero return aborts the script. Guard calls you expect to fail with
  `|| return`, `|| true`, or an `if`.
- `nounset` is on after `sh::init`: use `"${var:-}"` for anything that may
  be unset.
- Do not pair `msg::die` with `|| return` — it exits the process.
- `msg::error` returns; only `msg::die` exits. Choosing the wrong one is the
  most common mistake.
- Results come back on stdout, messages on stderr. Never `printf` a value to
  stdout from a function that also logs there.
