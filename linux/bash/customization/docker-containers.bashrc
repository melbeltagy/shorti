# Docker container management function

_d_ls() {
  if [ -z "$1" ]; then
    docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}"
    echo "============================================"
    echo "Found $(docker container ls -aq | wc -l) containers."
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}" | grep -E "^CONTAINER|$PATTERN"
    echo "============================================"
    echo "Found $(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -cE "$PATTERN") containers."
  fi
}

_d_lsp() {
  if [ -z "$1" ]; then
    docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}"
    echo "============================================"
    echo "Found $(docker container ls -aq | wc -l) containers."
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" | grep -E "^CONTAINER|$PATTERN"
    echo "============================================"
    echo "Found $(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -cE "$PATTERN") containers."
  fi
}

_d_mnt() {
  local CONTAINERS
  if [ -z "$1" ]; then
    CONTAINERS=$(docker container ls -aq)
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    CONTAINERS=$(docker container ls -a --format '{{.ID}}\t{{.Names}}\t{{.Image}}' | grep -E "$PATTERN" | awk '{print $1}')
    if [ -z "$CONTAINERS" ]; then
      echo "No containers match the pattern."
      return 1
    fi
  fi
  while IFS= read -r c; do
    docker inspect "$c" --format '{{.Name}}:{{range .Mounts}}
  - {{.Name}} → {{.Destination}}{{end}}'
  done <<< "$CONTAINERS"
}

_d_bash() { _d_exec bash "$@"; }
_d_sh()   { _d_exec sh "$@"; }

_d_exec() {
  local SHELL="$1"
  local PATTERN="$2"
  local USER="$3"
  if [ -z "$PATTERN" ]; then
    echo "Usage: d $SHELL <container> [user]"
    return 1
  fi
  local MATCHES=$(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep "$PATTERN")
  local COUNT=$(echo "$MATCHES" | grep -c .)
  if [ -z "$MATCHES" ]; then
    echo "No containers match '$PATTERN'."
    return 1
  fi
  if [ "$COUNT" -gt 1 ]; then
    echo "Multiple containers match '$PATTERN'. Be more specific:"
    echo "$MATCHES"
    return 1
  fi
  local CONTAINER=$(echo "$MATCHES" | awk '{print $1}')
  echo "Executing $SHELL on container: $(echo "$MATCHES" | awk '{print $2}') ($CONTAINER)"
  if [ -z "$USER" ]; then
    docker exec -it "$CONTAINER" /bin/$SHELL
  else
    docker exec -u "$USER" -it "$CONTAINER" /bin/$SHELL
  fi
}

_d_cp() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: d cp <to|from> <container> <src> <dest>"
    echo "  to <container> <src> <dest>     Copy file/dir from host to container"
    echo "  from <container> <src> <dest>   Copy file/dir from container to host"
    echo "Examples:"
    echo "  d cp to mycontainer ./file.txt /tmp/file.txt"
    echo "  d cp from mycontainer /tmp/file.txt ./file.txt"
    return
  fi
  if [ "$1" == "to" ]; then
    if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
      echo "Usage: d cp to <container> <src> <dest>"
      return 1
    fi
    docker cp "$3" "$2":"$4"
  elif [ "$1" == "from" ]; then
    if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
      echo "Usage: d cp from <container> <src> <dest>"
      return 1
    fi
    docker cp "$2":"$3" "$4"
  else
    echo "Unknown cp option: $1. Use 'd cp help' for usage."
    return 1
  fi
}

_d_tail() {
  local PATTERN="$(IFS="|"; echo "$*")"
  echo "Executing tail command on $(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -cE "$PATTERN") containers..."
  docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "$PATTERN" | awk '{print $1}' | xargs docker logs -f
}

_d_logs() {
  if [ -z "$1" ]; then
    echo "Showing logs for all containers..."
    docker ps -a --format '{{.ID}}' | xargs -r -I {} sh -c 'echo "===== Logs for container: {} ====="; docker logs {}'
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    echo "Showing logs for containers matching: $PATTERN"
    docker container ls -a --format '{{.ID}}\t{{.Names}}\t{{.Image}}' | grep -E "$PATTERN" | awk '{print $1}' | xargs -r -I {} sh -c 'echo "===== Logs for container: {} ====="; docker logs {}'
  fi
}

