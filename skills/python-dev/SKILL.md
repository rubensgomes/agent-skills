---
name: python-dev
description: >-
  Creates, edits, formats, and reviews files in a Python project.
---

## Python-Specific Guidelines

**Formatting & Style:**
- Use Black for auto-formatting
- Follow PEP8 standards

**Code Organization:**
- Follow Poetry standard layout
- Source in `src/`
- Tests in `tests/`
- Feature-based organization
- Avoid large monolithic modules

**Language Best Practices:**
- Use Pydantic models for DTOs
- Use async/await for I/O operations
- Type hints everywhere
- Raise meaningful exceptions, not None
- Use f-strings for formatting
- Use `is`/`is not` for None checks
- Use `with` for file operations
- Use `pathlib` instead of `os.path`
- Avoid wildcard imports
- Use `enumerate()` over `range(len())`
- Run `poetry run flake8 src/ tests/` to lint your code

**Testing Requirements:**
- Use pytest framework
- Mirror src/ structure in tests/
- Use pytest fixtures for setup/teardown
- Use pytest-cov for coverage
- Mock only external dependencies (DB, APIs)
- Use pytest-mock for mocking
- Test behavior, not implementation
- Use @pytest.mark.parametrize for multiple inputs
- Keep tests small, focused, fast
- Test success and failure scenarios
- Aim for 80%+ coverage
- Clear test names
- Test edge cases and error handling
