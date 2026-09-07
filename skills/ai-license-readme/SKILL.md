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
5. Ensure the directory contains a `README.md` file that includes at the top the
   Markdown badges, as well as "AI Disclaimer" and "License" sections similar to
   `./README_TEMPLATE.md`.
6. You are done.