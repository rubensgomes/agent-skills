---
name: ai-license-readme
description: >-
  Adds AI_DISCLAIMER.md and LICENSE files to the provided directory. Then, 
  updates or creates a README.md file with references to these files and Markdown badges.
argument-hint: "<path-to-directory>"
disable-model-invocation: true
---

## Overview

This guide is used to copy the `./AI_DISCLAIMER.md` and `./LICENSE` files to the
directory specified in the argument. Then, it adds "AI Disclaimer" and "License"
sections, along with Markdown badges, at the top of the `README.md` file in that
directory.

## Instructions

1. If no argument is provided, print "Error: directory missing".
2. Ensure that the `$ARGUMENTS` directory exists and is writable.
3. Copy and overwrite, if necessary, the `./AI_DISCLAIMER.md` file to that
   directory.
4. Copy and overwrite, if necessary, the `./LICENSE` file to that directory.
5. Ensure that the directory contains a `README.md` file. If not, create one
   using the `./README_TEMPLATE.md` as a guideline.
6. Ensure that the directory contains a `docs/INITIAL_SETUP.md` file. If not,
   create one copying the `./docs/INITIAL_SETUP.md`.
7. At the top of the README, include Markdown badges and an "AI Disclaimer"
   section like the one in `./README_TEMPLATE.md`. The "AI Disclaimer"
   section must contain the exact same content found in `./README_TEMPLATE`.
8. Near the end of the file, include "Authorship" and "License" sections like
   the ones in `./README_TEMPLATE.md`. The "Authorship" and "License"
   sections must contain the exact same content found in `./README_TEMPLATE`.
9. Update the year in the copied LICENSE file, if necessary.
10. Remove the `NOTICE` file from the project root directory, if present.
11. Update the CHANGELOG.md file if found in that directory.
12. You are done.