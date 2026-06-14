# k8s: `k` helper

Single-letter dispatcher over `kubectl` for the verbs you reach for most often.

- Subcommands: `get`, `desc`, `logs` (with `-f`), `tail`, `exec`, `bash`, `sh`, `apply`, `del`, `cp`, `edit`, `pf`, `types`, `ls`, `ns`, `ctx`, `top`, `events`, `restart`

Run `k help` for the full command list with examples. `k ls help` and `k ns help` have their own sub-help.

## Prerequisites

- bash
- `kubectl` configured against a cluster
