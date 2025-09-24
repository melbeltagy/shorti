# Docker network management shortcut

function n() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: n <command> [pattern ...]"
    echo "Commands:"
    echo "  ls [pattern ...]                List all networks (optionally filter by one or more patterns)"
    echo "  inspect [pattern ...]           Inspect one or more networks"
    echo "  rm [pattern ...]                Remove one or more networks (with confirmation)"
    echo "  create <name>                   Create a new network"
    echo "  connect <network> <container ...>   Connect one or more containers to a network"
    echo "  disconnect <network> <container ...> Disconnect one or more containers from a network"
    echo "  prune                           Remove all unused networks (with confirmation)"
    echo ""
    echo "Examples:"
    echo "  n ls"
    echo "  n ls mynet bridge"
    echo "  n inspect mynet"
    echo "  n rm oldnet tempnet"
    echo "  n create devnet"
    echo "  n connect devnet mycontainer1 mycontainer2"
    echo "  n disconnect devnet mycontainer1 mycontainer2"
    echo "  n prune"
    return
  fi

  local CMD="$1"
  shift
  case "$CMD" in
    ls)         _n_ls "$@" ;;
    inspect)    _n_inspect "$@" ;;
    rm)         _n_rm "$@" ;;
    create)     _n_create "$@" ;;
    connect)    _n_connect "$@" ;;
    disconnect) _n_disconnect "$@" ;;
    prune)      _n_prune ;;
    *)          echo "Unknown command: $CMD. Use 'n help' for usage."; return 1 ;;
  esac
}

_n_ls() {
  if [ -z "$1" ]; then
    docker network ls
    echo "============================================"
    echo "Found $(docker network ls | grep -v 'NETWORK ID' | wc -l) networks."
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    docker network ls | grep -E "$PATTERN"
    echo "============================================"
    echo "Found $(docker network ls | grep -E "$PATTERN" | wc -l) networks."
  fi
}

_n_inspect() {
  if [ -z "$1" ]; then
    echo "Which network to inspect? Specify one or more patterns."
    return 1
  fi
  local PATTERN="$(IFS="|"; echo "$*")"
  local NETWORKS=$(docker network ls | grep -E "$PATTERN" | awk '{print $2}')
  if [ -z "$NETWORKS" ]; then
    echo "No networks match the pattern."
    return 1
  fi
  for net in $NETWORKS; do
    echo "===== Inspecting network: $net ====="
    docker network inspect "$net"
  done
}

_n_rm() {
  if [ -z "$1" ]; then
    echo "Which network to remove? Specify one or more patterns."
    return 1
  fi
  local PATTERN="$(IFS="|"; echo "$*")"
  local NETWORKS=$(docker network ls | grep -E "$PATTERN" | awk '{print $2}')
  local COUNT=$(echo "$NETWORKS" | wc -w)
  if [ -z "$NETWORKS" ]; then
    echo "No networks match the pattern."
    return 1
  fi
  echo "Removing the following $COUNT networks:"
  docker network ls | grep -E "$PATTERN"
  read -p "Do you want to continue? (y/N)?" confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    echo "$NETWORKS" | xargs -r docker network rm
    echo "Networks removed."
  else
    echo "Operation cancelled."
  fi
}

_n_create() {
  if [ -z "$1" ]; then
    echo "Please specify a network name."
    return 1
  fi
  docker network create "$1"
}

_n_connect() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: n connect <network> <container ...>"
    return 1
  fi
  local NET="$1"
  shift
  for c in "$@"; do
    docker network connect "$NET" "$c"
  done
}

_n_disconnect() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: n disconnect <network> <container ...>"
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

