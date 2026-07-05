# github: git workflow helpers

`g` is `git` with a couple of power-ups: every subcommand passes straight through to `git` (so `g status`, `g branch`, `g rebase -i`, `g push origin main` all work exactly like their `git` equivalents), except for two overrides that add value:

- `g l`: `git log --oneline -20` (short, recent log)
- `g prune`: fetches with `--prune`, then deletes local branches whose remotes were removed (with confirmation)

Everything else is just `git`, so there are no abbreviations to memorize or keep in sync.

## Prerequisites

- bash
- `git`
