---
name: show-understanding
description: Request agent to read the given file and show its understanding.
argument-hint: <path-to-file>
disable-model-invocation: true
---

## Overview

This guide is used to show your understanding of the file provided.

## Instructions

1. If no argument is provided, print "Error: file missing".
2. Ensure that the $ARGUMENTS file exists and is readable.
3. Read the $ARGUMENTS file.
4. Show me your understanding of the file.
