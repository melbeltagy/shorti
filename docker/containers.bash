# Docker container management function

_d_ls() {
  if [ -z "$1" ]; then
    docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}"
    echo "============================================"
    echo "Found $(docker container ls -aq | wc -l) containers."
  else
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
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
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
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
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
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
  local MATCHES COUNT
  MATCHES=$(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep "$PATTERN")
  COUNT=$(echo "$MATCHES" | grep -c .)
  if [ -z "$MATCHES" ]; then
    echo "No containers match '$PATTERN'."
    return 1
  fi
  if [ "$COUNT" -gt 1 ]; then
    echo "Multiple containers match '$PATTERN'. Be more specific:"
    echo "$MATCHES"
    return 1
  fi
  local CONTAINER
  CONTAINER=$(echo "$MATCHES" | awk '{print $1}')
  echo "Executing $SHELL on container: $(echo "$MATCHES" | awk '{print $2}') ($CONTAINER)"
  if [ -z "$USER" ]; then
    docker exec -it "$CONTAINER" "/bin/$SHELL"
  else
    docker exec -u "$USER" -it "$CONTAINER" "/bin/$SHELL"
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
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  echo "Executing tail command on $(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -cE "$PATTERN") containers..."
  docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "$PATTERN" | awk '{print $1}' | xargs docker logs -f
}

_d_logs() {
  if [ -z "$1" ]; then
    echo "Showing logs for all containers..."
    docker ps -a --format '{{.ID}}' | xargs -r -I {} sh -c 'echo "===== Logs for container: {} ====="; docker logs {}'
  else
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
    echo "Showing logs for containers matching: $PATTERN"
    docker container ls -a --format '{{.ID}}\t{{.Names}}\t{{.Image}}' | grep -E "$PATTERN" | awk '{print $1}' | xargs -r -I {} sh -c 'echo "===== Logs for container: {} ====="; docker logs {}'
  fi
}

_d_rm() {
  if [ -z "$1" ]; then
    read -rp"Removing all containers: Do you want to continue? (y/N)?" confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      docker ps -q -a | xargs -r docker rm
    else
      echo "Operation cancelled."
    fi
  else
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
    local COUNT
    COUNT=$(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -cE "$PATTERN")
    if [ "$COUNT" -eq 0 ]; then
      echo "No containers match the pattern."
      return 1
    fi
    echo "Removing the following $COUNT containers:"
    d ls | grep -E "$PATTERN"
    read -rp"Do you want to continue? (y/N)?" confirm
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
    docker ps -q -a | xargs -r docker "$CMD"
  else
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
    local IDS COUNT
    IDS=$(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "$PATTERN" | awk '{print $1}')
    COUNT=$(echo "$IDS" | wc -w)
    if [ -z "$IDS" ]; then
      echo "No containers match the pattern."
      return 1
    fi
    echo "Executing [$CMD] command on $COUNT containers..."
    echo "$IDS" | xargs -r docker container "$CMD"
  fi
}

_d_info() {
  if [ -z "$1" ]; then
    echo "Which container to inspect? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local CONTAINERS
  CONTAINERS=$(docker container ls -a --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "$PATTERN" | awk '{print $1}')
  if [ -z "$CONTAINERS" ]; then
    echo "No containers match the pattern."
    return 1
  fi
  while IFS= read -r c; do
    echo "===== Inspecting container: $c ====="
    docker container inspect "$c"
  done <<< "$CONTAINERS"
}

_d_stats() {
  local FMT='{{.ID}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.PIDs}}'
  local body
  if [ -z "$1" ]; then
    body=$(docker stats --no-stream --format "$FMT")
  else
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
    body=$(docker stats --no-stream --format "$FMT" | grep -E "$PATTERN")
  fi
  if [ -z "$body" ]; then
    echo "No running containers match the pattern."
    return 1
  fi
  body=$(echo "$body" | sort -t$'\t' -k5 -nr)
  { printf 'ID\tNAME\tCPU %%\tMEM USAGE / LIMIT\tMEM %%\tPIDS\n'; echo "$body"; } | column -t -s $'\t'
}

