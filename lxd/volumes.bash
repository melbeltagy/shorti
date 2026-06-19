# LXD storage volume management shortcut
#
# Storage volumes are scoped to a pool (lxc storage volume ... <pool>). With no
# pool argument these helpers operate across every pool; pass a pool name to
# scope to one. Pool-level operations (create/delete pools) live in 'lxp'.

# Echo the list of pools, one per line.
_lxv_pools() {
  lxc storage list -c n --format csv
}

_lxv_ls() {
  local POOL="$1"
  shift 2>/dev/null
  local POOLS
  if [ -n "$POOL" ]; then
    POOLS="$POOL"
  else
    POOLS=$(_lxv_pools)
  fi
  local TOTAL=0
  while IFS= read -r pool; do
    [ -z "$pool" ] && continue
    echo "===== Volumes in pool: $pool ====="
    lxc storage volume list "$pool"
    TOTAL=$((TOTAL + $(lxc storage volume list "$pool" -c n --format csv | wc -l)))
  done <<< "$POOLS"
  echo "============================================"
  echo "Found $TOTAL volumes."
}

_lxv_info() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: lxv info <pool> <volume>"
    return 1
  fi
  echo "===== Inspecting volume: $1/$2 ====="
  lxc storage volume info "$1" "$2"
  lxc storage volume show "$1" "$2"
}

_lxv_rm() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: lxv rm <pool> <volume ...>"
    return 1
  fi
  local POOL="$1"
  shift
  local VOLS=("$@")
  echo "Removing the following ${#VOLS[@]} volumes from pool '$POOL':"
  printf '%s\n' "${VOLS[@]}"
  read -rp"Do you want to continue? (y/N)?" confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    for vol in "${VOLS[@]}"; do
      echo "Deleting volume: $POOL/$vol"
      lxc storage volume delete "$POOL" "$vol"
    done
    echo "Volumes removed."
  else
    echo "Operation cancelled."
  fi
}

_lxv_du() {
  local POOL="$1"
  local POOLS
  if [ -n "$POOL" ]; then
    POOLS="$POOL"
  else
    POOLS=$(_lxv_pools)
  fi
  while IFS= read -r pool; do
    [ -z "$pool" ] && continue
    echo "===== Disk usage in pool: $pool ====="
    lxc storage volume list "$pool" -c ntU
  done <<< "$POOLS"
}

_lxv_help() {
  cat <<'EOF'
Usage: lxv <command> [args ...]
Commands:
  ls   [pool]                List volumes (all pools, or one pool)
  info <pool> <volume>       Show state and config for a volume
  rm   <pool> <volume ...>   Delete one or more volumes (with confirmation)
  du   [pool]                Show volume type, name and disk usage per pool

Notes:
  Volumes are scoped to a pool, so info/rm need the pool name. Storage pool
  operations (creating/deleting pools) live in 'lxp'.

Examples:
  lxv ls
  lxv ls default
  lxv info default myvol
  lxv rm default oldvol tempvol
  lxv du default
EOF
}

function lxv() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _lxv_help; return; fi
  _shorti_require lxc || return $?
  local CMD="$1"
  shift
  case "$CMD" in
    ls)   _lxv_ls "$@" ;;
    info) _lxv_info "$@" ;;
    rm)   _lxv_rm "$@" ;;
    du)   _lxv_du "$@" ;;
    *)    echo "Unknown command: $CMD" >&2; echo "" >&2; _lxv_help >&2; return 1 ;;
  esac
}
