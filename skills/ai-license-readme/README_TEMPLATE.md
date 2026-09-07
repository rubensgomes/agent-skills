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
  gorups, container registry, container apps, and databases.
- GitHub account
- UNIX-based operating system (for example, AIX, Linux, macOS, or Solaris)
- Azure CLI 2.90+
- Terraform 1.16.0+
- GitHub CLI (`gh`) 2.99+
- Git 2.55+
- GNU Make 3.8+

### Configutation

Follow the steps in the [INITIAL_SETUP](./docs/INITIAL_SETUP.md).

## GitHub Actions

| Workflow                                                 | Shows in Actions as        | What it does                                                 |
|----------------------------------------------------------|----------------------------|--------------------------------------------------------------|
| [`acr-create.yml`](./.github/workflows/acr-create.yml)   | **ACR Create (reusable)**  | Applies modules 01 → 04 → 06.                                |
| [`acr-destroy.yml`](./.github/workflows/acr-destroy.yml) | **ACR Destroy (reusable)** | Destroys module 06 only.                                     |
| [`main-verify.yml`](./.github/workflows/main-verify.yml) | **Main Verify**            | Checks `terraform` and `workflows` always, `sonar` optional. |
| [`release.yml`](./.github/workflows/release.yml)         | **Release (tag push)**     | Validates and cuts a release.                                |

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

Prior to starting new work you need to ensure that you have the minimum tools in
`Prerequisites` installed.

- Follow the steps below:

  ```bash
  # 1. Always start from a current main.
  git switch main && git pull
  
  # 2. Do your work. Before committing, run what the CI checks will run:
  make fmt          # rewrites; the CI check is fmt -check and will fail on drift
  make validate     # all module roots, no cloud calls
  
  # 3. Record the change under [Unreleased] in CHANGELOG.md.  You must have an 
  #    entry in the CHANGELOG prior to releasing.
  
  # 4. Then commit.
  git add -A && git commit
  
  # 5. Push. Nothing verifies this automatically — step 2 was the gate.
  git push origin main
  
  # 6. Optional: run the same three checks in CI against the pushed commit.
  gh workflow run main-verify.yml --ref main && gh run watch
  #    Add -f run_sonar=true to include the SonarCloud scan (off by default).
  ```

Two things worth knowing:

1. **Pull before you commit, always.** Nothing serializes writers here. `make
  release-check` refuses to run when `HEAD` does not contain `origin/main`, but
   that is a release-time backstop, not day-to-day protection.
2. **Write the `CHANGELOG.md` entry as you go.** `make release-check` refuses to
   cut a release on an empty `[Unreleased]`, so it has to happen eventually —
   and it is far easier now than reconstructed from `git log` at release time.

### Cutting a Release

A release does the following steps:

1. bumps the project [Semantic Version](https://semver.org/).
2. rolls the CHANGELOG
3. commits and tags
4. then publishes

- Follow the steps below:

  ```bash
  # 1. Current main, and see what each bump level would produce.
  git switch main && git pull
  make version && make release-check
  
  # 2. Bump. Applies version, rolls [Unreleased] CHANGELOB into a dated 
  # section, commits,and creates the annotated tag.
  # All local — nothing is pushed.
  make release-patch             # or release-minor / release-major
  
  # 3. Publish. Pushes main, then the tag, which fires release.yml.
  make release-push
  ```

**Nothing leaves the machine until step 3**, which is the whole reason the bump
and the push are separate targets. A mistyped level or a bad changelog roll is
undone with `git tag -d v$(cat VERSION) && git reset --hard HEAD~1`.

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
