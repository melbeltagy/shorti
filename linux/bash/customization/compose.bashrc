function dc() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: dc <command> [profile]"
    echo "Commands:"
    echo "  up [profile]      Start all containers (or for a profile) in compose (detached)"
    echo "  stop [profile]    Stop all containers (or for a profile) in compose"
    echo "  down [profile]    Take down all containers (or for a profile) in compose"
    echo "  pull [profile]    Pull images for all containers (or for a profile) in compose"
    echo ""
    echo "Examples:"
    echo "  dc up"
    echo "  dc up dev"
    echo "  dc stop"
    echo "  dc down prod"
    echo "  dc pull"
    return
  fi

  if [ "$1" == "up" ]; then
    if [ -z "$2" ]; then
      echo "Starting all containers in compose (detached)..."
      docker compose up -d
    else
      echo "Starting containers for profile '$2' in compose (detached)..."
      docker compose --profile "$2" up -d
    fi
  elif [ "$1" == "stop" ]; then
    if [ -z "$2" ]; then
      echo "Stopping all containers in compose..."
      docker compose stop
    else
      echo "Stopping containers for profile '$2' in compose..."
      docker compose --profile "$2" stop
    fi
  elif [ "$1" == "down" ]; then
    if [ -z "$2" ]; then
      echo "Taking down all containers in compose..."
      docker compose down
    else
      echo "Taking down containers for profile '$2' in compose..."
      docker compose --profile "$2" down
    fi
  elif [ "$1" == "pull" ]; then
    if [ -z "$2" ]; then
      echo "Pulling images for all containers in compose..."
      docker compose pull
    else
      echo "Pulling images for profile '$2' in compose..."
      docker compose --profile "$2" pull
    fi
  else
    echo "Unknown command: $1. Use 'dc help' for usage."
  fi
}
