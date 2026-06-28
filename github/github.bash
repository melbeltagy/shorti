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

# Subcommand dispatcher: g <command> [args...]. "g" stands for git.
function g() {
  local cmd="$1"
  shift 2>/dev/null

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
    "")    git status ;;
    *)     git "$cmd" "$@" ;;  # fall through to plain git
  esac
}