_d_rm() {
  if [ -z "$1" ]; then
    read -p "Removing all containers: Do you want to continue? (y/N)?" confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      docker rm $(docker ps -q -a)
    else
      echo "Operation cancelled."
    fi
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    local COUNT=$(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "$PATTERN" | wc -l)
    if [ $COUNT -eq 0 ]; then
      echo "No containers match the pattern."
      return 1
    fi
    echo "Removing the following $COUNT containers:"
    d ls | grep -E "$PATTERN"
    read -p "Do you want to continue? (y/N)?" confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "$PATTERN" | awk '{print $1}' | xargs docker container rm
      echo "Containers removed."
    else
      echo "Operation cancelled."
    fi
  fi
}

_d_start_stop() {
  local CMD="$1"
  shift
  if [ -z "$1" ]; then
    echo "Executing [$CMD] command on $(docker container ls -aq | wc -l) containers..."
    docker $CMD $(docker ps -q -a)
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    local IDS=$(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "$PATTERN" | awk '{print $1}')
    local COUNT=$(echo "$IDS" | wc -w)
    if [ -z "$IDS" ]; then
      echo "No containers match the pattern."
      return 1
    fi
    echo "Executing [$CMD] command on $COUNT containers..."
    echo "$IDS" | xargs -r docker container $CMD
  fi
}

_d_prune() {
  read -p "This will remove all stopped containers. Continue? (y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    docker container prune
  else
    echo "Operation cancelled."
  fi
}

function d() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: d <command> [pattern ...] [user]"
    echo "Commands:"
    echo "  ls [pattern ...]              List all containers (optionally filter by one or more patterns)"
    echo "  lsp [pattern ...]             List containers with ports (optionally filter by one or more patterns)"
    echo "  mnt [pattern ...]             Show full mount details for containers (all or matching patterns)"
    echo "  bash <container> [user]       Exec into container with bash (optionally as user)"
    echo "  sh <container> [user]         Exec into container with sh (optionally as user)"
    echo "  cp to <container> <src> <dest>     Copy file/dir from host to container"
    echo "  cp from <container> <src> <dest>   Copy file/dir from container to host"
    echo "  tail <pattern>                Tail logs for containers matching pattern"
    echo "  logs [pattern]                Show logs for all or matching containers"
    echo "  rm [pattern ...]              Remove containers (all or matching patterns)"
    echo "  start [pattern ...]           Start containers (all or matching patterns)"
    echo "  stop [pattern ...]            Stop containers (all or matching patterns)"
    echo "  prune                         Remove all stopped containers (with confirmation)"
    echo ""
    echo "Examples:"
    echo "  d ls"
    echo "  d ls myapp web"
    echo "  d mnt ss2"
    echo "  d mnt ss"
    echo "  d bash mycontainer"
    echo "  d bash mycontainer root"
    echo "  d cp to mycontainer ./local-file.txt /tmp/file.txt"
    echo "  d cp from mycontainer /tmp/file.txt ./local-file.txt"
    echo "  d tail web"
    echo "  d logs myapp"
    echo "  d rm oldapp tempapp"
    echo "  d stop myapp web"
    echo "  d prune"
    return
  fi

  local CMD="$1"
  shift
  case "$CMD" in
    ls)      _d_ls "$@" ;;
    lsp)     _d_lsp "$@" ;;
    mnt)     _d_mnt "$@" ;;
    bash)    _d_bash "$@" ;;
    sh)      _d_sh "$@" ;;
    cp)      _d_cp "$@" ;;
    tail)    _d_tail "$@" ;;
    logs)    _d_logs "$@" ;;
    rm)      _d_rm "$@" ;;
    start)   _d_start_stop start "$@" ;;
    stop)    _d_start_stop stop "$@" ;;
    prune)   _d_prune ;;
    *)       echo "Unknown command: $CMD. Use 'd help' for usage."; return 1 ;;
  esac
}
