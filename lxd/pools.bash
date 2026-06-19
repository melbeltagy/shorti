# LXD storage pool management shortcut

_lxp_ls() {
  if [ -z "$1" ]; then
    lxc storage list
    echo "============================================"
    echo "Found $(lxc storage list -c n --format csv | wc -l) pools."
  else
    local PATTERN OUT
    PATTERN="$(IFS="|"; echo "$*")"
    OUT="$(lxc storage list)"
    { echo "$OUT" | head -n 3; echo "$OUT" | tail -n +4 | grep -E "$PATTERN"; }
    echo "============================================"
    echo "Found $(lxc storage list -c n --format csv | grep -cE "$PATTERN") pools."
  fi
}

_lxp_info() {
  if [ -z "$1" ]; then
    echo "Which pool to inspect? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local POOLS
  POOLS=$(lxc storage list -c n --format csv | grep -E "$PATTERN")
  if [ -z "$POOLS" ]; then
    echo "No pools match the pattern."
    return 1
  fi
  while IFS= read -r pool; do
    [ -z "$pool" ] && continue
    echo "===== Inspecting pool: $pool ====="
    lxc storage info "$pool"
    lxc storage show "$pool"
  done <<< "$POOLS"
}

_lxp_mk() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: lxp mk <pool> <driver> [key=value ...]"
    return 1
  fi
  lxc storage create "$@"
}

_lxp_rm() {
  if [ -z "$1" ]; then
    echo "Which pool to remove? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local POOLS
  POOLS=$(lxc storage list -c n --format csv | grep -E "$PATTERN")
  if [ -z "$POOLS" ]; then
    echo "No pools match the pattern."
    return 1
  fi
  local COUNT
  COUNT=$(echo "$POOLS" | wc -l)
  echo "Removing the following $COUNT pools:"
  echo "$POOLS"
  echo "Note: a pool with existing volumes cannot be deleted."
  read -rp"Do you want to continue? (y/N)?" confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    while IFS= read -r pool; do
      [ -z "$pool" ] && continue
      echo "Deleting pool: $pool"
      lxc storage delete "$pool"
    done <<< "$POOLS"
  else
    echo "Operation cancelled."
  fi
}

_lxp_help() {
  cat <<'EOF'
Usage: lxp <command> [pattern ...]
Commands:
  ls   [pattern ...]                List storage pools (filter optional)
  info [pattern ...]                Show usage and config for one or more pools
  mk   <pool> <driver> [key=val..]  Create a new storage pool
  rm   [pattern ...]                Delete one or more pools (with confirmation)

Notes:
  Storage volumes live under 'lxv', not here. A pool that still holds
  volumes cannot be deleted; remove its volumes first ('lxv rm').

Examples:
  lxp ls
  lxp ls default
  lxp info default
  lxp mk fast dir
  lxp mk pool1 zfs size=20GB
  lxp rm oldpool
EOF
}

function lxp() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _lxp_help; return; fi
  _shorti_require lxc || return $?
  local CMD="$1"
  shift
  case "$CMD" in
    ls)   _lxp_ls "$@" ;;
    info) _lxp_info "$@" ;;
    mk)   _lxp_mk "$@" ;;
    rm)   _lxp_rm "$@" ;;
    *)    echo "Unknown command: $CMD" >&2; echo "" >&2; _lxp_help >&2; return 1 ;;
  esac
}
