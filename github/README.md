# github: git workflow helpers

Light shortcuts on top of `git` (and eventually `gh`), exposed through a single `g` dispatcher (`g` stands for `git`).

- `g b`: `git branch`
- `g c`: `git clone`
- `g cb`: `git checkout -b`
- `g co`: `git checkout`
- `g d`: `git diff`
- `g f`: `git fetch`
- `g l`: `git log --oneline -20`
- `g p`: `git push`
- `g pl`: `git pull`
- `g prune`: fetches with `--prune`, then deletes local branches whose remotes were removed (with confirmation)
- `g s`: `git status`

Any extra arguments are passed through (e.g. `g co main`, `g p origin main`). Run `g` (or `g help`) with no arguments to print the usage; an unknown subcommand prints an error plus the usage and returns non-zero.

## Prerequisites

- bash
- `git`
