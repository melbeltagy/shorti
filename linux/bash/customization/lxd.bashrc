function lx() {
	if [ -z "$1" ] || [ "$1" == "help" ]; then
		echo "Usage: l <command> [pattern ...] [user]"
		echo "Commands:"
		echo "  ls [pattern ...]              		List all containers (optionally filter by one or more patterns)"
		echo "  bash <container> [user]       		Exec into container with bash (optionally as user)"
		echo "  sh <container> [user]         		Exec into container with sh (optionally as user)"
		echo "  cp to <container> <src> <dest>     	Copy file/dir from host to container"
		echo "  cp from <container> <src> <dest>   	Copy file/dir from container to host"
		echo "  rm [pattern ...]              		Remove containers (all or matching patterns)"
		echo "  start [pattern ...]           		Start containers (all or matching patterns)"
		echo "  stop [pattern ...]            		Stop containers (all or matching patterns)"
		echo ""
		echo "Examples:"
		echo "  lx ls"
		echo "  lx ls myapp web"
		echo "  lx bash mycontainer"
		echo "  lx bash mycontainer root"
		echo "  lx cp to mycontainer ./local-file.txt /tmp/file.txt"
		echo "  lx cp from mycontainer /tmp/file.txt ./local-file.txt"
		echo "  lx rm oldapp tempapp"
		echo "  lx start myapp web"
		echo "  lx stop myapp web"
		return
	fi

	if [ "$1" == "ls" ]; then
		shift
		if [ -z "$1" ]; then
			lxc list
			echo "============================================"
			echo "Found $(lxc list -c n --format csv | wc -l) containers."
		else
			local PATTERN="$(IFS="|"; echo "$*")"
			lxc list | grep -E "$PATTERN"
			echo "============================================"
			echo "Found $(lxc list -c n --format csv | grep -E "$PATTERN" | wc -l) containers."
		fi
	elif [ "$1" == "bash" ]; then
		if [ -z "$2" ]; then
			echo "Usage: l bash <container> [user]"
			return
		fi
		if [ -z "$3" ]; then
			lxc exec "$2" -- /bin/bash
		else
			lxc exec "$2" -- su - "$3" -c /bin/bash
		fi
	elif [ "$1" == "sh" ]; then
		if [ -z "$2" ]; then
			echo "Usage: l sh <container> [user]"
			return
		fi
		if [ -z "$3" ]; then
			lxc exec "$2" -- /bin/sh
		else
			lxc exec "$2" -- su - "$3" -c /bin/sh
		fi
	elif [ "$1" == "cp" ]; then
		if [ -z "$2" ] || [ "$2" == "help" ]; then
			echo "Usage: l cp <to|from> <container> <src> <dest>"
			echo "  to <container> <src> <dest>     Copy file/dir from host to container"
			echo "  from <container> <src> <dest>   Copy file/dir from container to host"
			echo "Examples:"
			echo "  l cp to mycontainer ./file.txt /tmp/file.txt"
			echo "  l cp from mycontainer /tmp/file.txt ./file.txt"
			return
		fi
		if [ "$2" == "to" ]; then
			if [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
				echo "Usage: l cp to <container> <src> <dest>"
				return
			fi
			lxc file push "$4" "$3/$5"
		elif [ "$2" == "from" ]; then
			if [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then
				echo "Usage: l cp from <container> <src> <dest>"
				return
			fi
			lxc file pull "$3/$4" "$5"
		else
			echo "Unknown cp option: $2. Use 'l cp help' for usage."
			return
		fi
	elif [ "$1" == "rm" ]; then
		shift
		if [ -z "$1" ]; then
			read -p "Removing all containers: Do you want to continue? (y/N)?" confirm
			if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
				for n in $(lxc list -c n --format csv); do
					echo "Deleting container: $n"
					lxc delete "$n" --force
				done
			else
				echo "Operation cancelled."
			fi
		else
			local PATTERN="$(IFS="|"; echo "$*")"
			local NAMES=$(lxc list -c n --format csv | grep -E "$PATTERN")
			local COUNT=$(echo "$NAMES" | wc -w)
			if [ -z "$NAMES" ]; then
				echo "No containers match the pattern."
				return
			fi
			echo "Removing the following $COUNT containers:"
			echo "$NAMES"
			read -p "Do you want to continue? (y/N)?" confirm
			if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
				for n in $NAMES; do
					echo "Deleting container: $n"
					lxc delete "$n" --force
				done
				echo "Containers removed."
			else
				echo "Operation cancelled."
			fi
		fi
	elif [ "$1" == "start" ] || [ "$1" == "stop" ]; then
		CMD="$1"
		shift
		if [ -z "$1" ]; then
			echo "Executing [$CMD] command on all containers..."
			for n in $(lxc list -c n --format csv); do
				echo "$CMD container: $n"
				lxc $CMD "$n"
			done
		else
			local PATTERN="$(IFS="|"; echo "$*")"
			local NAMES=$(lxc list -c n --format csv | grep -E "$PATTERN")
			local COUNT=$(echo "$NAMES" | wc -w)
			if [ -z "$NAMES" ]; then
				echo "No containers match the pattern."
				return
			fi
			echo "Executing [$CMD] command on $COUNT containers..."
			for n in $NAMES; do
				echo "$CMD container: $n"
				lxc $CMD "$n"
			done
		fi
	else
		echo "Unknown command: $1. Use 'l help' for usage."
		return
	fi
}
