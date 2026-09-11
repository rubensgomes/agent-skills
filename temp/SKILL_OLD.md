---
name: java-spring
description: >-
  A set of guidelines to use when generating, or changing files in Java Spring
  Boot projects.
---

## Overview

Guidelines to be used when creating or modifying files in Java Spring Boot 
projects.

## Instructions

- **Language/Framework**: Java 25 + Spring Boot 4.x
- Limit all Java block comments, line comments, and Javadocs to a maximum
  of 80 characters per line.
- Use constructor injection only for dependencies.
- Avoid using field injection in main source code.
- Use records for immutable DTOs.
- Add a Javadoc header comment to every class, record, interface, and enum.
  The comment should briefly describe the purpose of the file and include the
  author tag:

    ```text
    /**
     * A simple statement that describes the intent of this file.
     *
     * @author Rubens Gomes
     * @implNote Initial implementation was generated with AI assistance and
     * subsequently reviewed and approved by the author.
     */
    ```

- Do not generate Javadoc for private members, getters, setters, constructors
- Do not generate Javadoc for obvious methods. A method is obvious when its
  signature already carries everything the comment would say. Visibility is
  irrelevant -- a private or public method is not exempt.
- Lombok where it is already adopted by the project.
- Use the Lombok @Slf4j annotation for logging.
- Use Java 11+ features (var, records, streams).
- Use Optional for nullable returns instead of null.
- Use Streams and Lambdas for collections.
- Use Enums for fixed constants.
- Use try-with-resources for resource management.
- Do NOT use wildcard imports.
- Use `Objects.requireNonNull()` for null checks.


