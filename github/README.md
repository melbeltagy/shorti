# github: git workflow helpers

Light shortcuts on top of `git` (and eventually `gh`).

- `gprune`: fetches with `--prune`, then deletes local branches whose remotes were removed (with confirmation)
- `gb`: `git branch`
- `gc`: `git clone`
- `gcb`: `git checkout -b`
- `gco`: `git checkout`
- `gd`: `git diff`
- `gf`: `git fetch`
- `gl`: `git log --oneline -20`
- `gp`: `git push`
- `gpl`: `git pull`
- `gprn`: alias for `gprune`
- `gs`: `git status`

A subcommand dispatcher (e.g. `g status`, `g diff`) may follow once enough commands exist to justify it.

## Prerequisites

- bash
- `git`
