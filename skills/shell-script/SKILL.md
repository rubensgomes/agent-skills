---
name: shell-script
description: >-
  A set of guidelines to use when generating or modifying a bash shell script.
---

## Overview

Use the guidelines below when generating or modifying bash shell scripts.

## Instructions

1. **Strict Mode**: Use the `sh::init` inside the `main()` function to
   enforce strict mode. See `template/template.sh`.
2. **Global Constants**: Define paths, tools, and immutable configurations at
   the top using `readonly` or `declare -r`.
3. **Comment**: Follow the patterns in `template/template.sh` to generate or
   to modify file header and function comments.
4. **Libraries**: Use the bash functions from library files located at
   `${HOME}/lib/sh-lib` whenever possible.
5. **Guarded-constant idiom**: Use guarded-constant idioms like
   `[[ -z "${X:-}" ]] && readonly X=...`. See `template/template.sh`

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
- **Global Variables**: Should be named starting with "g_" (e.g.,
  `g_is_dry_run`). See `template/template.sh`, and they should be declared
  at the top of the file before all the function declarations.
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

## Function Requirements

- **Usage**: Always add a `usage()` function to the shell script file.
  Follow the patterns found in `template/template.sh`
- **Help**: Always add a `help()` function to the shell script file.
  Follow the patterns found in `template/template.sh`
- **Logging**: Use the functions in `${HOME}/lib/sh-lib/msg_lib.sh` to
  print messages during the execution of the shell script.
- **CLI Options**: Write a function similar to `parse_options()` found in the
  `template/template.sh` to parse CLI input options.
- **Required tools**: Write a function similar to `check_required_tool()`
  found in the `template/template.sh` to ensure all tools described in the
  `REQUIRED_TOOLS` are installed. If you need any additional tools, add that
  tool to the constant `REQUIRED_TOOLS` array.
- **Trap Handler**: Write a function similar to `signal_handler()` found in
  the `template/template.sh` to trap any signal caught inside the shell script
  program. You should register this function from somewhere at top of `main()`.
- **Reset Globals**: Write a function similar to `reset_globals()` found in
  the `template/template.sh`. You should call this function from
  somewhere at top of `main()`.
- **Main Function**: Write a function similar to `main()` found in the
  `template/template.sh`. You should call this function from somewhere at bottom
  of the shell script.

## Naming Convention

- **Function Names**: Use lowercase with underscores (e.g.,
  `my_awesome_function()`).
- **Variable Names**: Use lowercase with underscores for standard variables (e.
  g., file_path).
- **Constants**: Use ALL CAPS with underscores for constants defined at the top
  of the file (e.g., READONLY_PATH="/var/log"). See `template/template.sh`.

## Defensive Programming Guidelines

- **File System Operations**: Always check if directories exist before writing
  to them (`[[ -d "${dir}" ]]`). Always check if files exist before reading them
  (`[[ -f "${file}" ]]`).

## Code Verification

- **Linter**: All code generated must strictly pass **ShellCheck** static
  analysis validation.

## Code Patterns and Template

When asked to write a complete script, or to modify an existing shell script,
follow the patterns of the `template/template.sh` closely. As a matter of
fact, all your scripts should resemble `template/template.sh`.
