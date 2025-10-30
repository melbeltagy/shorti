function gp() {
  # Update remote references, pruning any branches no longer existing on the remote
  git fetch --prune

  local branches=$(git branch -vv | grep 'gone]')
  if [ -z "$branches" ]; then
    echo "No local branches that no longer exist on remote."
    return
  fi

  echo "Deleted the following local branches that no longer exist on remote:"
  git branch -vv | grep 'gone]'
  
  read -p "Do you want to continue? (y/N): " confirm
  if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      echo "Continuing..."
      # Identify and delete local branches that no longer exist on remote (remote branches won't be affected)
      git branch -vv | grep -v '\*' | grep 'gone]' | awk '{print $1}' | xargs git branch -D
      local branches=$(git branch -vv | grep 'gone]')
      if [ -n "$branches" ]; then
        echo ""
        echo "The following branches have not been deleted:"
        git branch -vv | grep 'gone]'
      fi
  else
      echo "Operation cancelled."
  fi    
}

alias clone='git clone'