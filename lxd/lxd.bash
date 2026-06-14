_lx_ls() {
  if [ -z "$1" ]; then
    lxc list
    echo "============================================"
    echo "Found $(lxc list -c n --format csv | wc -l) containers."
  else
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
    lxc list | grep -E "$PATTERN"
    echo "============================================"
    echo "Found $(lxc list -c n --format csv | grep -cE "$PATTERN") containers."
  fi
}

_lx_bash() {
  if [ -z "$1" ]; then
    echo "Usage: lx bash <container> [user]"
    return 1
  fi
  if [ -z "$2" ]; then
    lxc exec "$1" -- /bin/bash
  else
    lxc exec "$1" -- su - "$2" -c /bin/bash
  fi
}

_lx_sh() {
  if [ -z "$1" ]; then
    echo "Usage: lx sh <container> [user]"
    return 1
  fi
  if [ -z "$2" ]; then
    lxc exec "$1" -- /bin/sh
  else
    lxc exec "$1" -- su - "$2" -c /bin/sh
  fi
}

_lx_cp() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: lx cp <to|from> <container> <src> <dest>"
    echo "  to <container> <src> <dest>     Copy file/dir from host to container"
    echo "  from <container> <src> <dest>   Copy file/dir from container to host"
    echo "Examples:"
    echo "  lx cp to mycontainer ./file.txt /tmp/file.txt"
    echo "  lx cp from mycontainer /tmp/file.txt ./file.txt"
    return
  fi
  if [ "$1" == "to" ]; then
    if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
      echo "Usage: lx cp to <container> <src> <dest>"
      return 1
    fi
    lxc file push "$3" "$2/$4"
  elif [ "$1" == "from" ]; then
    if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
      echo "Usage: lx cp from <container> <src> <dest>"
      return 1
    fi
    lxc file pull "$2/$3" "$4"
  else
    echo "Unknown cp option: $1. Use 'lx cp help' for usage."
    return 1
  fi
}

_lx_rm() {
  if [ -z "$1" ]; then
    read -rp"Removing all containers: Do you want to continue? (y/N)?" confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      while IFS= read -r n; do
        [ -z "$n" ] && continue
        echo "Deleting container: $n"
        lxc delete "$n" --force
      done < <(lxc list -c n --format csv)
    else
      echo "Operation cancelled."
    fi
  else
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
    local NAMES
    NAMES=$(lxc list -c n --format csv | grep -E "$PATTERN")
    if [ -z "$NAMES" ]; then
      echo "No containers match the pattern."
      return 1
    fi
    local COUNT
    COUNT=$(echo "$NAMES" | wc -w)
    echo "Removing the following $COUNT containers:"
    echo "$NAMES"
    read -rp"Do you want to continue? (y/N)?" confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      while IFS= read -r n; do
        [ -z "$n" ] && continue
        echo "Deleting container: $n"
        lxc delete "$n" --force
      done <<< "$NAMES"
      echo "Containers removed."
    else
      echo "Operation cancelled."
    fi
  fi
}

_lx_start_stop() {
  local CMD="$1"
  shift
  if [ -z "$1" ]; then
    echo "Executing [$CMD] command on all containers..."
    while IFS= read -r n; do
      [ -z "$n" ] && continue
      echo "$CMD container: $n"
      lxc "$CMD" "$n"
    done < <(lxc list -c n --format csv)
  else
    local PATTERN
    PATTERN="$(IFS="|"; echo "$*")"
    local NAMES
    NAMES=$(lxc list -c n --format csv | grep -E "$PATTERN")
    if [ -z "$NAMES" ]; then
      echo "No containers match the pattern."
      return 1
    fi
    local COUNT
    COUNT=$(echo "$NAMES" | wc -w)
    echo "Executing [$CMD] command on $COUNT containers..."
    while IFS= read -r n; do
      [ -z "$n" ] && continue
      echo "$CMD container: $n"
      lxc "$CMD" "$n"
    done <<< "$NAMES"
  fi
}

_lx_snap() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: lx snap <command> <container> [snapshot]"
    echo "Commands:"
    echo "  new <container> [name]            Create snapshot (auto-named if no name)"
    echo "  ls [container]                    List snapshots (all containers if none given)"
    echo "  restore <container> <snapshot>    Restore container to a snapshot"
    echo "  rm <container> <snapshot>         Delete a snapshot"
    return
  fi
  local SUB="$1"
  shift
  case "$SUB" in
    new|create)
      if [ -z "$1" ]; then
        echo "Usage: lx snap new <container> [name]"
        return 1
      fi
      if [ -z "$2" ]; then
        lxc snapshot "$1"
      else
        lxc snapshot "$1" "$2"
      fi
      ;;
    ls|list)
      if [ -z "$1" ]; then
        while IFS= read -r c; do
          [ -z "$c" ] && continue
          echo "===== Snapshots for: $c ====="
          lxc info "$c" | sed -n '/Snapshots:/,$p'
          echo ""
        done < <(lxc list -c n --format csv)
      else
        lxc info "$1" | sed -n '/Snapshots:/,$p'
      fi
      ;;
    restore)
      if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: lx snap restore <container> <snapshot>"
        return 1
      fi
      lxc restore "$1" "$2"
      ;;
    rm|delete)
      if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: lx snap rm <container> <snapshot>"
        return 1
      fi
      lxc delete "$1/$2"
      ;;
    *)
      echo "Unknown snap subcommand: $SUB. Use 'lx snap help' for usage."
      return 1
      ;;
  esac
}

_lx_help() {
  cat <<'EOF'
Usage: lx <command> [pattern ...] [user]
Commands:
  ls [pattern ...]                List containers (filter optional)
  bash <container> [user]         Exec into container with bash (optionally as user)
  sh <container> [user]           Exec into container with sh (optionally as user)
  cp <to|from> ...                Copy file/dir between host and container
  rm [pattern ...]                Remove containers (all or matching patterns)
  start [pattern ...]             Start containers (all or matching patterns)
  stop [pattern ...]              Stop containers (all or matching patterns)
  snap <new|ls|restore|rm> ...    Manage container snapshots ('lx snap help')

Examples:
  lx ls
  lx ls myapp web
  lx bash mycontainer
  lx bash mycontainer root
  lx cp to mycontainer ./file.txt /tmp/file.txt
  lx cp from mycontainer /tmp/file.txt ./file.txt
  lx rm oldapp tempapp
  lx start myapp web
  lx stop myapp web
  lx snap new mycontainer before-upgrade
  lx snap ls mycontainer
  lx snap restore mycontainer before-upgrade
EOF
}

function lx() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _lx_help; return; fi
  _shorti_require lxc || return $?
  local CMD="$1"
  shift
  case "$CMD" in
    ls)    _lx_ls "$@" ;;
    bash)  _lx_bash "$@" ;;
    sh)    _lx_sh "$@" ;;
    cp)    _lx_cp "$@" ;;
    rm)    _lx_rm "$@" ;;
    start) _lx_start_stop start "$@" ;;
    stop)  _lx_start_stop stop "$@" ;;
    snap)  _lx_snap "$@" ;;
    *)     echo "Unknown command: $CMD" >&2; echo "" >&2; _lx_help >&2; return 1 ;;
  esac
}
