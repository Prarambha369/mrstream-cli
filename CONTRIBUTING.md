# Contributing to MrStream-Cli

We welcome contributions! Whether it's a bug fix, a new feature, or a new source plugin, your help is appreciated.

## Getting Started
1. Fork the repository and clone it locally.
2. Install development dependencies: `bats` and `shellcheck`.
3. Ensure the `mrstream doctor` command passes.

## Development Guidelines

### 1. POSIX Compliance
All shell scripts must be compatible with `sh` (POSIX). Avoid "bashisms" like `[[ ]]` (use `[ ]`), `local` (use variables carefully), or arrays. Run `shellcheck` on all scripts before submitting.

### 2. Plugin Development
When adding a new source plugin:
- Create a new file in `src/plugins/your_source.sh`.
- Implement `plugin_fetch`, `plugin_parse`, and `plugin_resolve`.
- `plugin_parse` should output data in the format: `Time|Title|Channel|URL`.
- All plugins **MUST** include the non-affiliation header from `templates/ETHICAL_HEADER.txt`.
- Do NOT hardcode stream URLs.

### 3. Testing
- Add new tests in the `tests/` directory using the `bats` framework.
- Existing tests must pass: `bats tests/`.
- Verify your changes with `shellcheck mrstream src/**/*.sh`.

### 4. Pull Request Process
1. Create a new branch for your feature or fix.
2. Write clear, concise commit messages.
3. Update the `CHANGELOG.md` with your changes.
4. Submit the PR and wait for review.

## Ethical Guidelines
Please respect the guidelines in `DISCLAIMER.md`. This tool is for personal use and should not be used for mass distribution of copyrighted content.
