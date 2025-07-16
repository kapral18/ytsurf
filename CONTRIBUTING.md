# Contributing to ytsurf

First off, thank you for considering contributing to ytsurf! Your help is greatly appreciated.

## How Can I Contribute?

### Reporting Bugs

If you find a bug, please open a [bug report](https://github.com/Stan-breaks/ytsurf/issues/new?template=bug_report.md). Please include:
- A clear and descriptive title.
- Steps to reproduce the bug.
- The expected behavior and what happened instead.
- Your `ytsurf` version and system information.

### Suggesting Enhancements

If you have an idea for a new feature or an improvement, please open a [feature request](https://github.com/Stan-breaks/ytsurf/issues/new?template=feature_request.md).
- Clearly describe the feature and why it would be useful.
- If possible, provide an example of how it might work.

### Submitting Pull Requests

1.  Fork the repository.
2.  Create a new branch for your feature or bug fix: `git checkout -b feature/your-feature-name` or `git checkout -b fix/your-bug-fix`.
3.  Make your changes. Please adhere to the code style guidelines below.
4.  Test your changes to ensure they work as expected and do not break existing functionality.
5.  Commit your changes with a clear and descriptive commit message.
6.  Push your branch to your fork: `git push origin feature/your-feature-name`.
7.  Open a pull request to the `main` branch of the original repository.

## Development

### Setup

- This is a single-file shell script (`ytsurf.sh`). No build command is necessary.
- Ensure you have all the dependencies listed in the `README.md` installed.

### Code Style

- **Linting:** Use `shellcheck` to lint the script before submitting changes:
  ```bash
  shellcheck ytsurf.sh
  ```
- **Formatting:**
  - Use 2 spaces for indentation.
  - Use `[[ ... ]]` for tests.
  - Use `set -euo pipefail` at the beginning of the script.
- **Naming Conventions:**
  - Variables: `snake_case` (e.g., `cache_key`).
  - Constants: `UPPER_CASE` (e.g., `CACHE_DIR`).
- **Error Handling:**
  - The script uses `set -euo pipefail` to exit on errors.
  - Provide clear error messages to `stderr` when applicable.
