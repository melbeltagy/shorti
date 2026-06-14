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

# Print "Title:" followed by indented content, optionally filtered by regex
# and optionally wrapped in an ANSI color (e.g. $'\033[33m').
_dc_print_section() {
  local title="$1"
  local content="$2"
  local pattern="$3"
  local color="${4:-}"
  echo "$title:"
  if [ -n "$pattern" ] && [ -n "$content" ]; then
    content=$(echo "$content" | grep -E "$pattern" || true)
  fi
  if [ -z "$content" ]; then
    echo "  (none)"
  elif [ -n "$color" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      printf '  %s%s\033[0m\n' "$color" "$line"
    done <<< "$content"
  else
    awk '{print "  " $0}' <<< "$content"
  fi
}

_dc_ls() {
  local PATTERN=""
  [ -n "$1" ] && PATTERN="$(IFS="|"; echo "$*")"

  local profiles
  profiles=$(docker compose config --profiles 2>/dev/null)

  # Activate every profile so the services list also includes profile-gated ones.
  local profile_flags=()
  while IFS= read -r p; do
    [ -n "$p" ] && profile_flags+=(--profile "$p")
  done <<< "$profiles"
  local services
  services=$(docker compose "${profile_flags[@]}" config --services 2>/dev/null)

  # Build a set of currently running services for status markers.
  local -A is_running=()
  while IFS= read -r s; do
    [ -n "$s" ] && is_running["$s"]=1
  done < <(docker compose ps --services 2>/dev/null)

  _dc_print_section "Profiles" "$profiles" "$PATTERN" $'\033[33m'
  echo ""

  echo "Services:"
  local filtered="$services"
  [ -n "$PATTERN" ] && [ -n "$services" ] && filtered=$(echo "$services" | grep -E "$PATTERN" || true)
  if [ -z "$filtered" ]; then
    echo "  (none)"
  else
    while IFS= read -r s; do
      [ -z "$s" ] && continue
      if [ -n "${is_running[$s]+_}" ]; then
        printf '  \033[32m● %s\033[0m\n' "$s"
      else
        printf '  \033[31m○ %s\033[0m\n' "$s"
      fi
    done <<< "$filtered"
  fi
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
  ls     [pattern ...]                  List profiles and services defined in the compose file
  ps     [:profile ...] [service ...]   List running compose containers
  up     [:profile ...] [service ...]   Start services (detached)
  stop   [:profile ...] [service ...]   Stop services
  down   [:profile ...] [service ...]   Take down services (-v)
  pull   [:profile ...] [service ...]   Pull images
  build  [:profile ...] [service ...]   Build images
  logs   [:profile ...] [service ...]   Show logs
  tail   [:profile ...] [service ...]   Follow (-f) logs

Examples:
  dc ls                       List all profiles and services
  dc ls web                   Filter profiles/services matching 'web'
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
