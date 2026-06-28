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

Any extra arguments are passed through (e.g. `g co main`, `g p origin main`). Unknown subcommands fall through to plain `git`, so `g status` and `g diff --stat` work too. Calling `g` with no arguments runs `git status`.

## Prerequisites

- bash
- `git`
