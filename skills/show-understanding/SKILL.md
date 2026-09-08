---
name: show-understanding
description: >-
  Requests the agent to read the specified file and demonstrate 
  its understanding.
argument-hint: "[file-path]"
disable-model-invocation: true
---

## Overview

This guide is used to demonstrate understanding of the specified file.

## Instructions

1. If no argument is provided, print "Error: file missing".
2. Ensure that the `$ARGUMENTS` file exists and is readable.
3. Read the `$ARGUMENTS` file.
4. Provide a clear summary demonstrating your understanding of the file content.