# LXD image management shortcut

_lxi_ls() {
  if [ -z "$1" ]; then
    lxc image list
    echo "============================================"
    echo "Found $(lxc image list -c f --format csv | wc -l) images."
  else
    local PATTERN OUT
    PATTERN="$(IFS="|"; echo "$*")"
    OUT="$(lxc image list)"
    { echo "$OUT" | head -n 3; echo "$OUT" | tail -n +4 | grep -E "$PATTERN"; }
    echo "============================================"
    echo "Found $(lxc image list -c lfd --format csv | grep -cE "$PATTERN") images."
  fi
}

_lxi_info() {
  if [ -z "$1" ]; then
    echo "Which image to inspect? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local IMAGES
  IMAGES=$(lxc image list -c lfd --format csv | grep -E "$PATTERN" | cut -d, -f2)
  if [ -z "$IMAGES" ]; then
    echo "No images match the pattern."
    return 1
  fi
  while IFS= read -r img; do
    [ -z "$img" ] && continue
    echo "===== Inspecting image: $img ====="
    lxc image info "$img"
  done <<< "$IMAGES"
}

_lxi_rm() {
  if [ -z "$1" ]; then
    echo "Which image to delete? Specify one or more patterns."
    return 1
  fi
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local IMAGES
  IMAGES=$(lxc image list -c lfd --format csv | grep -E "$PATTERN" | cut -d, -f2)
  if [ -z "$IMAGES" ]; then
    echo "No images match the pattern."
    return 1
  fi
  local COUNT
  COUNT=$(echo "$IMAGES" | wc -l)
  echo "Removing the following $COUNT images..."
  lxc image list | grep -E "$PATTERN"
  read -rp"Do you want to continue? (y/N)?" confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    while IFS= read -r img; do
      [ -z "$img" ] && continue
      echo "Deleting image: $img"
      lxc image delete "$img"
    done <<< "$IMAGES"
    echo "Images removed."
  else
    echo "Operation cancelled."
  fi
}

_lxi_pull() {
  if [ -z "$1" ]; then
    echo "Usage: lxi pull <image> [remote]"
    echo "Copies an image from a remote (default 'images:') into the local store."
    return 1
  fi
  local IMAGE="$1"
  local REMOTE="${2:-images}"
  echo "Copying ${REMOTE}:${IMAGE} into the local image store..."
  lxc image copy "${REMOTE}:${IMAGE}" local:
}

_lxi_help() {
  cat <<'EOF'
Usage: lxi <command> [pattern ...]
Commands:
  ls   [pattern ...]        List images (filter optional)
  info [pattern ...]        Show info for matching images
  rm   [pattern ...]        Delete matching images (with confirmation)
  pull <image> [remote]     Copy an image from a remote (default 'images:')

Examples:
  lxi ls
  lxi ls ubuntu 24.04
  lxi info ubuntu
  lxi rm 5aa497 oldimage
  lxi pull ubuntu/24.04
  lxi pull alpine/edge images
EOF
}

function lxi() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _lxi_help; return; fi
  _shorti_require lxc || return $?
  local CMD="$1"
  shift
  case "$CMD" in
    ls)   _lxi_ls "$@" ;;
    info) _lxi_info "$@" ;;
    rm)   _lxi_rm "$@" ;;
    pull) _lxi_pull "$@" ;;
    *)    echo "Unknown command: $CMD" >&2; echo "" >&2; _lxi_help >&2; return 1 ;;
  esac
}
