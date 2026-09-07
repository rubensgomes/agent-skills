# =============================================================================
# agent-skills
#
# Repository:
#   https://github.com/rubensgomes/agent-skills
#
# This repo is TRUNK-BASED: main is the trunk for current and all future work.
# Work lands on main directly, and a release is a version bump plus an
# annotated tag on main. There are no release branches and nothing is ever
# cut from anywhere else -- RELEASE_PRECHECK enforces it.
#
# Cutting a release:
#   1. Add entries under [Unreleased] in CHANGELOG.md as you work.
#   2. make release-check      see the current version and what each bump costs
#   3. make release-<level>    bump, roll changelog, commit, tag -- ALL LOCAL
#   4. make release-push       push main + the tag, which fires release.yml
#
# Nothing leaves the machine until step 4. Undo step 3 with:
#   git tag -d v<version> && git reset --hard HEAD~1
# =============================================================================

# Release version. The repo-root VERSION file is the single source of truth:
# the git tag is `v$(VERSION)` and the CHANGELOG heading is `[$(VERSION)]`.
#
# Read with `:=` (once, at parse time) rather than `=`, so a recipe that
# rewrites VERSION mid-flight still sees the value the target STARTED with.
# The bump recipes therefore re-read the file in-shell rather than using
# $(VERSION); the variable here is for reporting and for `release-push`.
VERSION     := $(shell cat VERSION 2>/dev/null)
RELEASE_TAG := v$(VERSION)

# Every shell script in the repo. Kept as a variable so `lint` and the release
# workflow cannot drift apart on what they cover.
SHELL_SCRIPTS := $(wildcard bin/*.sh)

.DEFAULT_GOAL := help

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------
# These are the same three checks release.yml runs. Run them locally before
# tagging and CI holds no surprises.

# shellcheck plus a parse under both bash builds. The /bin/bash pass is not
# redundant: on macOS that is bash 3.2, and bin/sync-skills.sh documents a hard
# constraint that it stays parseable there. This is what enforces it.
.PHONY: lint
lint:
	@set -e; \
	 if [ -z "$(SHELL_SCRIPTS)" ]; then echo "no shell scripts to lint"; exit 0; fi; \
	 for f in $(SHELL_SCRIPTS); do \
	   echo "=== LINT $$f ==="; \
	   bash -n "$$f"; \
	   /bin/bash -n "$$f"; \
	   shellcheck "$$f"; \
	 done; \
	 echo "  ok: $(words $(SHELL_SCRIPTS)) script(s) clean"

# Every skills/<dir>/SKILL.md must exist, carry YAML frontmatter with a name
# and a description, and its `name:` must equal its directory name. The name is
# how the skill is invoked, and bin/sync-skills.sh mirrors by directory, so a
# disagreement between the two is a skill that installs under one name and
# answers to another.
.PHONY: check-skills
check-skills:
	@set -e; \
	 _bad=0; _n=0; \
	 for d in skills/*/; do \
	   _dir=$$(basename "$$d"); \
	   _f="$${d}SKILL.md"; \
	   _n=$$((_n + 1)); \
	   if [ ! -f "$$_f" ]; then \
	     echo "ERROR: $$_dir has no SKILL.md" >&2; _bad=1; continue; \
	   fi; \
	   if [ "$$(head -1 "$$_f")" != "---" ]; then \
	     echo "ERROR: $$_f does not start with YAML frontmatter" >&2; _bad=1; continue; \
	   fi; \
	   _name=$$(awk -F': ' '/^name: /{print $$2; exit}' "$$_f"); \
	   if [ -z "$$_name" ]; then \
	     echo "ERROR: $$_f has no 'name:' in its frontmatter" >&2; _bad=1; continue; \
	   fi; \
	   if [ "$$_name" != "$$_dir" ]; then \
	     echo "ERROR: $$_f declares name '$$_name' but lives in '$$_dir'" >&2; _bad=1; continue; \
	   fi; \
	   if ! grep -q '^description: ' "$$_f"; then \
	     echo "ERROR: $$_f has no 'description:' in its frontmatter" >&2; _bad=1; continue; \
	   fi; \
	 done; \
	 if [ "$$_bad" -ne 0 ]; then exit 1; fi; \
	 echo "  ok: $$_n skill(s) valid"

# Everything CI gates on, in one target.
.PHONY: verify
verify: lint check-skills
	@echo "=== VERIFY OK ==="

# -----------------------------------------------------------------------------
# Release: version bump, changelog roll, annotated tag
# -----------------------------------------------------------------------------
# Releases are manual and explicit -- you pick the bump level, nothing is
# inferred from commit messages. `VERSION` is the source of truth; the tag is
# `v$(VERSION)`; the changelog heading derives from it. `make release-check`
# prints the policy and the undo procedure.
#
# The bump targets deliberately stop at the local annotated tag. Pushing is a
# separate, explicit `release-push`, so a mistyped level or a bad changelog
# roll is recoverable with `git tag -d` + `git reset --hard HEAD~1` and never
# escapes the machine.
#
# Portability constraints: no GNU coreutils on macOS. Bump arithmetic is POSIX
# `$((...))` over an `IFS=. read`, not `seq`/`bc`. The changelog is rewritten
# through `awk` into a temp file and `mv`d, never `sed -i` -- BSD `sed -i`
# demands a backup suffix and GNU `sed -i` refuses one, so no single `sed -i`
# invocation works on both this laptop and the ubuntu CI runner.
#
# Every awk program is kept on ONE physical line. A `\`-continuation inside a
# single-quoted awk program would be passed to the shell literally and awk
# would choke on it.
#
# Shared bodies live in `define` variables inlined into the recipes, NOT in
# sub-targets invoked via $(MAKE): a $(MAKE) inside a backslash-continued
# recipe line runs for real under `-n`, and `make -n release-patch` must stay
# an honest dry run.

# Preflight shared by every release target. Read-only: verifies the repo is in
# a fit state to be tagged and exits non-zero otherwise. Deliberately does NOT
# fail on untracked files -- `.idea/`-style noise is not a reason to block a
# release, and everything that will be committed is checked above.
#
# The origin sync check compares against FETCH_HEAD rather than
# `refs/remotes/origin/main`, because `git fetch origin main` does not reliably
# update the remote-tracking ref on every git version. A fetch failure is a
# WARNING, not an error, so the release targets still work offline.
define RELEASE_PRECHECK
echo "=== RELEASE PRECHECK ==="; \
if [ ! -f VERSION ]; then \
  echo "ERROR: VERSION file is missing at the repo root." >&2; exit 1; \
fi; \
_v=$$(cat VERSION); \
case "$$_v" in \
  [0-9]*.[0-9]*.[0-9]*) ;; \
  *) echo "ERROR: VERSION '$$_v' is not MAJOR.MINOR.PATCH." >&2; exit 1;; \
