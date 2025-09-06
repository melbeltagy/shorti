# Shortcuts to some docker commands
# alias d-ls='docker container ls -a --format '"'"'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}'"'"
# alias d-lsp='docker container ls -a --format '"'"'table {{.ID}}\t{{.Names}}\t{{.Ports}}'"'"

function d() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: d <command> [container] [user]"
    echo "Commands:"
    echo "  ls [pattern]         List all containers (optionally filter by pattern)"
    echo "  lsp [pattern]        List containers with ports (optionally filter by pattern)"
    echo "  bash <container> [user]  Exec into container with bash (optionally as user)"
    echo "  sh <container> [user]    Exec into container with sh (optionally as user)"
    echo "  tail <pattern>        Tail logs for containers matching pattern"
    echo "  log                   Show logs for all containers"
    echo "  rm [pattern]          Remove containers (all or matching pattern)"
    echo "  start|stop [pattern]  Start/stop containers (all or matching pattern)"

  elif [ $1 == "ls" ]; then
    if [ -z $2 ]; then
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}"
      echo "============================================"
      echo "Found $(docker container ls -a | grep -vv "CONTAINER ID" | wc -l) containers."
    else
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}\t{{.Networks}}" | grep $2
      echo "============================================"
      echo "Found $(docker container ls -a | grep $2 | wc -l) containers."
    fi

  elif [ $1 == "lsp" ]; then
    if [ -z $2 ]; then
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}"
      echo "============================================"
      echo "Found $(docker container ls -a | grep -vv "CONTAINER ID" | wc -l) containers."
    else
      docker container ls -a --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" | grep $2
      echo "============================================"
      echo "Found $(docker container ls -a | grep $2 | wc -l) containers."
    fi

  elif [ $1 == "bash" ]; then
    echo "Executing bash command on $(docker container ls -a | grep $2 | wc -l) containers..."
    if [ -z $3 ]; then
      docker exec -it $2 /bin/bash
    else
      docker exec -u $3 -it $2 /bin/bash
    fi

  elif [ $1 == "sh" ]; then
    echo "Executing sh command on $(docker container ls -a | grep $2 | wc -l) containers..."
    if [ -z $3 ]; then
      docker exec -it $2 /bin/sh
    else
      docker exec -u $3 -it $2 /bin/sh
    fi

  elif [ $1 == "tail" ]; then
    echo "Executing tail command on $(docker container ls -a | grep $2 | wc -l) containers..."
    d ls | grep $2 | awk '{print $1}' | xargs docker logs -f

  elif [ $1 == "log" ]; then
    echo "Executing log command on $(docker container ls -a | grep -vv "CONTAINER ID" | wc -l) containers..."
    docker $1 $(docker ps -q -a)

  elif [ $1 == "rm" ]; then
    if [ -z $2 ]; then
      read -p "Removing all containers: Do you want to continue? (y/N)?" confirm
      if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        docker rm $(docker ps -q -a)
      else
        echo "Operation cancelled."
      fi

    else
      shift
      local PATTERN="$(IFS="|"; echo "$*")"
      echo "Removing the following $(docker container ls -a | grep -E $PATTERN | wc -l) containers:"
      d ls | grep -E $PATTERN
      read -p "Do you want to continue? (y/N)?" confirm
      if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        d ls | grep -E $PATTERN | awk '{print $1}' | xargs docker container rm
        echo "Containers removed."
      else
        echo "Operation cancelled."
      fi
    fi

  else
    # start, stop
    if [ -z $2 ]; then
      echo "Executing [$1] command on $(docker container ls -a | grep -vv "CONTAINER ID" | wc -l) containers..."
      docker $1 $(docker ps -q -a)
    else
      echo "Executing [$1] command on $(docker container ls -a | grep $2 | wc -l) containers..."
      docker container ls -a | grep $2 | awk '{print $1}' | xargs docker container $1
    fi
  fi
}

function i() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: i <command> [pattern]"
    echo "Commands:"
    echo "  ls [pattern]         List all images (optionally filter by pattern)"
    echo "  update all           Pull all images"
    echo "  rm <pattern>         Remove images matching pattern"

  else
    if [ $1 == "ls" ]; then
      docker image ls
      echo "============================================"
      echo "Found $(docker image ls | grep -vv "IMAGE ID" | wc -l) images."

    elif [ $1 == "update" ] && [ $2 == "all" ]; then
      echo "Updating all images..."
      docker image ls | grep -v REPOSITORY | awk -v col=':' '{print $1col$2}' | xargs -I {} docker pull {}

    elif [ $1 == "rm" ]; then
      if [ -z $2 ]; then
        echo "Which image to delete?";
      else
        shift
        local PATTERN="$(IFS="|"; echo "$*")"
        echo "Removing the following $(docker image ls -a | grep -E $PATTERN | wc -l) images..."
        docker image ls | grep -E $PATTERN
        read -p "Do you want to continue? (y/N)?" confirm
        if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
          docker image ls | grep -E $PATTERN | awk '{print $3}' | xargs docker image rm
          echo "Images removed."

        else
          echo "Operation cancelled."
        fi
      fi
    fi
  fi
}

