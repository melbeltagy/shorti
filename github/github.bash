function gprune() {
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

alias gb='git branch'
alias gc='git clone'
alias gcb='git checkout -b'
alias gco='git checkout'
alias gd='git diff'
alias gf='git fetch'
alias gl='git log --oneline -20'
alias gp='git push'
alias gpl='git pull'
alias gprn='gprune'
alias gs='git status'
