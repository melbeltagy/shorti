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

# "g" is git with a couple of power-ups. Anything not overridden below passes
# straight through to git, so `g status`, `g branch`, `g rebase -i`, etc. all work.
function g() {
  _shorti_require git || return $?
  case "$1" in
    l)     shift; git log --oneline -20 "$@" ;;  # short, recent log
    prune) shift; _g_prune "$@" ;;               # delete local branches whose remote is gone
    *)     git "$@" ;;                           # everything else is plain git
  esac
}
