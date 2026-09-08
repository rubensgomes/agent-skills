---
name: refresh-session
description: >-
  Requests agent to re-read files within the current session working 
  directory changed by the user.
argument-hint: "[file-path ...]"
disable-model-invocation: true
---

## Overview

Use this skill to notify the agent that files in the current session's working
directory have been changed by the user and may need to be re-read.

## Instructions

1. If `$ARGUMENTS` contains file paths, re-read those files before relying on or
   modifying their contents.
2. If `$ARGUMENTS` is empty, re-read files already in context whose contents may
   have changed. If no files have been read this session, state that and stop.
3. Do not discard, overwrite, revert, stage, or commit the user's changes.
4. Briefly acknowledge which files were re-read. If no changed files can be
   identified, state that briefly.