esac; \
case "$$_v" in \
  *[!0-9.]*|*.*.*.*|*..*|.*|*.) \
    echo "ERROR: VERSION '$$_v' is not MAJOR.MINOR.PATCH." >&2; exit 1;; \
esac; \
if ! git diff --quiet || ! git diff --cached --quiet; then \
  echo "ERROR: working tree is dirty. Commit or stash before releasing." >&2; \
  git status --short >&2; \
  exit 1; \
fi; \
_br=$$(git rev-parse --abbrev-ref HEAD); \
if [ "$$_br" != "main" ]; then \
  echo "ERROR: releases are cut from main, not '$$_br'." >&2; \
  echo "  This repo is trunk-based: all work lands on main directly, and a" >&2; \
  echo "  release is a bump + tag on main. See make release-check." >&2; \
  exit 1; \
fi; \
if git fetch --quiet origin main 2>/dev/null; then \
  if ! git merge-base --is-ancestor FETCH_HEAD HEAD; then \
    echo "ERROR: HEAD does not contain origin/main." >&2; \
    echo "  Pull main before releasing." >&2; \
    exit 1; \
  fi; \
else \
  echo "  WARN: could not fetch origin, skipping the sync check"; \
fi; \
echo "  ok: VERSION=$$_v, branch=$$_br, tree clean"
endef

