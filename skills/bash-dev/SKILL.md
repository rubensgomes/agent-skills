---
name: bash-dev
description: >-
  Creates, edits, formats, and reviews a bash shell script.
---

## CRITICAL: Initial Validation Step

Before running any other command or processing data, you MUST run the
[bootstrap.sh](./scripts/bootstrap.sh) environment check script.

- **IF THE SCRIPT FAILS (Exit Code different from 0):** Stop immediately.
  Report the exact error message to the user and ask them to configure the
  missing dependency.
- **IF THE SCRIPT PASSES (Exit Code 0):** Proceed to the steps below.

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
- **Global Variables**:  You should avoid using global variables. But when
  used, global variables should be named starting with "g_" (e.g.,
  `g_is_dry_run`).
- **Built-ins**: Use `printf` instead of `echo` for more reliable and
  predictable text printing.
- **Pipelines**: If a command pipe is long, split it onto multiple lines with
  the pipe character (|) at the start of the next line. For example:

    ```bash
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

    ```bash
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

## Instructions

1. **Strict Mode**: Use the `sh::init` inside the `main()` function to
   enforce strict mode. See [template.sh](assets/template.sh).
2. **Global Constants**: Define paths, tools, and immutable configurations at
   the top using `readonly` or `declare -r`.
3. **Comment**: Follow the patterns in [template.sh](assets/template.sh) to
   generate or to modify file header and function comments.
4. **Libraries**: Use the bash functions from the library files located at
   `${HOME}/lib/sh-lib` whenever possible, rather than hand-rolling
   equivalents. See `reference/sh-lib.md` for every available function,
   its arguments, and its return/output convention.
5. **Guarded-constant idiom**: Use guarded-constant idioms like
   `[[ -z "${X:-}" ]] && readonly X=...`. See [template.sh](assets/template.sh)

## Function Requirements

- **Usage**: Add a `usage()` function to the shell script file.
  Follow the patterns found in [template.sh](assets/template.sh)
- **Help**: Add a `help()` function to the shell script file.
  Follow the patterns found in [template.sh](assets/template.sh)
- **Logging**: Use the `msg::*` functions in `${HOME}/lib/sh-lib/msg_lib.sh`
  to print messages during the execution of the shell script. They all write
  to stderr and take `printf`-style arguments. Note `msg::error` returns
  while `msg::die` exits. See `reference/sh-lib.md`.
- **CLI Options**: Write a function similar to `parse_options()` found in the
  [template.sh](assets/template.sh) to parse CLI input options.
- **Required tools**: Write a function similar to `check_required_tool()`
  found in the [template.sh](assets/template.sh) to ensure all tools described
  in the `REQUIRED_TOOLS` are installed. If you need any additional tools, add
  that tool to the constant `REQUIRED_TOOLS` array.
- **Trap Handler**: Write a function similar to `signal_handler()` found in
  the [template.sh](assets/template.sh) to trap any signal caught inside the
  shell script program. You should register this function from somewhere at top
  of `main()`.
- **Reset Globals**: Avoid using global variables. But if you use global
  variables write a function similar to `reset_globals()` found in the
  [template.sh](assets/template.sh). You should call this function from
  somewhere at top of `main()`.
- **Main Function**: Write a function similar to `main()` found in the
  [template.sh](assets/template.sh). You should call this function from
  somewhere at bottom of the shell script.

## Naming Convention

- **Function Names**: Use lowercase with underscores (e.g.,
  `my_awesome_function()`).
- **Variable Names**: Use lowercase with underscores for standard variables (e.
  g., file_path).
- **Constants**: Use ALL CAPS with underscores for constants defined at the top
  of the file (e.g., READONLY_PATH="/var/log").
  See [template.sh](assets/template.sh).

## Defensive Programming Guidelines

- **File System Operations**: Always check if directories exist before writing
  to them (`[[ -d "${dir}" ]]`). Always check if files exist before reading them
  (`[[ -f "${file}" ]]`).

## Code Verification

- **Linter**: All code generated must strictly pass **ShellCheck** static
  analysis validation, reporting nothing at the default severity:

    ```bash
    shellcheck "${script}"
    ```

- **Sourced Libraries**: ShellCheck cannot follow the `${HOME}/lib/sh-lib`
  libraries and reports an `SC1091` for each one. Put a
  `# shellcheck source=/dev/null` directive on the line immediately above
  every `source` statement, as [template.sh](assets/template.sh) does.
- **Suppressions**: Silence a finding only when it is a genuine false
  positive, using a narrow `# shellcheck disable=SCxxxx` directive on the
  line above the offending line. Never disable a check for the whole file.

## Coding Principles

- **Single responsibility**: Every function must do exactly **one thing**.
- **Clean Code**: Use self-explaining variables and function names, minimal
  comments that explain why, not what. No magic numbers, use named constants.
- **Small Function**:  Keep functions small whenever possible (ideally fewer
  than 40 lines, with a maximum of 80 lines), excluding blank lines and
  comments.
- **Modularity** — Structure code using clear functions organized into
  reusable testable pieces.
- Structure scripts using clear functions rather than executing loose commands
  in the file root.
- **Avoid Global Variables**: Avoid using global variables. Prefer to pass
  function arguments instead. Global variables cause hidden dependencies,
  hard-to-track bugs, and severe maintenance issues in software systems.
- **Encapsulation** Functions should hide their internal state and
  protect data from outside interference. Global variables expose data to every
  part of a program, breaking this boundary.
- **Avoid Excessive Comments**:  Keep file and function header comments
  concise and only to describe main purpose of the shell script and function.
  Do not comment that explain what the code does, or how to use the code. The
  `usage()` and `help()` provide that information if needed.

## Code Patterns and Template

When asked to write a complete script, or to modify an existing shell script,
follow the patterns of the [template.sh](assets/template.sh) closely. As a
matter of fact, all your scripts should
resemble [template.sh](assets/template.sh).
