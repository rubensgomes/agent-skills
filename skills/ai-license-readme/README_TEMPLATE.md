[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![AI Assisted](https://img.shields.io/badge/AI--Assisted-Development-007ACC?logo=openai&logoColor=white)](./AI_DISCLAIMER.md)

# azure-iac

Brief description of the project.

## AI Disclaimer

This project includes code and documentation created with the assistance of AI
tools. For details on usage, limits, and review practices, please see
the [AI Disclaimer](./AI_DISCLAIMER.md).

## Installation

To use this project, ensure that your environment is properly configured and
that the required tools are installed.

### Prerequisites

The following prerequisites are required:

- Microsoft Azure account
- An active Azure subscription
- An Azure RBAC role that allows you to create the resources, such as resource
  groups, container registry, container apps, and databases.
- GitHub account
- UNIX-based operating system (for example, AIX, Linux, macOS, or Solaris)
- Azure CLI 2.90+
- Terraform 1.16.0+
- GitHub CLI (`gh`) 2.99+
- Git 2.55+
- GNU Make 3.8+

### Configuration

Follow the steps in the [INITIAL_SETUP](./docs/INITIAL_SETUP.md).

## GitHub Actions

| Workflow                                                 | Purpose                                                      |
|----------------------------------------------------------|--------------------------------------------------------------|
| [`acr-create.yml`](./.github/workflows/acr-create.yml)   | Applies modules 01 → 04 → 06.                                |
| [`acr-destroy.yml`](./.github/workflows/acr-destroy.yml) | Destroys module 06 only.                                     |
| [`main-verify.yml`](./.github/workflows/main-verify.yml) | Checks `terraform` and `workflows` always, `sonar` optional. |
| [`release.yml`](./.github/workflows/release.yml)         | Validates and cuts a release.                                |

## Working on This Project

There are three primary workflows: making a modification, shipping a change and
cutting a release. All the work occur directly on the `main` branch. This
repository follows a trunk-based development model, with no feature branches or
pull requests.

The decision to use a single branch was made to keep the development and
maintenance of the project simple. This approach is appropriate because the
project was originally created by [Rubens Gomes](https://rubensgomes.com) to be
maintained by a single person.

### Starting New Work

Before starting new work, ensure that all required prerequisites are installed.

1. Sync the local `main` branch with the remote repository.

    ```bash
    # Always start from a current main.
    git switch main && git pull
    ````

2. Modify the project as needed.

3. Record the change under [Unreleased] in the `CHANGELOG.md` file accordingly.
   You must have an entry in the `CHANGELOG.md` prior to releasing.

4. Add, commit changes locally.

   ```bash
   # Nothing verifies or triggers a release automatically
   git add -A && git commit
   ```

5. Display the current version and run a preliminary release preflight check.

   ```bash
   # Nothing triggers a release automatically.  Follow Cutting a Release steps. 
   make version && make release-check
   ```

Two things worth knowing:

1. **Pull before you commit, always.** Nothing serializes writers here. `make
  release-check` refuses to run when `HEAD` does not contain `origin/main`, but
   that is a release-time backstop, not day-to-day protection.
2. **Write the `CHANGELOG.md` entry as you go.** `make release-check` refuses to
   cut a release on an empty `[Unreleased]`, so it has to happen eventually —
   and it is far easier now than reconstructed from `git log` at release time.

### Cutting a Release

Follow the steps below to cut a release.

1. Sync the local `main` branch with the remote repository.

    ```bash
    # Current main, and see what each bump level would produce.
    git switch main && git pull
    ````

2. Display the current version and run a release preflight only check reporting
   what each bump would produce.

    ```bash
    make version && make release-check
    ````

3. Bump the [Semantic Version](https://semver.org/) project version, roll
   changelog, commit, tag. Local only.

    ```bash
    # Bump. Applies version, rolls [Unreleased] CHANGELOG into a dated 
    # section, commits,and creates the annotated tag.
    # All local — nothing is pushed.
    make release-patch             # or release-minor / release-major
    ```

   | Level   | Use for                                                       |
   |---------|---------------------------------------------------------------|
   | `patch` | docs and in-place tweaks no caller can observe                |
   | `minor` | new reusable workflows, composite actions, or optional inputs |
   | `major` | anything that breaks a consumer stub                          |

4. Pushes main, then the tag, which fires release.yml.

    ```bash
    make release-push
    ```

**Nothing leaves the machine until step 4**, which is the whole reason the bump
and the push are separate targets. A mistyped level or a bad changelog roll is
undone with `git tag -d v$(cat VERSION) && git reset --hard HEAD~1`.

5. Manually trigger the `release.yml` workflow in the project GitHub repo.

## Authorship

This project was originally created and is maintained by
[Rubens Gomes](https://rubensgomes.com).

The original public repository is available at:

- <https://github.com/rubensgomes-org/azure-iac>

This repository is a derivative copy maintained for experimentation, learning,
and development purposes.

## License

The project is licensed under the [MIT License](./LICENSE).

---
Author:  [Rubens Gomes](https://rubensgomes.com/)
