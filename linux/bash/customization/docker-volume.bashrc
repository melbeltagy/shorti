# Docker volumes management function

_v_ls() {
  if [ -z "$1" ]; then
    docker volume ls
    echo "============================================"
    echo "Found $(docker volume ls | grep -v 'VOLUME NAME' | wc -l) volumes."
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    docker volume ls | grep -E "$PATTERN"
    echo "============================================"
    echo "Found $(docker volume ls | grep -E "$PATTERN" | wc -l) volumes."
  fi
}

_v_rm() {
  if [ -z "$1" ]; then
    local COUNT=$(docker volume ls | grep -v 'VOLUME NAME' | wc -l)
    if [ $COUNT -eq 0 ]; then
      echo "No volumes to remove."
      return 1
    fi
    echo "Removing all $COUNT volumes:"
    docker volume ls | grep -v 'VOLUME NAME'
    read -p "Do you want to continue? (y/N)?" confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      docker volume ls -q | xargs -r docker volume rm
      echo "Volumes removed."
    else
      echo "Operation cancelled."
    fi
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    local COUNT=$(docker volume ls | grep -E "$PATTERN" | wc -l)
    if [ $COUNT -eq 0 ]; then
      echo "No volumes match the pattern."
      return 1
    fi
    echo "Removing the following $COUNT volumes:"
    docker volume ls | grep -E "$PATTERN"
    read -p "Do you want to continue? (y/N)?" confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      docker volume ls | grep -E "$PATTERN" | awk '{print $2}' | xargs -r docker volume rm
      echo "Volumes removed."
    else
      echo "Operation cancelled."
    fi
  fi
}

_v_inspect() {
  if [ -z "$1" ]; then
    local VOLUMES=$(docker volume ls -q)
    if [ -z "$VOLUMES" ]; then
      echo "No volumes to inspect."
      return 1
    fi
    for v in $VOLUMES; do
      echo "===== Inspecting volume: $v ====="
      docker volume inspect "$v"
    done
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    local VOLUMES=$(docker volume ls | grep -E "$PATTERN" | awk '{print $2}')
    if [ -z "$VOLUMES" ]; then
      echo "No volumes match the pattern."
      return 1
    fi
    for v in $VOLUMES; do
      echo "===== Inspecting volume: $v ====="
      docker volume inspect "$v"
    done
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
    echo "  ls [pattern ...]             List all volumes (optionally filter by one or more patterns)"
    echo "  rm [pattern ...]             Remove all or matching volumes (with confirmation)"
    echo "  inspect [pattern ...]        Inspect all or matching volumes"
    echo "  prune                        Remove all unused volumes (with confirmation)"
    echo ""
    echo "Examples:"
    echo "  v ls"
    echo "  v ls data backup"
    echo "  v rm"
    echo "  v rm oldvolume tempvolume"
    echo "  v inspect"
    echo "  v inspect myvolume cache"
    echo "  v prune"
    return
  fi

  local CMD="$1"
  shift
  case "$CMD" in
    ls)      _v_ls "$@" ;;
    rm)      _v_rm "$@" ;;
    inspect) _v_inspect "$@" ;;
    prune)   _v_prune ;;
    *)       echo "Unknown command: $CMD. Use 'v help' for usage."; return 1 ;;
  esac
}

