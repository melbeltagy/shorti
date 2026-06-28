function _g_prune() {
  # Update remote references, pruning any branches no longer existing on the remote
  git fetch --prune

  local branches
  branches=$(git branch -vv | grep 'gone]')
  if [ -z "$branches" ]; then
    echo "No local branches that no longer exist on remote."
    return
  fi

  echo "Deleted the following local branches that no longer exist on remote:"
  git branch -vv | grep 'gone]'

  read -rp "Do you want to continue? (y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      echo "Continuing..."
      # Identify and delete local branches that no longer exist on remote (remote branches won't be affected)
      git branch -vv | grep -v '\*' | grep 'gone]' | awk '{print $1}' | xargs git branch -D
      branches=$(git branch -vv | grep 'gone]')
      if [ -n "$branches" ]; then
        echo ""
        echo "The following branches have not been deleted:"
        git branch -vv | grep 'gone]'
      fi
  else
      echo "Operation cancelled."
  fi
}

_g_help() {
  cat <<'EOF'
Usage: g <command> [args ...]   ("g" stands for git)
Commands:
  b   [args ...]   git branch
  c   [args ...]   git clone
  cb  [args ...]   git checkout -b
  co  [args ...]   git checkout
  d   [args ...]   git diff
  f   [args ...]   git fetch
  l   [args ...]   git log --oneline -20
  p   [args ...]   git push
  pl  [args ...]   git pull
  prune            Prune local branches whose remote is gone (with confirmation)
  s   [args ...]   git status

Examples:
  g s
  g co main
  g cb feature/x
  g p origin main
  g prune
EOF
}

# Subcommand dispatcher: g <command> [args...]. "g" stands for git.
function g() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _g_help; return; fi
  _shorti_require git || return $?
  local cmd="$1"
  shift

  case "$cmd" in
    b)     git branch "$@" ;;
    c)     git clone "$@" ;;
    cb)    git checkout -b "$@" ;;
    co)    git checkout "$@" ;;
    d)     git diff "$@" ;;
    f)     git fetch "$@" ;;
    l)     git log --oneline -20 "$@" ;;
    p)     git push "$@" ;;
    pl)    git pull "$@" ;;
    prune) _g_prune "$@" ;;
    s)     git status "$@" ;;
    *)     echo "Unknown command: $cmd" >&2; echo "" >&2; _g_help >&2; return 1 ;;
  esac
}
