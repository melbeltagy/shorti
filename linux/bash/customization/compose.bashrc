function dc() {
  if [ -z $1 ]; then
    echo "What command? Options: up, stop, down, or pull?";
  elif [ $1 == "up" ]; then
    if [ -z $2 ]; then
      echo "Starting all containers in compose..."
      docker compose up -d
    else
      echo "Starting container in compose for profile $2..."
      docker compose --profile $2 up -d
    fi
  elif [ $1 == "stop" ] || [ $1 == "down" ] || [ $1 == "pull" ]; then
    if [ -z $2 ]; then
      echo "Starting all containers in compose..."
      docker compose $1
    else
      echo "Starting container in compose for profile $2..."
      docker compose --profile $2 $1
    fi
  else
    echo "What command? Options: up, stop, or down?";
  fi
}