# A bump with an empty [Unreleased] section produces a release note that says
# nothing, which is worse than no release at all. Counts `- ` bullets between
# the [Unreleased] heading and the next version heading.
#
# The `#` characters in these awk patterns survive: make passes `#` through a
# define body verbatim, it is only the makefile's own lines that treat it as a
# comment. Anchoring on the full `^## \[` matters -- the prose at the top of
# CHANGELOG.md mentions `[Unreleased]` inline, and a looser pattern either
# misses the real heading or matches the prose.
define RELEASE_REQUIRE_UNRELEASED
_n=$$(awk '/^## \[Unreleased\]/{f=1;next} f && /^## \[[0-9]/{exit} f && /^- /{c++} END{print c+0}' CHANGELOG.md); \
if [ "$$_n" -eq 0 ]; then \
  echo "ERROR: CHANGELOG.md [Unreleased] has no entries - nothing to release." >&2; \
  exit 1; \
fi; \
echo "  ok: $$_n changelog entrie(s) under [Unreleased]"
endef

# Creates the annotated tag for whatever VERSION currently holds. Re-reads the
# file rather than using $(VERSION), because RELEASE_BUMP rewrites VERSION
# after make has already expanded its variables.
define RELEASE_TAG_BODY
_v=$$(cat VERSION); \
_tag="v$$_v"; \
if git rev-parse -q --verify "refs/tags/$$_tag" >/dev/null; then \
  echo "ERROR: tag $$_tag already exists." >&2; exit 1; \
fi; \
git tag -a "$$_tag" -m "Release $$_tag"; \
echo "=== TAGGED $$_tag ==="; \
echo "  nothing has been pushed. Inspect with 'git show --stat HEAD', then:"; \
echo "    make release-push     publish $$_tag (fires release.yml)"; \
echo "  or undo with:"; \
echo "    git tag -d $$_tag && git reset --hard HEAD~1"; \
echo "  (nothing has left this machine until 'make release-push'.)"
endef

# The bump itself. LEVEL (patch|minor|major) comes from the calling recipe.
# Order matters: every check that can fail runs BEFORE the first write, so a
# rejected release leaves the tree exactly as it found it. That includes the
# full `verify` suite -- a release that fails CI should fail on the laptop.
#
# The changelog roll replaces the `## [Unreleased]` heading with a fresh empty
# [Unreleased] block followed by the new version heading. The old Unreleased
# body is left in place and therefore falls under the new version -- which is
# precisely the Keep a Changelog promotion.
define RELEASE_BUMP
$(RELEASE_PRECHECK); \
$(RELEASE_REQUIRE_UNRELEASED); \
$(MAKE) --no-print-directory verify; \
IFS=. read -r _ma _mi _pa < VERSION; \
case "$$LEVEL" in \
  major) _ma=$$((_ma + 1)); _mi=0; _pa=0;; \
  minor) _mi=$$((_mi + 1)); _pa=0;; \
  patch) _pa=$$((_pa + 1));; \
  *) echo "ERROR: unknown bump level '$$LEVEL'." >&2; exit 1;; \
esac; \
_new="$$_ma.$$_mi.$$_pa"; \
if git rev-parse -q --verify "refs/tags/v$$_new" >/dev/null; then \
  echo "ERROR: tag v$$_new already exists." >&2; exit 1; \
fi; \
echo "=== RELEASE $$LEVEL: $$(cat VERSION) -> $$_new ==="; \
printf '%s\n' "$$_new" > VERSION; \
awk -v ver="$$_new" -v day="$$(date +%F)" 'BEGIN{d=0} /^## \[Unreleased\]/ && !d {print; print ""; print "### Added"; print ""; print "### Changed"; print ""; print "### Fixed"; print ""; print "## [" ver "] - " day; d=1; next} {print}' CHANGELOG.md > CHANGELOG.md.tmp; \
mv CHANGELOG.md.tmp CHANGELOG.md; \
git add VERSION CHANGELOG.md; \
git commit -q -m "release: v$$_new"; \
$(RELEASE_TAG_BODY)
endef

.PHONY: version
version:
	@echo "VERSION file : $(VERSION)"
	@echo "Release tag  : $(RELEASE_TAG)"
	@echo "Latest tag   : $$(git describe --tags --abbrev=0 2>/dev/null || echo '(none yet)')"

