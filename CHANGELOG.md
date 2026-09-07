# Changelog

All notable changes to this project are documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/) with **skill-library
semantics**: PATCH for wording fixes, docs, and script changes that keep the
same behaviour; MINOR for a new skill or a genuinely new capability in an
existing skill or script; MAJOR for removing or renaming a skill, or for a
change that breaks how an existing skill or script is invoked. `make
release-check` prints the same three lines against the current `VERSION`.

A rename is MAJOR because `bin/sync-skills.sh` mirrors skill directories by
name: renaming one retires the old directory from every machine that syncs,
moving it to `~/.claude/skills/old/`.

Add entries under `[Unreleased]` as you work. Do not edit the version headings
by hand: `make release-<level>` renames `[Unreleased]` to the new version and
re-seeds an empty `[Unreleased]` block above it.

`[Unreleased]` is for *changes since the last release only*.

This changelog is the **only** place in the repo that records dated history.
Every other document — `README.md`, the skill files, the script headers —
describes how things work, never when they changed. Keep it that way: status
notes rot, and a reader who trusts one reasons from a false premise.

## [Unreleased]

### Added

### Changed

### Fixed

## [0.0.3] - 2026-09-06

### Added

- added ai-disclaimer skill

### Changed

### Fixed

## [0.0.2] - 2026-09-06

### Added

- Added mit-license skill.

### Changed

### Fixed

- Fixed documentation and extra spaces in skill.

## [0.0.1] - 2026-09-06

### Added

- `bin/sync-skills.sh`, a recursive per-file installer that mirrors a source
  skills directory into `~/.claude/skills/`. Overwrites what it manages, moves
  files it no longer recognises to `<dest>/old/` rather than deleting them,
  and prunes the directories that leaves empty. Supports `--source`, `--dest`,
  `--dry-run` and `--verbose`
- `skills/show-understanding`, which asks the agent to read a file and report
  its understanding of it
- `skills/sync-projs/tf.md`, splitting the Terraform-specific synchronisation
  rules out of the main skill so they load only when `.tf` files are present
- Release process: `VERSION`, this changelog, the `make release-*` targets and
  the tag-triggered `release.yml` workflow
- `Makefile`, carrying the release targets plus `verify` (`shellcheck` and a
  bash parse over `bin/*.sh`, and a check that every `SKILL.md` declares a
  `name:` matching its directory) and `install`
- `README.md` sections documenting installing, the trunk-based branching model,
  and how to cut a release

### Changed

- `skills/sync-tf-projs` renamed to `skills/sync-projs`. The skill is no longer
  Terraform-only; its Terraform rules now live in `tf.md` and are read
  conditionally
- `README.md` now points at `rubensgomes/agent-skills` rather than the
  unrelated `rubensgomes-org/azure-iac`

### Fixed

- `skills/sync-projs/SKILL.md` declared `name: sync-tf-projs` after the
  directory rename, so the skill's own name disagreed with its location
