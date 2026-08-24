# Docker compose management function

# Resolve profile-name patterns against `docker compose config --profiles`.
# Appends '--profile <name>' pairs to DC_PROFILE_FLAGS.
# Returns 1 if patterns were given but matched nothing.
_dc_resolve_profiles() {
  [ $# -eq 0 ] && return 0
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  local matched=()
  while IFS= read -r p; do
    [ -n "$p" ] && matched+=("$p")
  done < <(docker compose config --profiles 2>/dev/null | grep -E "$PATTERN")
  if [ ${#matched[@]} -eq 0 ]; then
    echo "No profiles match pattern: $*"
    return 1
  fi
  for p in "${matched[@]}"; do
    DC_PROFILE_FLAGS+=(--profile "$p")
  done
}

# Resolve service-name patterns against `docker compose config --services`
# (under the already-resolved DC_PROFILE_FLAGS). Appends matches to DC_SERVICES.
# Returns 1 if patterns were given but matched nothing.
_dc_resolve_services() {
  [ $# -eq 0 ] && return 0
  local PATTERN
  PATTERN="$(IFS="|"; echo "$*")"
  while IFS= read -r svc; do
    [ -n "$svc" ] && DC_SERVICES+=("$svc")
  done < <(docker compose "${DC_PROFILE_FLAGS[@]}" config --services 2>/dev/null | grep -E "$PATTERN")
  if [ ${#DC_SERVICES[@]} -eq 0 ]; then
    echo "No services match pattern: $*"
    return 1
  fi
}

# Parse args into profile flags and service names.
# Args starting with ':' are profile-name patterns (e.g., :dev matches any
# profile whose name contains 'dev'). Other args are service-name patterns.
# Both are regex, combined with '|'.
# Sets globals: DC_PROFILE_FLAGS (array), DC_SERVICES (array).
# Returns 1 if any pattern group was given but matched nothing.
_dc_parse() {
  DC_PROFILE_FLAGS=()
  DC_SERVICES=()
  local PROFILE_PATTERNS=()
  local SERVICE_PATTERNS=()
  for arg in "$@"; do
    if [[ "$arg" == :* ]]; then
      PROFILE_PATTERNS+=("${arg#:}")
    else
      SERVICE_PATTERNS+=("$arg")
    fi
  done
  _dc_resolve_profiles "${PROFILE_PATTERNS[@]}" || return 1
  _dc_resolve_services "${SERVICE_PATTERNS[@]}" || return 1
}

# Echo a human-friendly description of the parsed scope.
_dc_scope_desc() {
  local parts=()
  if [ ${#DC_PROFILE_FLAGS[@]} -gt 0 ]; then
    local profiles=()
    local i=1
    while [ $i -lt ${#DC_PROFILE_FLAGS[@]} ]; do
      profiles+=("${DC_PROFILE_FLAGS[$i]}")
      i=$((i + 2))
    done
    parts+=("profile(s): ${profiles[*]}")
  fi
  if [ ${#DC_SERVICES[@]} -gt 0 ]; then
    parts+=("service(s): ${DC_SERVICES[*]}")
  fi
  if [ ${#parts[@]} -eq 0 ]; then
    echo "all services"
  else
    (IFS=", "; echo "${parts[*]}")
  fi
}

_dc_up() {
  _dc_parse "$@" || return 1
  echo "Starting $(_dc_scope_desc) (detached)..."
  docker compose "${DC_PROFILE_FLAGS[@]}" up -d "${DC_SERVICES[@]}"
}

_dc_stop() {
  _dc_parse "$@" || return 1
  echo "Stopping $(_dc_scope_desc)..."
  docker compose "${DC_PROFILE_FLAGS[@]}" stop "${DC_SERVICES[@]}"
}

_dc_down() {
  _dc_parse "$@" || return 1
  echo "Taking down $(_dc_scope_desc)..."
  docker compose "${DC_PROFILE_FLAGS[@]}" down -v "${DC_SERVICES[@]}"
}

_dc_pull() {
  _dc_parse "$@" || return 1
  echo "Pulling images for $(_dc_scope_desc)..."
  docker compose "${DC_PROFILE_FLAGS[@]}" pull "${DC_SERVICES[@]}"
}

_dc_build() {
  _dc_parse "$@" || return 1
  echo "Building images for $(_dc_scope_desc)..."
  docker compose "${DC_PROFILE_FLAGS[@]}" build "${DC_SERVICES[@]}"
}

_dc_logs() {
  _dc_parse "$@" || return 1
  echo "Showing logs for $(_dc_scope_desc)..."
  docker compose "${DC_PROFILE_FLAGS[@]}" logs "${DC_SERVICES[@]}"
}

_dc_tail() {
  _dc_parse "$@" || return 1
  echo "Tailing logs for $(_dc_scope_desc)..."
  docker compose "${DC_PROFILE_FLAGS[@]}" logs -f "${DC_SERVICES[@]}"
}

# Print "Title:" followed by indented content, optionally filtered by regex.
# If $status_fn is given, it's called as `$status_fn "$line"` for each line
# and must print "<prefix>\t<suffix>" (prefix carries the ANSI color/marker,
# printed right before the line; suffix is printed uncolored right after).
# With no status_fn, lines are printed plain.
_dc_print_section() {
  local title="$1"
  local content="$2"
  local pattern="$3"
  local status_fn="${4:-}"
  echo "$title:"
  if [ -n "$pattern" ] && [ -n "$content" ]; then
    content=$(echo "$content" | grep -E "$pattern" || true)
  fi
  if [ -z "$content" ]; then
    echo "  (none)"
  elif [ -n "$status_fn" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      local prefix suffix
      IFS=$'\t' read -r prefix suffix < <("$status_fn" "$line")
      printf '  %s%s\033[0m%s\n' "$prefix" "$line" "$suffix"
    done <<< "$content"
  else
    awk '{print "  " $0}' <<< "$content"
  fi
}

_dc_profile_status() { printf '\033[33m\t\n'; }

_dc_service_status() {
  if [ -n "${is_running[$1]+_}" ]; then
    printf '\033[32m● \t (running)\n'
  else
    printf '\033[31m○ \t (not running)\n'
  fi
}

_dc_volume_status() {
  if [ -n "${volume_size[$1]+_}" ]; then
    printf '\033[32m● \t (created - %s)\n' "${volume_size[$1]}"
  else
    printf '\033[31m○ \t (not created)\n'
  fi
}

_dc_network_status() {
  if [ -n "${network_exists[$1]+_}" ]; then
    printf '\033[32m● \t (created)\n'
  else
    printf '\033[31m○ \t (not created)\n'
  fi
}

_dc_ls() {
  local PATTERN=""
  [ -n "$1" ] && PATTERN="$(IFS="|"; echo "$*")"

  local profiles
  profiles=$(docker compose config --profiles 2>/dev/null)

  # Activate every profile so the services/volumes list also includes profile-gated ones.
  local profile_flags=()
  while IFS= read -r p; do
    [ -n "$p" ] && profile_flags+=(--profile "$p")
  done <<< "$profiles"
  local services
  services=$(docker compose "${profile_flags[@]}" config --services 2>/dev/null)
  local volumes
  volumes=$(docker compose "${profile_flags[@]}" config --volumes 2>/dev/null)
  local networks
  networks=$(docker compose "${profile_flags[@]}" config --networks 2>/dev/null)

  # Build a set of currently running services for status markers.
  local -A is_running=()
  while IFS= read -r s; do
    [ -n "$s" ] && is_running["$s"]=1
  done < <(docker compose ps --services 2>/dev/null)

  # Resolve the compose project name (first line of `docker compose config`)
  # so we can match volumes back to their declared name via compose labels.
  local project
  project=$(docker compose config 2>/dev/null | sed -n 's/^name: *//p;q')

  # Map each declared volume name to its disk usage, keyed by the
  # com.docker.compose.volume label (falling back to the docker volume name
  # itself, e.g. for external volumes which carry no compose labels).
  local -A volume_size=()
  while IFS='|' read -r vname vsize vlabels; do
    [ -z "$vname" ] && continue
    local key=""
    if [[ ",$vlabels," == *",com.docker.compose.project=$project,"* ]]; then
      key=$(grep -oE ',com\.docker\.compose\.volume=[^,]*,' <<< ",$vlabels," | sed -E 's/,com\.docker\.compose\.volume=([^,]*),/\1/')
    fi
    volume_size["${key:-$vname}"]="$vsize"
  done < <(docker system df -v --format '{{range .Volumes}}{{.Name}}|{{.Size}}|{{.Labels}}\n{{end}}' 2>/dev/null)

  # Same idea for networks, keyed by com.docker.compose.network (falling back
  # to the docker network name itself for external networks).
  local -A network_exists=()
  while IFS='|' read -r nname nlabels; do
    [ -z "$nname" ] && continue
    local key=""
    if [[ ",$nlabels," == *",com.docker.compose.project=$project,"* ]]; then
      key=$(grep -oE ',com\.docker\.compose\.network=[^,]*,' <<< ",$nlabels," | sed -E 's/,com\.docker\.compose\.network=([^,]*),/\1/')
    fi
    network_exists["${key:-$nname}"]=1
  done < <(docker network ls --format '{{.Name}}|{{.Labels}}' 2>/dev/null)

  _dc_print_section "Profiles" "$profiles" "$PATTERN" _dc_profile_status
  echo ""
  _dc_print_section "Services" "$services" "$PATTERN" _dc_service_status
  echo ""
  _dc_print_section "Volumes" "$volumes" "$PATTERN" _dc_volume_status
  echo ""
  _dc_print_section "Networks" "$networks" "$PATTERN" _dc_network_status
}

_dc_ps() {
  local FMT="table {{.ID}}\t{{.Name}}\t{{.Service}}\t{{.Image}}\t{{.CreatedAt}}\t{{.State}}\t{{.Status}}"
  if [ $# -eq 0 ]; then
    docker compose ps --format "$FMT"
    return
  fi
  _dc_parse "$@" || return 1
  docker compose "${DC_PROFILE_FLAGS[@]}" ps --format "$FMT" "${DC_SERVICES[@]}"
}

_dc_help() {
  cat <<'EOF'
Usage: dc <command> [:profile ...] [service-pattern ...]

  Args prefixed with ':' are profile-name patterns (e.g., :dev).
  Other args are service-name patterns. Both are regex, combined with '|'.

Commands:
  ls     [pattern ...]                  List profiles, services, volumes, and networks defined in the compose file
  ps     [:profile ...] [service ...]   List running compose containers
  up     [:profile ...] [service ...]   Start services (detached)
  stop   [:profile ...] [service ...]   Stop services
  down   [:profile ...] [service ...]   Take down services (-v)
  pull   [:profile ...] [service ...]   Pull images
  build  [:profile ...] [service ...]   Build images
  logs   [:profile ...] [service ...]   Show logs
  tail   [:profile ...] [service ...]   Follow (-f) logs

Examples:
  dc ls                       List all profiles, services, volumes, and networks
  dc ls web                   Filter profiles/services/volumes/networks matching 'web'
  dc ps                       List running compose containers
  dc ps :dev web              Running services in 'dev' profile matching 'web'
  dc up                       Start everything
  dc up :dev :base            Start everything in the 'dev' and 'base' profiles
  dc up web                   Start services matching 'web'
  dc up :dev web db           In 'dev' profile, start services matching 'web' or 'db'
  dc tail web                 Follow logs for services matching 'web'
  dc down :prod
EOF
}

function dc() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _dc_help; return; fi
  _shorti_require docker || return $?
  local CMD="$1"
  shift
  case "$CMD" in
    ls)    _dc_ls "$@" ;;
    ps)    _dc_ps "$@" ;;
    up)    _dc_up "$@" ;;
    stop)  _dc_stop "$@" ;;
    down)  _dc_down "$@" ;;
    pull)  _dc_pull "$@" ;;
    build) _dc_build "$@" ;;
    logs)  _dc_logs "$@" ;;
    tail)  _dc_tail "$@" ;;
    *)     echo "Unknown command: $CMD" >&2; echo "" >&2; _dc_help >&2; return 1 ;;
  esac
}
