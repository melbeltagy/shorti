# github: git workflow helpers

Light shortcuts on top of `git` (and eventually `gh`).

- `gprune`: fetches with `--prune`, then deletes local branches whose remotes were removed (with confirmation)
- `clone`: short alias for `git clone`
- `gs`: `git status`
- `gd`: `git diff`
- `gl`: `git log --oneline -20`

A subcommand dispatcher (e.g. `g status`, `g diff`) may follow once enough commands exist to justify it.

## Prerequisites

- bash
- `git`
