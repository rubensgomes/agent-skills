[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![AI Assisted](https://img.shields.io/badge/AI--Assisted-Development-007ACC?logo=openai&logoColor=white)](./AI_DISCLAIMER.md)

# My AI Agent Skills

This repository serves as a central location for my AI agent skills library. I
use these skills across multiple projects and a variety of tasks. Some skills
are tailored to specific domains, while others focus on technical workflows or
provide general-purpose capabilities.

## AI Disclaimer

This project includes code and documentation created with the assistance of AI
tools. For details on usage, limits, and review practices, please see
the [AI Disclaimer](./AI_DISCLAIMER.md).

## License

The project is licensed under the [MIT License](./LICENSE).

## Installing

`bin/sync-skills.sh` mirrors this repository's `skills/` directory into
`~/.claude/skills/`:

```bash
make install-dry-run   # show what would change, touch nothing
make install           # sync ./skills into ~/.claude/skills
```

Files already installed are overwritten from this repository. Files there that
this repository no longer carries are moved to `~/.claude/skills/old/` rather
than deleted, and the directories that leaves empty are removed. Run
`bin/sync-skills.sh --help` for the full option list.

## Branching

This repository is trunk-based. `main` is the trunk for current and all future
work: changes land on `main` directly, and a release is a version bump plus an
annotated tag on `main`. There are no release branches, and `make release-*`
refuses to run from any other branch.

## Releasing

`VERSION` is the single source of truth. The git tag is `v$(cat VERSION)` and
the [CHANGELOG.md](./CHANGELOG.md) heading is `[$(cat VERSION)]`; the release
workflow refuses to publish unless all three agree.

Record what you change under `[Unreleased]` in `CHANGELOG.md` as you work, then:

```bash
make release-check     # preflight, and what each bump level would produce
make release-patch     # or release-minor / release-major
make release-push      # push main + the tag, firing release.yml
```

`make release-<level>` bumps `VERSION`, promotes `[Unreleased]` to the new
version heading, commits, and creates the annotated tag — all locally. Nothing
leaves the machine until `make release-push`, so a mistake is undone with:

```bash
git tag -d v<version> && git reset --hard HEAD~1
```

The tag push fires
[`release.yml`](./.github/workflows/release.yml), which re-checks that the tag,
`VERSION`, and `CHANGELOG.md` agree, runs `make verify`, and publishes a GitHub
Release whose notes are that version's changelog section.

Run `make help` for every target.

---

Author [Rubens Gomes](https://rubensgomes.com/)
