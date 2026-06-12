# Docker network management shortcut

_n_ls() {
  if [ -z "$1" ]; then
    docker network ls --format 'table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}'
    echo "============================================"
    echo "Found $(docker network ls -q | wc -l) networks."
  else
    local PATTERN="$(IFS="|"; echo "$*")"
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
  local PATTERN="$(IFS="|"; echo "$*")"
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
  local PATTERN="$(IFS="|"; echo "$*")"
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
  read -p "Do you want to continue? (y/N)?" confirm
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
  read -p "This will remove all unused networks. Continue? (y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    docker network prune
  else
    echo "Operation cancelled."
  fi
}

function n() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: n <command> [pattern ...]"
    echo "Commands:"
    echo "  ls   [pattern ...]              List networks (filter optional)"
    echo "  info [pattern ...]              Inspect one or more networks"
    echo "  rm   [pattern ...]              Remove one or more networks (with confirmation)"
    echo "  mk   <name>                     Create a new network"
    echo "  conn <network> <container ...>  Connect one or more containers to a network"
    echo "  disc <network> <container ...>  Disconnect one or more containers from a network"
    echo "  prune                           Remove all unused networks (with confirmation)"
    echo ""
    echo "Examples:"
    echo "  n ls"
    echo "  n ls mynet bridge"
    echo "  n info mynet"
    echo "  n rm oldnet tempnet"
    echo "  n mk devnet"
    echo "  n conn devnet mycontainer1 mycontainer2"
    echo "  n disc devnet mycontainer1 mycontainer2"
    echo "  n prune"
    return
  fi

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
    *)     echo "Unknown command: $CMD. Use 'n help' for usage."; return 1 ;;
  esac
}
