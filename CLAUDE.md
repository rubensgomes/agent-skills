**This file is read-only.** Never edit it as a side effect of other work.

Store durable facts in `docs/` and dated changes in `CHANGELOG.md`.

## Documentation Rules

Follow these rules when creating or modifying Markdown documentation or source
code comments, including comments in YAML, Java, Python, and Bash files.

### Prioritize Brevity

- Keep documentation concise and focused. Avoid adjacent topics, anticipated
  follow-up questions, unrequested rationale, and redundant information.
- Write the shortest documentation that correctly conveys the required
  information.
- Make the smallest change that preserves correctness and clarity. Prefer
  deleting unnecessary content over rewording it.
- Add or modify documentation only when explicitly requested or required to
  keep existing documentation accurate.
- Do not add explanatory prose, historical context, motivation, background, or
  implementation details unless explicitly requested or required to document
  behavior, constraints, or breaking changes.
- Do not restate information that is already clear from the code,
  configuration, headings, or examples.

### Avoid Documentation Bloat

When editing existing documentation:

- Match the document's existing level of detail.
- Prefer modifying existing content over adding paragraphs or sections.
- Do not increase the document's length unless required to document new
  functionality, preserve correctness, or resolve ambiguity.
- Do not add sections such as "Overview," "Background," "Additional Notes," or
  "Best Practices" unless explicitly requested.
- Do not duplicate information from other sections.

### Keep Lists Short

- Prefer three to five bullets per list.
- Remove redundant bullets.
- Communicate one idea per bullet.

### Document Code Intentionally

- Prefer self-documenting code over comments.
- Document behavior, constraints, inputs, outputs, and caveats only when they
  are not clear from the code.
- Document design patterns only when they are important for maintenance and
  are not apparent from the code.
- Remove redundant or outdated comments when modifying related code.
- Do not add comments that merely restate the code.

## Planning

- Before implementing multi-file or architectural changes, create a concise
  plan in `misc/tasks`.
- Plans in `misc/tasks` are exempt from the requirement that documentation
  changes must be explicitly requested.
- Apply these documentation rules to plans.
- Obtain user approval before implementing the plan.

## Summaries

- Keep summaries focused, specific, concise, and free of redundancy.
- Default to a high-level summary unless details are requested.

## Coding Principles

- Apply SOLID and Clean Code principles where appropriate.
- Keep functions small, focused, and easy to understand. Prefer readability
  over strict line-count limits.
- Use descriptive names. Avoid non-standard or unclear abbreviations.
- Avoid global variables and static mutable state.
- Never silently swallow exceptions.
- Avoid deep nesting. Prefer early returns when they improve readability.
- Replace magic values with clearly named constants.
- Prefer immutability and pure functions where practical.
- Follow the DRY principle, but do not introduce abstractions prematurely.
- Follow the KISS principle. Prefer the simplest correct solution.
- Address root causes rather than symptoms when practical.
- Write meaningful log messages that include relevant context.