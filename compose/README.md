# compose: `dc` helper

Thin wrappers around `docker compose` with a shared, pattern-friendly arg style for profiles and services.

- Subcommands: `ls`, `ps`, `up`, `stop`, `down`, `pull`, `build`, `logs`, `tail`
- Args prefixed with `:` are **profile-name regex patterns** (e.g. `:dev`)
- Other args are **service-name regex patterns**
- Multiple patterns are OR'd via `|`

Run `dc help` for the full command list with examples.

## Prerequisites

- bash 4+
- `docker` CLI with the `compose` plugin
- A `docker-compose.yml` / `compose.yaml` in the directory where you run the command(s)
