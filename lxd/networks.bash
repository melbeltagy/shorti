# LXD network management shortcut

_lxn_ls() {
  if [ -z "$1" ]; then
    lxc network list
    echo "============================================"
    echo "Found $(lxc network list -c n --format csv | wc -l) networks."
  else
    local PATTERN OUT
    PATTERN="$(IFS="|"; echo "$*")"
    OUT="$(lxc network list)"
    { echo "$OUT" | head -n 3; echo "$OUT" | tail -n +4 | grep -E "$PATTERN"; }
    echo "============================================"
    echo "Found $(lxc network list -c n --format csv | grep -cE "$PATTERN") networks."
  fi
}

_lxn_info() {
  if [ -z "$1" ]; then
    echo "Which network to inspect? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local NETWORKS
  NETWORKS=$(lxc network list -c n --format csv | grep -E "$PATTERN")
  if [ -z "$NETWORKS" ]; then
    echo "No networks match the pattern."
    return 1
  fi
  while IFS= read -r net; do
    [ -z "$net" ] && continue
    echo "===== Inspecting network: $net ====="
    lxc network show "$net"
  done <<< "$NETWORKS"
}

_lxn_rm() {
  if [ -z "$1" ]; then
    echo "Which network to remove? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local NETWORKS
  NETWORKS=$(lxc network list -c n --format csv | grep -E "$PATTERN")
  if [ -z "$NETWORKS" ]; then
    echo "No networks match the pattern."
    return 1
  fi
  local COUNT
  COUNT=$(echo "$NETWORKS" | wc -l)
  echo "Removing the following $COUNT networks:"
  echo "$NETWORKS"
  read -rp"Do you want to continue? (y/N)?" confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    while IFS= read -r net; do
      [ -z "$net" ] && continue
      echo "Deleting network: $net"
      lxc network delete "$net"
    done <<< "$NETWORKS"
    echo "Networks removed."
  else
    echo "Operation cancelled."
  fi
}

_lxn_mk() {
  if [ -z "$1" ]; then
    echo "Usage: lxn mk <name> [key=value ...]"
    return 1
  fi
  lxc network create "$@"
}

_lxn_leases() {
  if [ -z "$1" ]; then
    echo "Which network's leases? Specify a network name."
    return 1
  fi
  lxc network list-leases "$1"
}

_lxn_conn() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: lxn conn <network> <container ...>"
    return 1
  fi
  local NET="$1"
  shift
  for c in "$@"; do
    lxc network attach "$NET" "$c"
  done
}

_lxn_disc() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: lxn disc <network> <container ...>"
    return 1
  fi
  local NET="$1"
  shift
  for c in "$@"; do
    lxc network detach "$NET" "$c"
  done
}

_lxn_help() {
  cat <<'EOF'
Usage: lxn <command> [pattern ...]
Commands:
  ls     [pattern ...]              List networks (filter optional)
  info   [pattern ...]              Show config for one or more networks
  rm     [pattern ...]              Delete one or more networks (with confirmation)
  mk     <name> [key=value ...]     Create a new network
  leases <network>                  List DHCP leases for a network
  conn   <network> <container ...>  Attach a network device to containers
  disc   <network> <container ...>  Detach a network device from containers

Examples:
  lxn ls
  lxn ls lxdbr mynet
  lxn info lxdbr0
  lxn rm oldnet tempnet
  lxn mk devnet ipv6.address=none
  lxn leases lxdbr0
  lxn conn devnet mycontainer1 mycontainer2
  lxn disc devnet mycontainer1 mycontainer2
EOF
}

function lxn() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _lxn_help; return; fi
  _shorti_require lxc || return $?
  local CMD="$1"
  shift
  case "$CMD" in
    ls)     _lxn_ls "$@" ;;
    info)   _lxn_info "$@" ;;
    rm)     _lxn_rm "$@" ;;
    mk)     _lxn_mk "$@" ;;
    leases) _lxn_leases "$@" ;;
    conn)   _lxn_conn "$@" ;;
    disc)   _lxn_disc "$@" ;;
    *)      echo "Unknown command: $CMD" >&2; echo "" >&2; _lxn_help >&2; return 1 ;;
  esac
}
