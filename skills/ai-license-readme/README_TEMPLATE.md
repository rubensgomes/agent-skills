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

| Workflow          | Purpose                                                                                                 |
|-------------------|---------------------------------------------------------------------------------------------------------|
| `acr-create.yml`  | apply modules 01 → 04 → 06 so a registry exists and is writable                                         |
| `acr-destroy.yml` | **destructive** — destroy module 06 only, the registry and every image in it                            |
| `destroy-all.yml` | **destructive** — destroy the whole estate, modules 12 → 01; plans only unless `dry_run` is cleared     |
| `main-verify.yml` | manual checks on `main` — `terraform` and `workflows` always, `sonar` when `run_sonar` is true          |
| `release.yml`     | fires on a `v*.*.*` tag push — validate the tag against `VERSION` + `CHANGELOG.md`, publish the release |

## Development Workflow

See [DEVELOPMENT_WORKFLOW](./docs/DEVELOPMENT_WORKFLOW.md) for guidance on
developing, and cutting a release on this project.

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
