# lxd: `lx`, `lxi`, `lxv`, `lxn`, `lxp` helpers

Short wrappers around `lxc` for everyday LXD ops. All share the same
pattern-filter style as the docker helpers (positional regex args OR'd via `|`).

- **`lx`** containers: `ls`, `bash`, `sh`, `cp`, `rm`, `start`, `stop`, `snap`
  - `lx snap` sub-subcommands: `new`, `ls`, `restore`, `rm`
- **`lxi`** images (`lxc image`): `ls`, `info`, `rm`, `pull`
- **`lxv`** storage volumes (`lxc storage volume`): `ls`, `info`, `rm`, `du`
- **`lxn`** networks (`lxc network`): `ls`, `info`, `rm`, `mk`, `leases`, `conn`, `disc`
- **`lxp`** storage pools (`lxc storage`): `ls`, `info`, `mk`, `rm`

Storage in LXD splits into **pools** (`lxp`) and **volumes** (`lxv`); volumes are
scoped to a pool. There is no ports helper: LXD containers get their own IP on a
bridge, so `lx ls` already shows IPv4/IPv6.

Run `<tool> help` for the full command list with examples (e.g. `lx help`,
`lxi help`, `lxv help`, `lxn help`, `lxp help`).

## Prerequisites

- bash
- `lxc` CLI; LXD installed and the user added to the `lxd` group
