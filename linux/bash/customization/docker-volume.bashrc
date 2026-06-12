# Docker volumes management function

_v_ls() {
  if [ -z "$1" ]; then
    docker volume ls --format 'table {{.Driver}}\t{{.Name}}'
    echo "============================================"
    echo "Found $(docker volume ls -q | wc -l) volumes."
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    docker volume ls --format 'table {{.Driver}}\t{{.Name}}' | grep -E "^DRIVER|$PATTERN"
    echo "============================================"
    echo "Found $(docker volume ls --format '{{.Name}}' | grep -cE "$PATTERN") volumes."
  fi
}

_v_rm() {
  local NAMES COUNT
  if [ -z "$1" ]; then
    NAMES=$(docker volume ls -q)
    if [ -z "$NAMES" ]; then
      echo "No volumes to remove."
      return 1
    fi
    COUNT=$(echo "$NAMES" | wc -l)
    echo "Removing all $COUNT volumes:"
    docker volume ls --format 'table {{.Driver}}\t{{.Name}}'
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    NAMES=$(docker volume ls --format '{{.Name}}' | grep -E "$PATTERN")
    if [ -z "$NAMES" ]; then
      echo "No volumes match the pattern."
      return 1
    fi
    COUNT=$(echo "$NAMES" | wc -l)
    echo "Removing the following $COUNT volumes:"
    echo "$NAMES"
  fi
  read -p "Do you want to continue? (y/N)?" confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    echo "$NAMES" | xargs -r docker volume rm
    echo "Volumes removed."
  else
    echo "Operation cancelled."
  fi
}

_v_info() {
  local VOLUMES
  if [ -z "$1" ]; then
    VOLUMES=$(docker volume ls -q)
    if [ -z "$VOLUMES" ]; then
      echo "No volumes to inspect."
      return 1
    fi
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    VOLUMES=$(docker volume ls --format '{{.Name}}' | grep -E "$PATTERN")
    if [ -z "$VOLUMES" ]; then
      echo "No volumes match the pattern."
      return 1
    fi
  fi
  while IFS= read -r v; do
    echo "===== Inspecting volume: $v ====="
    docker volume inspect "$v"
  done <<< "$VOLUMES"
}

_v_who() {
  local VOLUMES
  if [ -z "$1" ]; then
    VOLUMES=$(docker volume ls --format '{{.Name}}')
    if [ -z "$VOLUMES" ]; then
      echo "No volumes found."
      return 1
    fi
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    VOLUMES=$(docker volume ls --format '{{.Name}}' | grep -E "$PATTERN")
    if [ -z "$VOLUMES" ]; then
      echo "No volumes match the pattern."
      return 1
    fi
  fi
  {
    printf 'VOLUME\tCONTAINER\tIMAGE\tSTATUS\n'
    while IFS= read -r v; do
      local rows
      rows=$(docker ps -a --filter volume="$v" --format '{{.Names}}	{{.Image}}	{{.Status}}')
      if [ -z "$rows" ]; then
        printf '%s\t(unused)\t\t\n' "$v"
      else
        while IFS= read -r row; do
          printf '%s\t%s\n' "$v" "$row"
        done <<< "$rows"
      fi
    done <<< "$VOLUMES"
  } | column -t -s $'\t'
}

_v_du() {
  local OUT
  OUT=$(docker system df -v --format '{{range .Volumes}}{{.Name}}	{{.Size}}	{{.Links}}
{{end}}')
  if [ -z "$1" ]; then
    { printf 'VOLUME\tSIZE\tLINKS\n'; echo "$OUT"; } | column -t -s $'\t'
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    { printf 'VOLUME\tSIZE\tLINKS\n'; echo "$OUT" | grep -E "$PATTERN"; } | column -t -s $'\t'
  fi
}

_v_prune() {
  read -p "This will remove all unused volumes. Continue? (y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    docker volume prune
  else
    echo "Operation cancelled."
  fi
}

function v() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: v <command> [pattern ...]"
    echo "Commands:"
    echo "  ls   [pattern ...]   List volumes (filter optional)"
    echo "  rm   [pattern ...]   Remove all or matching volumes (with confirmation)"
    echo "  info [pattern ...]   Inspect all or matching volumes"
    echo "  who  [pattern ...]   Show containers using each volume"
    echo "  du   [pattern ...]   Show on-disk size and link count for each volume"
    echo "  prune                Remove all unused volumes (with confirmation)"
    echo ""
    echo "Examples:"
    echo "  v ls"
    echo "  v ls data backup"
    echo "  v rm oldvolume tempvolume"
    echo "  v info myvolume cache"
    echo "  v who data"
    echo "  v du"
    echo "  v prune"
    return
  fi

  local CMD="$1"
  shift
  case "$CMD" in
    ls)    _v_ls "$@" ;;
    rm)    _v_rm "$@" ;;
    info)  _v_info "$@" ;;
    who)   _v_who "$@" ;;
    du)    _v_du "$@" ;;
    prune) _v_prune ;;
    *)     echo "Unknown command: $CMD. Use 'v help' for usage."; return 1 ;;
  esac
}
