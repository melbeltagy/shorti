# Shortcuts to some docker commands
# alias d-ls='docker container ls -a --format '"'"'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}'"'"
# alias d-lsp='docker container ls -a --format '"'"'table {{.ID}}\t{{.Names}}\t{{.Ports}}'"'"

function d() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: d <command> [pattern ...] [user]"
    echo "Commands:"
    echo "  ls [pattern ...]              List all containers (optionally filter by one or more patterns)"
    echo "  lsp [pattern ...]             List containers with ports (optionally filter by one or more patterns)"
    echo "  bash <container> [user]       Exec into container with bash (optionally as user)"
    echo "  sh <container> [user]         Exec into container with sh (optionally as user)"
    echo "  tail <pattern>                Tail logs for containers matching pattern"
    echo "  logs [pattern]                Show logs for all or matching containers"
    echo "  rm [pattern ...]              Remove containers (all or matching patterns)"
    echo "  start [pattern ...]           Start containers (all or matching patterns)"
    echo "  stop [pattern ...]            Stop containers (all or matching patterns)"
    echo ""
    echo "Examples:"
    echo "  d ls"
    echo "  d ls myapp web"
    echo "  d bash mycontainer"
    echo "  d bash mycontainer root"
    echo "  d tail web"
    echo "  d logs myapp"
    echo "  d rm oldapp tempapp"
    echo "  d stop myapp web"
    return
  fi

  if [ "$1" == "ls" ]; then
    shift
    if [ -z "$1" ]; then
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}"
      echo "============================================"
      echo "Found $(docker container ls -a | grep -v \"CONTAINER ID\" | wc -l) containers."
    else
      local PATTERN="$(IFS="|"; echo "$*")"
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}" | grep -E "$PATTERN"
      echo "============================================"
      echo "Found $(docker container ls -a | grep -E "$PATTERN" | wc -l) containers."
    fi
  elif [ "$1" == "lsp" ]; then
    shift
    if [ -z "$1" ]; then
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}"
      echo "============================================"
      echo "Found $(docker container ls -a | grep -v \"CONTAINER ID\" | wc -l) containers."
    else
      local PATTERN="$(IFS="|"; echo "$*")"
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" | grep -E "$PATTERN"
      echo "============================================"
      echo "Found $(docker container ls -a | grep -E "$PATTERN" | wc -l) containers."
    fi
  elif [ "$1" == "bash" ]; then
    echo "Executing bash command on $(docker container ls -a | grep $2 | wc -l) containers..."
    if [ -z $3 ]; then
      docker exec -it $2 /bin/bash
    else
      docker exec -u $3 -it $2 /bin/bash
    fi
  elif [ "$1" == "sh" ]; then
    echo "Executing sh command on $(docker container ls -a | grep $2 | wc -l) containers..."
    if [ -z $3 ]; then
      docker exec -it $2 /bin/sh
    else
      docker exec -u $3 -it $2 /bin/sh
    fi
  elif [ "$1" == "tail" ]; then
    echo "Executing tail command on $(docker container ls -a | grep $2 | wc -l) containers..."
    d ls | grep $2 | awk '{print $1}' | xargs docker logs -f
  elif [ "$1" == "logs" ]; then
    if [ -z "$2" ]; then
      echo "Showing logs for all containers..."
      docker ps -a --format '{{.ID}}' | xargs -r -I {} sh -c 'echo "===== Logs for container: {} ====="; docker logs {}'
    else
      echo "Showing logs for containers matching '$2'..."
      docker container ls -a --format '{{.ID}}\t{{.Names}}' | grep "$2" | awk '{print $1}' | xargs -r -I {} sh -c 'echo "===== Logs for container: {} ====="; docker logs {}'
    fi
  elif [ "$1" == "rm" ]; then
    shift
    if [ -z "$1" ]; then
      read -p "Removing all containers: Do you want to continue? (y/N)?" confirm
      if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        docker rm $(docker ps -q -a)
      else
        echo "Operation cancelled."
      fi
    else
      local PATTERN="$(IFS="|"; echo "$*")"
      local COUNT=$(docker container ls -a | grep -E "$PATTERN" | wc -l)
      if [ $COUNT -eq 0 ]; then
        echo "No containers match the pattern."
        return 1
      fi
      echo "Removing the following $COUNT containers:"
      d ls | grep -E "$PATTERN"
      read -p "Do you want to continue? (y/N)?" confirm
      if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        d ls | grep -E "$PATTERN" | awk '{print $1}' | xargs docker container rm
        echo "Containers removed."
      else
        echo "Operation cancelled."
      fi
    fi
  elif [ "$1" == "start" ] || [ "$1" == "stop" ]; then
    CMD="$1"
    shift
    if [ -z "$1" ]; then
      echo "Executing [$CMD] command on $(docker container ls -a | grep -v \"CONTAINER ID\" | wc -l) containers..."
      docker $CMD $(docker ps -q -a)
    else
      local PATTERN="$(IFS="|"; echo "$*")"
      local IDS=$(docker container ls -a | grep -E "$PATTERN" | awk '{print $1}')
      local COUNT=$(echo "$IDS" | wc -w)
      if [ -z "$IDS" ]; then
        echo "No containers match the pattern."
        return 1
      fi
      echo "Executing [$CMD] command on $COUNT containers..."
      echo "$IDS" | xargs -r docker container $CMD
    fi
  else
    echo "Unknown command: $1. Use 'd help' for usage."
    return 1
  fi
}

function i() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: i <command> [pattern ...]"
    echo "Commands:"
    echo "  ls [pattern ...]              List all images (optionally filter by one or more patterns)"
    echo "  update [pattern ...]          Pull all or matching images"
    echo "  rm [pattern ...]              Remove images matching one or more patterns"
    echo "  inspect [pattern ...]         Inspect images matching one or more patterns"
    echo ""
    echo "Examples:"
    echo "  i ls"
    echo "  i ls ubuntu alpine"
    echo "  i update"
    echo "  i update ubuntu alpine"
    echo "  i rm oldimage tempimage"
    echo "  i inspect myimage"
    echo "  i inspect ubuntu alpine"
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
  else
    echo "Unknown command: $1. Use 'i help' for usage."
    return 1
  fi
}

function v() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: v <command> [pattern ...]"
    echo "Commands:"
    echo "  ls [pattern ...]             List all volumes (optionally filter by one or more patterns)"
    echo "  rm [pattern ...]             Remove all or matching volumes (with confirmation)"
    echo "  inspect [pattern ...]        Inspect all or matching volumes"
    echo ""
    echo "Examples:"
    echo "  v ls"
    echo "  v ls data backup"
    echo "  v rm"
    echo "  v rm oldvolume tempvolume"
    echo "  v inspect"
    echo "  v inspect myvolume cache"
    return
  fi

  if [ "$1" == "ls" ]; then
    shift
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
  elif [ "$1" == "rm" ]; then
    shift
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
  elif [ "$1" == "inspect" ]; then
    shift
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
  else
    echo "Unknown command: $1. Use 'v help' for usage."
    return 1
  fi
}

