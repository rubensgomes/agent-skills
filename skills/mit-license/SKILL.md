---
name: mit-license
description: Adds an MIT license file to the directory provided in the argument
argument-hint: <path-to-directory>
disable-model-invocation: true
---

## Overview

This guide is used to copy the ./LICENSE MIT LICENSE file to the directory
defined by the argument.

## Instructions

1. If no argument is provided, print "Error: directory missing".
2. Ensure that the $ARGUMENTS directory exists and is writeable.
3. If an existing LICENSE file already exists in the directory, compare the
   content of that file with the ./LICENSE.
4. If the content in the LICENSE file in that directory is different make a
   backup of that LICENSE file, and print a warning message.
5. If the content is the same, there is nothing else to do, and you are done.
6. Otherwise, if the content is different copy the ./LICENSE over to that
   directory.
7. Update the year in the copied LICENSE file, if necessary.
8. You should be done now.
