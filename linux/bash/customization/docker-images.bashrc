# Docker images management function
function i() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: i <command> [pattern ...]"
    echo "Commands:"
    echo "  ls [pattern ...]              List all images (optionally filter by one or more patterns)"
    echo "  update [pattern ...]          Pull all or matching images"
    echo "  rm [pattern ...]              Remove images matching one or more patterns"
    echo "  inspect [pattern ...]         Inspect images matching one or more patterns"
    echo "  prune                         Remove unused images (with confirmation)"
    echo ""
    echo "Examples:"
    echo "  i ls"
    echo "  i ls ubuntu alpine"
    echo "  i update"
    echo "  i update ubuntu alpine"
    echo "  i rm oldimage tempimage"
    echo "  i inspect myimage"
    echo "  i inspect ubuntu alpine"
    echo "  i prune"
    return
  fi

  if [ "$1" == "ls" ]; then
    shift
    if [ -z "$1" ]; then
      docker image ls
      echo "============================================"
      echo "Found $(docker image ls | grep -v 'IMAGE ID' | wc -l) images."
    else
      local PATTERN="$(IFS="|"; echo "$*")"
      docker image ls | grep -E "$PATTERN"
      echo "============================================"
      echo "Found $(docker image ls | grep -E "$PATTERN" | wc -l) images."
    fi
  elif [ "$1" == "update" ]; then
    shift
    if [ -z "$1" ]; then
      echo "Updating all images..."
      docker image ls | grep -v REPOSITORY | awk -v col=':' '{print $1col$2}' | xargs -I {} docker pull {}
    else
      local PATTERN="$(IFS="|"; echo "$*")"
      local IMAGES=$(docker image ls | grep -E "$PATTERN" | awk '{print $1":"$2}')
      if [ -z "$IMAGES" ]; then
        echo "No images match the pattern."
        return 1
      fi
      echo "Updating images matching: $PATTERN"
      for img in $IMAGES; do
        echo "Pulling $img ..."
        docker pull "$img"
      done
    fi
  elif [ "$1" == "rm" ]; then
    shift
    if [ -z "$1" ]; then
      echo "Which image to delete? Specify one or more patterns."
      return 1
    fi
    local PATTERN="$(IFS="|"; echo "$*")"
    local COUNT=$(docker image ls | grep -E "$PATTERN" | wc -l)
    if [ $COUNT -eq 0 ]; then
      echo "No images match the pattern."
      return 1
    fi
    echo "Removing the following $COUNT images..."
    docker image ls | grep -E "$PATTERN"
    read -p "Do you want to continue? (y/N)?" confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      docker image ls | grep -E "$PATTERN" | awk '{print $3}' | xargs -r docker image rm
      echo "Images removed."
    else
      echo "Operation cancelled."
    fi
  elif [ "$1" == "inspect" ]; then
    shift
    if [ -z "$1" ]; then
      echo "Which image to inspect? Specify one or more patterns."
      return 1
    fi
    local PATTERN="$(IFS="|"; echo "$*")"
    local IMAGES=$(docker image ls | grep -E "$PATTERN" | awk '{print $3}')
    if [ -z "$IMAGES" ]; then
      echo "No images match the pattern."
      return 1
    fi
    for img in $IMAGES; do
      echo "===== Inspecting image: $img ====="
      docker image inspect "$img"
    done
  elif [ "$1" == "prune" ]; then
    read -p "This will remove all unused images. Continue? (y/N): " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      docker image prune
    else
      echo "Operation cancelled."
    fi
  else
    echo "Unknown command: $1. Use 'i help' for usage."
    return 1
  fi
}
