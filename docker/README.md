# docker: `d`, `i`, `v`, `n` helpers

Tighter shortcuts over `docker container`, `docker image`, `docker volume`, and `docker network`. All four share the same pattern-filter style (positional regex args OR'd via `|`).

- **`d`** containers: `ls`, `lsp`, `mnt`, `bash`, `sh`, `cp`, `tail`, `logs`, `rm`, `start`, `stop`, `restart`, `info`, `stats`, `top`, `pid`, `prune`
- **`i`** images: `ls`, `pull`, `rm`, `info`, `who`, `hist`, `prune`
- **`v`** volumes: `ls`, `rm`, `info`, `who`, `du`, `prune`
- **`n`** networks: `ls`, `info`, `rm`, `mk`, `conn`, `disc`, `prune`

Run `<tool> help` for the full command list with examples (e.g. `d help`, `i help`, `v help`, `n help`).

## Prerequisites

- bash 4+
- `docker` CLI with permission to talk to the daemon
- `column` (for aligned tables in `v who`, `v du`, `d stats`)
