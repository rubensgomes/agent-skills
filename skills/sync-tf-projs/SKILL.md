---
name: sync-tf-projs
description: Synchronize this Terraform project with a source project whose folder path is provided as an argument.
argument-hint: <path-to-source-project-dir>
disable-model-invocation: true
---

## Synchronization Guidelines:

1. If no argument is provided, print "Error: source project directory missing".
2. Ensure that the $ARGUMENTS folder exists and is readable.
3. Create a plan first and ask the user for approval. Present the plan as three
   separate lists — files to add, files to change, and files to remove — plus
   any conflicts found. Make no changes until the user approves the plan.
4. Print an error message and stop if an error occurs executing this skill.
5. Except for the first word followed by a dash "-", the basenames of this
   project directory and the $ARGUMENTS directory should be equal. If they are
   not equal print an error message and stop.
6. Only text files should be compared and sync'ed.
7. Any binary files should be skipped.
8. Do NOT make any modifications to the source $ARGUMENTS project.
9. If this project contains a '.gitignore' in the root directory, use that file
   to skip files using the git check-ignore rules.
10. Do NOT compare a file named CHANGELOG.md found in the root folder of this
    project.
11. Do NOT compare a file named VERSION found in the root folder of this
    project.
12. Keep and maintain this project's current version. Change the version on this
    project only when cutting a new release.
13. Do NOT change the values of any of the following variables or parameters
    that appear in this project:
    - TF_VAR_backend_resource_group_name
    - TF_VAR_storage_account_id
    - TF_VAR_container_name
    - TF_VAR_acr_name
    - TF_VAR_action_group_email
    - TF_VAR_owner
    - TF_VAR_prefix
    - TF_VAR_rg_suffix
14. Do NOT change the ALLOWED_ACTORS.
15. Do NOT change the default ACR name found in GitHub workflow files.
16. Skip any directory or subdirectory that starts with '.terraform'
17. Skip any directory or subdirectory that starts with '.git'
18. Compare files by content, never by file modification time. Treat a file as
    changed only when its contents differ.
19. Add to this project any file present in the source project but absent from
    this project.
20. A file present in this project but absent from the source project is
    ambiguous: it may have been removed from the source project, or added to
    this project and never present in the source. In this case prompt question
    for the user to decide.
21. When you are done syncing this project, stop there. Do not run any other
    commands afterward.
