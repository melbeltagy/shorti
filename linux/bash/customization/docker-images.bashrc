# Docker images management function

_i_ls() {
  if [ -z "$1" ]; then
    docker image ls -a
    echo "============================================"
    echo "Found $(docker image ls -aq 2>/dev/null | wc -l) images."
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    docker image ls -a 2>/dev/null | grep -E "^REPOSITORY|$PATTERN"
    echo "============================================"
    echo "Found $(docker image ls -a --format '{{.ID}} {{.Repository}} {{.Tag}}' 2>/dev/null | grep -cE "$PATTERN") images."
  fi
}

_i_pull() {
  if [ -z "$1" ]; then
    echo "Pulling all images..."
    docker image ls --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' | while IFS= read -r img; do
      echo "Pulling $img ..."
      docker pull "$img"
    done
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    local IMAGES
    IMAGES=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' | grep -E "$PATTERN")
    if [ -z "$IMAGES" ]; then
      echo "No images match the pattern."
      return 1
    fi
    echo "Pulling images matching: $PATTERN"
    while IFS= read -r img; do
      echo "Pulling $img ..."
      docker pull "$img"
    done <<< "$IMAGES"
  fi
}

_i_rm() {
  if [ -z "$1" ]; then
    echo "Which image to delete? Specify one or more patterns."
    return 1
  fi
  local PATTERN="$(IFS="|"; echo "$*")"
  local COUNT
  COUNT=$(docker image ls -a --format '{{.ID}} {{.Repository}} {{.Tag}}' 2>/dev/null | grep -cE "$PATTERN")
  if [ "$COUNT" -eq 0 ]; then
    echo "No images match the pattern."
    return 1
  fi
  echo "Removing the following $COUNT images..."
  docker image ls -a 2>/dev/null | grep -E "^REPOSITORY|$PATTERN"
  read -p "Do you want to continue? (y/N)?" confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    docker image ls -a --format '{{.ID}} {{.Repository}} {{.Tag}}' 2>/dev/null | grep -E "$PATTERN" | awk '{print $1}' | xargs -r docker image rm
    echo "Images removed."
  else
    echo "Operation cancelled."
  fi
}

_i_info() {
  if [ -z "$1" ]; then
    echo "Which image to inspect? Specify one or more patterns."
    return 1
  fi
  local PATTERN="$(IFS="|"; echo "$*")"
  local IMAGES
  IMAGES=$(docker image ls --format '{{.ID}} {{.Repository}} {{.Tag}}' | grep -E "$PATTERN" | awk '{print $1}')
  if [ -z "$IMAGES" ]; then
    echo "No images match the pattern."
    return 1
  fi
  while IFS= read -r img; do
    echo "===== Inspecting image: $img ====="
    docker image inspect "$img"
  done <<< "$IMAGES"
}

_i_who() {
  local IMAGES
  if [ -z "$1" ]; then
    IMAGES=$(docker image ls --format '{{.ID}}|{{.Repository}}:{{.Tag}}' | grep -v ':<none>')
  else
    local PATTERN="$(IFS="|"; echo "$*")"
    IMAGES=$(docker image ls --format '{{.ID}}|{{.Repository}}:{{.Tag}}' | grep -v ':<none>' | grep -E "$PATTERN")
  fi
  if [ -z "$IMAGES" ]; then
    echo "No images match."
    return 1
  fi
  {
    printf 'IMAGE\tCONTAINER\tSTATUS\n'
    while IFS='|' read -r id label; do
      local rows
      rows=$(docker ps -a --filter ancestor="$id" --format '{{.Names}}	{{.Status}}')
      if [ -z "$rows" ]; then
        printf '%s\t(unused)\t\n' "$label"
      else
        while IFS= read -r row; do
          printf '%s\t%s\n' "$label" "$row"
        done <<< "$rows"
      fi
    done <<< "$IMAGES"
  } | column -t -s $'\t'
}

_i_hist() {
  if [ -z "$1" ]; then
    echo "Which image? Specify one or more patterns."
    return 1
  fi
  local PATTERN="$(IFS="|"; echo "$*")"
  local IMAGES
  IMAGES=$(docker image ls --format '{{.ID}} {{.Repository}} {{.Tag}}' | grep -E "$PATTERN" | awk '{print $1}')
  if [ -z "$IMAGES" ]; then
    echo "No images match the pattern."
    return 1
  fi
  while IFS= read -r img; do
    echo "===== History for image: $img ====="
    docker history "$img"
  done <<< "$IMAGES"
}

_i_prune() {
  read -p "This will remove all unused images. Continue? (y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    docker image prune
  else
    echo "Operation cancelled."
  fi
}

function i() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: i <command> [pattern ...]"
    echo "Commands:"
    echo "  ls   [pattern ...]   List images (filter optional)"
    echo "  pull [pattern ...]   Pull images (all or matching)"
    echo "  rm   [pattern ...]   Remove matching images (with confirmation)"
    echo "  info [pattern ...]   Inspect matching images"
    echo "  who  [pattern ...]   Show containers using each matching image"
    echo "  hist [pattern ...]   Show layer history for matching images"
    echo "  prune                Remove unused images (with confirmation)"
    echo ""
    echo "Examples:"
    echo "  i ls"
    echo "  i ls ubuntu alpine"
    echo "  i pull ubuntu alpine"
    echo "  i rm oldimage tempimage"
    echo "  i info myimage"
    echo "  i who postgres"
    echo "  i hist niis/xroad"
    echo "  i prune"
    return
  fi

  local CMD="$1"
  shift
  case "$CMD" in
    ls)    _i_ls "$@" ;;
    pull)  _i_pull "$@" ;;
    rm)    _i_rm "$@" ;;
    info)  _i_info "$@" ;;
    who)   _i_who "$@" ;;
    hist)  _i_hist "$@" ;;
    prune) _i_prune ;;
    *)     echo "Unknown command: $CMD. Use 'i help' for usage."; return 1 ;;
  esac
}
