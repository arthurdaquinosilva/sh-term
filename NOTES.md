# shtick — notes for later

Snapshot from 2026-11-18 (v0.2.0 plus unreleased changes). This is a working list toward a "production grade" 1.0, most important first.

## State

- The most mature of the family after ember. About 5,900 lines in `src/` and about 1,400 lines of tests. **243 tests pass** locally (50 s). CI runs Ubuntu and macOS on Python 3.10–3.13 with shellcheck, dash and zsh installed, a docs-are-current check and pytest-timeout.
- Only 2 broad `except` handlers. Good discipline.
- Docs: commands (generated), configuration, features, how-it-works, releasing.
- Uncommitted: `src/shtick/theme.py` (pitch palette tweak, same as ember's). Commit it and add it to CHANGELOG "Unreleased".

## 1. Cleanup

- [ ] `BUILD_PROMPT.md` is the original "build this" prompt for Claude. Move it to `docs/design.md` (written as a design doc) or delete it. It looks odd at the root of a public repo.
- [ ] CHANGELOG has two `## Unreleased` headings. Merge them.
- [ ] Remove `twine` from the dev extras (PyPI is gone).
- [ ] Add `pythonpath = ["src"]` to the pytest config so tests never pick up an installed copy.

## 2. Code quality

- [ ] Replace pyflakes with ruff. Add mypy or pyright and `py.typed`.
- [ ] Measure coverage with `pytest-cov`, with a threshold.
- [ ] Add Python 3.14 to CI and the classifiers.

## 3. Safety and correctness (shtick runs arbitrary shell code)

- [ ] `%sandbox` is a working-directory sandbox, not a security boundary (the docstring says so). Make that very visible in the README and in `%sandbox` help. Optionally add a real isolation mode: `bwrap` on Linux, `sandbox-exec` on macOS, or a container when available.
- [ ] Test behaviour when the persistent shell dies, hangs, or is killed (`exit`, `exec`, `kill $$`, endless output). Recovery should be clean, with a clear message.
- [ ] Check which bash, zsh and dash versions are supported (macOS ships bash 3.2) and document them.

## 4. Diagnosability

- [ ] No logging. Add `--debug` / `SHTICK_LOG`, a crash report file and `shtick --doctor` (shell versions, shellcheck present, terminal capabilities).

## 5. Releases and distribution

- [ ] Use one source for the version (it's in both `pyproject.toml` and `__init__.py`).
- [ ] Tag-triggered release workflow (build, attach artifacts, notes from CHANGELOG).
- [ ] `install.sh` should default to the latest tag, not `main`. Publish checksums.
- [ ] Add Dependabot for Actions and a weekly newest-dependencies job.

## 6. Project hygiene

- [ ] Add CONTRIBUTING.md, SECURITY.md, issue and PR templates and pre-commit hooks.
- [ ] Write a stability policy for command names and config keys before 1.0.

## Shared with the family

The pitch palette is copied into each repo, and the release, installer, logging and `--doctor` work is the same across all of them. Solve it once in ember and port it here.