_d_top() {
  if [ -z "$1" ]; then
    echo "Which container? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local MATCHES
  MATCHES=$(docker container ls --format '{{.ID}} {{.Names}} {{.Image}}' | grep -E "$PATTERN")
  if [ -z "$MATCHES" ]; then
    echo "No running containers match the pattern."
    return 1
  fi
  while IFS= read -r row; do
    local id name
    id=$(echo "$row" | awk '{print $1}')
    name=$(echo "$row" | awk '{print $2}')
    echo "===== Processes in container: $name ====="
    docker top "$id"
    echo ""
  done <<< "$MATCHES"
}

_d_pid() {
  if [ -z "$1" ]; then
    echo "Usage: d pid <pid>"
    return 1
  fi
  local PID="$1"
  if [ ! -e "/proc/$PID" ]; then
    echo "PID $PID does not exist"
    return 1
  fi
  local cgroup
  cgroup=$(head -n 1 "/proc/$PID/cgroup" 2>/dev/null)
  local cid
  cid=$(echo "$cgroup" | grep -oE 'docker[-/][0-9a-f]{12,}' | grep -oE '[0-9a-f]{12,}' | head -n 1)
  if [ -z "$cid" ]; then
    echo "PID $PID is not in any docker container"
    return 1
  fi
  local name
  name=$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | sed 's|^/||')
  if [ -z "$name" ]; then
    echo "PID $PID → unknown container (${cid:0:12})"
  else
    echo "PID $PID → $name (${cid:0:12})"
  fi
}

_d_prune() {
  read -rp "This will remove all stopped containers. Continue? (y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    docker container prune
  else
    echo "Operation cancelled."
  fi
}

_d_help() {
  cat <<'EOF'
Usage: d <command> [pattern ...] [user]
Commands:
  ls [pattern ...]              List all containers (optionally filter by one or more patterns)
  lsp [pattern ...]             List containers with ports (optionally filter by one or more patterns)
  mnt [pattern ...]             Show full mount details for containers (all or matching patterns)
  bash <container> [user]       Exec into container with bash (optionally as user)
  sh <container> [user]         Exec into container with sh (optionally as user)
  cp to <container> <src> <dest>     Copy file/dir from host to container
  cp from <container> <src> <dest>   Copy file/dir from container to host
  tail <pattern>                Tail logs for containers matching pattern
  logs [pattern]                Show logs for all or matching containers
  rm [pattern ...]              Remove containers (all or matching patterns)
  start [pattern ...]           Start containers (all or matching patterns)
  stop [pattern ...]            Stop containers (all or matching patterns)
  restart [pattern ...]         Restart containers (all or matching patterns)
  info [pattern ...]            Inspect matching containers (docker inspect)
  stats [pattern ...]           Show CPU/MEM/PIDs snapshot, sorted by MEM% desc
  top [pattern ...]             List processes inside matching running containers
  pid <pid>                     Find which container owns a host PID
  prune                         Remove all stopped containers (with confirmation)

Examples:
  d ls
  d ls myapp web
  d mnt ss2
  d mnt ss
  d bash mycontainer
  d bash mycontainer root
  d cp to mycontainer ./local-file.txt /tmp/file.txt
  d cp from mycontainer /tmp/file.txt ./local-file.txt
  d tail web
  d logs myapp
  d rm oldapp tempapp
  d stop myapp web
  d restart myapp
  d info myapp
  d stats
  d top cs
  d pid 35896
  d prune
EOF
}

function d() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _d_help; return; fi
  _shorti_require docker || return $?
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
    restart) _d_start_stop restart "$@" ;;
    info)    _d_info "$@" ;;
    stats)   _d_stats "$@" ;;
    top)     _d_top "$@" ;;
    pid)     _d_pid "$@" ;;
    prune)   _d_prune ;;
    *)       echo "Unknown command: $CMD" >&2; echo "" >&2; _d_help >&2; return 1 ;;
  esac
}
