# Docker network management shortcut

_n_ls() {
  if [ -z "$1" ]; then
    docker network ls --format 'table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}'
    echo "============================================"
    echo "Found $(docker network ls -q | wc -l) networks."
  else
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
    docker network ls --format 'table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}' | grep -E "^NETWORK|$PATTERN"
    echo "============================================"
    echo "Found $(docker network ls --format '{{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}' | grep -cE "$PATTERN") networks."
  fi
}

_n_info() {
  if [ -z "$1" ]; then
    echo "Which network to inspect? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local NETWORKS
  NETWORKS=$(docker network ls --format '{{.Name}}' | grep -E "$PATTERN")
  if [ -z "$NETWORKS" ]; then
    echo "No networks match the pattern."
    return 1
  fi
  while IFS= read -r net; do
    echo "===== Inspecting network: $net ====="
    docker network inspect "$net"
  done <<< "$NETWORKS"
}

_n_rm() {
  if [ -z "$1" ]; then
    echo "Which network to remove? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local NETWORKS
  NETWORKS=$(docker network ls --format '{{.Name}}' | grep -E "$PATTERN")
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
    echo "$NETWORKS" | xargs -r docker network rm
    echo "Networks removed."
  else
    echo "Operation cancelled."
  fi
}

_n_mk() {
  if [ -z "$1" ]; then
    echo "Please specify a network name."
    return 1
  fi
  docker network create "$1"
}

_n_conn() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: n conn <network> <container ...>"
    return 1
  fi
  local NET="$1"
  shift
  for c in "$@"; do
    docker network connect "$NET" "$c"
  done
}

_n_disc() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: n disc <network> <container ...>"
    return 1
  fi
  local NET="$1"
  shift
  for c in "$@"; do
    docker network disconnect "$NET" "$c"
  done
}

_n_prune() {
  read -rp"This will remove all unused networks. Continue? (y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    docker network prune
  else
    echo "Operation cancelled."
  fi
}

_n_help() {
  cat <<'EOF'
Usage: n <command> [pattern ...]
Commands:
  ls   [pattern ...]              List networks (filter optional)
  info [pattern ...]              Inspect one or more networks
  rm   [pattern ...]              Remove one or more networks (with confirmation)
  mk   <name>                     Create a new network
  conn <network> <container ...>  Connect one or more containers to a network
  disc <network> <container ...>  Disconnect one or more containers from a network
  prune                           Remove all unused networks (with confirmation)

Examples:
  n ls
  n ls mynet bridge
  n info mynet
  n rm oldnet tempnet
  n mk devnet
  n conn devnet mycontainer1 mycontainer2
  n disc devnet mycontainer1 mycontainer2
  n prune
EOF
}

function n() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _n_help; return; fi
  _shorti_require docker || return $?
  local CMD="$1"
  shift
  case "$CMD" in
    ls)    _n_ls "$@" ;;
    info)  _n_info "$@" ;;
    rm)    _n_rm "$@" ;;
    mk)    _n_mk "$@" ;;
    conn)  _n_conn "$@" ;;
    disc)  _n_disc "$@" ;;
    prune) _n_prune ;;
    *)     echo "Unknown command: $CMD" >&2; echo "" >&2; _n_help >&2; return 1 ;;
  esac
}
