# Docker container management function
function d() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: d <command> [pattern ...] [user]"
    echo "Commands:"
    echo "  ls [pattern ...]              List all containers (optionally filter by one or more patterns)"
    echo "  lsp [pattern ...]             List containers with ports (optionally filter by one or more patterns)"
    echo "  lsv [volume ...]              List containers with volume info (optionally filter by one or more partial volume names)"
    echo "  bash <container> [user]       Exec into container with bash (optionally as user)"
    echo "  sh <container> [user]         Exec into container with sh (optionally as user)"
    echo "  cp to <container> <src> <dest>     Copy file/dir from host to container"
    echo "  cp from <container> <src> <dest>   Copy file/dir from container to host"
    echo "  tail <pattern>                Tail logs for containers matching pattern"
    echo "  logs [pattern]                Show logs for all or matching containers"
    echo "  rm [pattern ...]              Remove containers (all or matching patterns)"
    echo "  start [pattern ...]           Start containers (all or matching patterns)"
    echo "  stop [pattern ...]            Stop containers (all or matching patterns)"
    echo "  prune                         Remove all stopped containers (with confirmation)"
    echo ""
    echo "Examples:"
    echo "  d ls"
    echo "  d ls myapp web"
    echo "  d lsv" 
    echo "  d lsv data" 
    echo "  d lsv a13a91 1c3279d"
    echo "  d bash mycontainer"
    echo "  d bash mycontainer root"
    echo "  d cp to mycontainer ./local-file.txt /tmp/file.txt"
    echo "  d cp from mycontainer /tmp/file.txt ./local-file.txt"
    echo "  d tail web"
    echo "  d logs myapp"
    echo "  d rm oldapp tempapp"
    echo "  d stop myapp web"
    echo "  d prune"
    return
  fi

  if [ "$1" == "ls" ]; then
    shift
    if [ -z "$1" ]; then
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}"
      echo "============================================"
      echo "Found $(docker container ls -a | grep -v "CONTAINER ID" | wc -l) containers."
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
      echo "Found $(docker container ls -a | grep -v "CONTAINER ID" | wc -l) containers."
    else
      local PATTERN="$(IFS="|"; echo "$*")"
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" | grep -E "$PATTERN"
      echo "============================================"
      echo "Found $(docker container ls -a | grep -E "$PATTERN" | wc -l) containers."
    fi
  elif [ "$1" == "lsv" ]; then
    shift
    if [ -z "$1" ]; then
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Mounts}}"
      echo "============================================"
      echo "Found $(docker container ls -a | grep -v "CONTAINER ID" | wc -l) containers."
    else
      # Accept partial volume names
      local FILTERS=()
      while [ -n "$1" ]; do
        # Find all matching volume names for the partial value
        local VOLS=$(docker volume ls --format '{{.Name}}' | grep "$1")
        for v in $VOLS; do
          FILTERS+=(--filter volume="$v")
        done
        shift
      done
      if [ ${#FILTERS[@]} -eq 0 ]; then
        echo "No matching volumes found."
        return 0
      fi
      docker container ls -a "${FILTERS[@]}" --format "table {{.ID}}\t{{.Names}}\t{{.Mounts}}"
      echo "============================================"
      echo "Found $(docker container ls -a "${FILTERS[@]}" | grep -v "CONTAINER ID" | wc -l) containers."
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
  elif [ "$1" == "cp" ]; then
    if [ -z "$2" ] || [ "$2" == "help" ]; then
      echo "Usage: d cp <to|from> <container> <src> <dest>"
      echo "  to <container> <src> <dest>     Copy file/dir from host to container"
      echo "  from <container> <src> <dest>   Copy file/dir from container to host"
      echo "Examples:"
      echo "  d cp to mycontainer ./file.txt /tmp/file.txt"
      echo "  d cp from mycontainer /tmp/file.txt ./file.txt"
      return
    fi
    if [ "$2" == "to" ]; then
      if [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
        echo "Usage: d cp to <container> <src> <dest>"
        return 1
      fi
      docker cp "$4" "$3":"$5"
    elif [ "$2" == "from" ]; then
      if [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
        echo "Usage: d cp from <container> <src> <dest>"
        return 1
      fi
      docker cp "$3":"$4" "$5"
    else
      echo "Unknown cp option: $2. Use 'd cp help' for usage."
      return 1
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
      echo "Executing [$CMD] command on $(docker container ls -a | grep -v "CONTAINER ID" | wc -l) containers..."
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
  elif [ "$1" == "prune" ]; then
    read -p "This will remove all stopped containers. Continue? (y/N): " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
      docker container prune
    else
      echo "Operation cancelled."
    fi
  else
    echo "Unknown command: $1. Use 'd help' for usage."
    return 1
  fi
}
