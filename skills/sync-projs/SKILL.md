---
name: sync-projs
description: >-
  Synchronize this project working directory with a source 
  project directory provided as an argument.
argument-hint: "[path-to-source-project-dir]"
disable-model-invocation: true
---

## Overview

This guide covers the synchronization of text files in the current project
working directory with a similar source project found in the directory provided
in the argument. If you encounter Terraform files (e.g., files ending with the
`.tf` extension) in this project, read `./tf.md` and follow the instructions
there as well.

## Instructions

1. If no argument is provided, print "Error: source project directory missing".
2. Ensure that the `$ARGUMENTS` folder exists and is readable.
3. Create a plan first and ask the user for approval. Present the plan as three
   separate lists—files to add, files to change, and files to remove—plus any
   conflicts found. Make no changes until the user approves the plan.
4. Print an error message and stop if an error occurs executing this skill.
5. Except for the first word followed by a dash ("-"), the basenames of this
   project directory and the `$ARGUMENTS` directory should be equal. If they are
   not equal, print an error message and stop.
6. Only text files should be compared and synchronized.
7. Any binary files should be skipped.
8. Do NOT make any modifications to the source `$ARGUMENTS` project.
9. If this project contains a `.gitignore` in the root directory, use that file
   to skip files using the `git check-ignore` rules.
10. Do NOT compare a file named `CHANGELOG.md` found in the root folder of this
    project.
11. Do NOT compare a file named `VERSION` found in the root folder of this
    project.
12. Keep and maintain this project's current version. Change the version of this
    project only when cutting a new release.
13. Do NOT change `ALLOWED_ACTORS`.
14. Do NOT change the default ACR name found in GitHub workflow files.
15. Skip any directory or subdirectory that starts with `.terraform`.
16. Skip any directory or subdirectory that starts with `.git`.
17. Compare files by content, never by file modification time. Treat a file as
    changed only when its contents differ.
18. Add to this project any file present in the source project but absent from
    this project.
19. A file present in this project but absent from the source project is
    ambiguous: it may have been removed from the source project, or added to
    this project and never present in the source. In this case, prompt the user
    to decide.
20. When you are done syncing this project, stop there. Do not run any other
    commands afterward.