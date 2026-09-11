# shorti <!-- omit in toc -->

Terser shell shortcuts for the tools you use daily: Docker, Docker Compose, Kubernetes, LXD, git, and snap. Each tool lives in its own folder with its own README and a single dispatcher function (`d`, `i`, `v`, `n`, `dc`, `k`, `lx`, `lxi`, `lxv`, `lxn`, `lxp`, `sn`, `ds`), alongside a `shell/` folder for system upkeep.

> [!NOTE]
> Every shorti command is a thin shortcut on top of an existing CLI (`docker`, `kubectl`, `lxc`, `git`, `apt`, `snap`, ...). The goal is to type less, not to replace those tools. If you need a flag or behavior that isn't wrapped, drop down to the underlying command.

## Table of Contents <!-- omit in toc -->

- [What's included](#whats-included)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Uninstall](#uninstall)
- [License](#license)

## What's included

- [`compose/`](compose/README.md): `dc` wrapper over `docker compose`
- [`docker/`](docker/README.md): `d` (containers), `i` (images), `v` (volumes), `n` (networks)
- [`github/`](github/README.md): `g` wrapper over `git` (incl. `g prune`)
- [`k8s/`](k8s/README.md): `k` wrapper over `kubectl`
- [`lxd/`](lxd/README.md): `lx` (containers), `lxi` (images), `lxv` (volumes), `lxn` (networks), `lxp` (storage pools) over `lxc`
- [`shell/`](shell/README.md): `sn` (snap: refresh, orphan report, cleanup), `ds` (disk space: usage and cleanup), `aup` (apt + snap system update), plus shared helpers and aliases

Each helper accepts `help` as its first arg (e.g. `d help`, `k help`) and prints its own command list with examples. Run `shorti` to see all available helpers at a glance.

## Prerequisites

- bash 4+ (`dc ls` uses associative arrays)
- `column`, for the aligned tables
- The CLI each helper wraps, with access to whatever it talks to:
  - `docker`, with permission to reach the daemon
  - `kubectl`, configured against a cluster
  - `lxc`, with your user in the `lxd` group
  - `git`
  - `apt`, and optionally `snap`. The `shell/` helpers are Linux only: there is no apt, snap or systemd on macOS.
- Extras specific to one helper: [compose](compose/README.md#prerequisites), [shell](shell/README.md#prerequisites)

## Setup

> [!WARNING]
> Don't blindly pipe scripts from the internet. Before running the one-liner below, review [`install.bash`](install.bash) and [`setup/apply.bash`](setup/apply.bash) so you know what they do to your system. If you'd rather read everything first, use the **Manual clone** path.

### One-liner (convenience)

```bash
curl -fsSL https://raw.githubusercontent.com/melbeltagy/shorti/main/install.bash | bash
```

Clones to `~/shorti` and runs `apply.bash` for you. Override the location with:

```bash
SHORTI_DIR=~/custom/path bash -c "$(curl -fsSL https://raw.githubusercontent.com/melbeltagy/shorti/main/install.bash)"
```

### Manual clone (for the cautious)

```bash
git clone https://github.com/melbeltagy/shorti ~/shorti
~/shorti/setup/apply.bash
```

Both paths end in the same place: the setup is idempotent and uses no hardcoded paths. Clone wherever you like and `setup/apply.bash` figures out its own location. It appends a small marker block to `~/.bashrc` that sources every `<tool>/*.bash` file in the repo. Open a new terminal afterwards (or run `source ~/.bashrc`).

## Uninstall

Delete the block between `# >>> shorti >>>` and `# <<< shorti <<<` in `~/.bashrc`, then open a new terminal.

## License

[MIT](LICENSE). Copyright (c) 2026 Mohamed Elbeltagy.