.PHONY: release-check
release-check:
	@$(RELEASE_PRECHECK); \
	 $(RELEASE_REQUIRE_UNRELEASED); \
	 IFS=. read -r _ma _mi _pa < VERSION; \
	 echo ""; \
	 echo "  current        v$$_ma.$$_mi.$$_pa"; \
	 echo "  release-patch  v$$_ma.$$_mi.$$((_pa + 1))   wording, docs, same behaviour"; \
	 echo "  release-minor  v$$_ma.$$((_mi + 1)).0   a new skill or a new capability"; \
	 echo "  release-major  v$$((_ma + 1)).0.0   a skill removed/renamed, or a breaking change"

# The three release targets. Each bumps VERSION, rolls the changelog, commits
# and creates the annotated tag -- all LOCALLY. `make release-push` is the
# separate, deliberate step that publishes.
#
# One shot rather than a prep/tag split: this repo is trunk-based, so the
# release commit is made directly on main and its SHA is the SHA that gets
# pushed. Nothing rewrites it between the tag and the push.
.PHONY: release-patch
release-patch:
	@LEVEL=patch; $(RELEASE_BUMP)

.PHONY: release-minor
release-minor:
	@LEVEL=minor; $(RELEASE_BUMP)

.PHONY: release-major
release-major:
	@LEVEL=major; $(RELEASE_BUMP)

# Tag the CURRENT VERSION without bumping it.
#
# An escape hatch, not part of the normal recipe: it only helps when a bump
# committed cleanly but the tag was lost or deleted before it was pushed.
# Requires the changelog to already carry a section for this version, so it
# cannot mint a tag with no release notes behind it -- which also means it
# cannot be used to cut a NEW release ([Unreleased] carries no version
# heading). Use release-<level> for that.
.PHONY: release-tag
release-tag:
	@$(RELEASE_PRECHECK); \
	 _v=$$(cat VERSION); \
	 if ! grep -q "^## \[$$_v\]" CHANGELOG.md; then \
	   echo "ERROR: CHANGELOG.md has no [$$_v] section. Add one, or use release-<level>." >&2; \
	   exit 1; \
	 fi; \
	 $(RELEASE_TAG_BODY)

# Publishes. This is the only release target that talks to the network, and
# the only one that is not undoable -- release.yml fires on the tag.
#
# `git push origin main` comes FIRST and is load-bearing. The release commit
# was made locally on main, so the branch must reach origin before the tag
# does -- push the tag alone and release.yml fires against a commit nobody
# else can see. Both pushes go in one target so the ordering cannot be got
# wrong by hand.
.PHONY: release-push
release-push:
	@_tag="$(RELEASE_TAG)"; \
	 if ! git rev-parse -q --verify "refs/tags/$$_tag" >/dev/null; then \
	   echo "ERROR: no local tag $$_tag. Run 'make release-<level>' first." >&2; exit 1; \
	 fi; \
	 echo "=== PUSH $$_tag ==="; \
	 git push origin main; \
	 git push origin "$$_tag"; \
	 echo "  pushed. Watch: gh run list --workflow=release.yml"

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------

# Install this repo's skills into ~/.claude/skills via the repo's own script.
.PHONY: install
install:
	@bin/sync-skills.sh --source ./skills --verbose

.PHONY: install-dry-run
install-dry-run:
	@bin/sync-skills.sh --source ./skills --verbose --dry-run

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
.PHONY: help
help:
	@echo "agent-skills -- trunk-based on main"
	@echo ""
	@echo "Verify:"
	@echo "  lint             shellcheck + bash 5 and bash 3.2 parse of bin/*.sh"
	@echo "  check-skills     every SKILL.md has frontmatter matching its directory"
	@echo "  verify           both of the above (what release.yml gates on)"
	@echo ""
	@echo "Install:"
	@echo "  install          sync ./skills into ~/.claude/skills"
	@echo "  install-dry-run  show what install would do, change nothing"
	@echo ""
	@echo "Release (see CHANGELOG.md for what counts as which level):"
	@echo "  version          print VERSION, release tag, latest tag"
	@echo "  release-check    preflight + what each bump level would produce"
	@echo "  release-patch    bump patch, roll changelog, commit, tag (LOCAL)"
	@echo "  release-minor    bump minor, roll changelog, commit, tag (LOCAL)"
	@echo "  release-major    bump major, roll changelog, commit, tag (LOCAL)"
	@echo "  release-tag      re-tag the current VERSION (escape hatch)"
	@echo "  release-push     push main + tag, firing release.yml (PUBLISHES)"
