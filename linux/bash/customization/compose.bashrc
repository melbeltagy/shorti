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

function dc() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then
    echo "Usage: dc <command> [:profile ...] [service-pattern ...]"
    echo ""
    echo "  Args prefixed with ':' are profile-name patterns (e.g., :dev)."
    echo "  Other args are service-name patterns. Both are regex, combined with '|'."
    echo ""
    echo "Commands:"
    echo "  up     [:profile ...] [service ...]   Start services (detached)"
    echo "  stop   [:profile ...] [service ...]   Stop services"
    echo "  down   [:profile ...] [service ...]   Take down services (-v)"
    echo "  pull   [:profile ...] [service ...]   Pull images"
    echo "  build  [:profile ...] [service ...]   Build images"
    echo "  logs   [:profile ...] [service ...]   Show logs"
    echo "  tail   [:profile ...] [service ...]   Follow (-f) logs"
    echo ""
    echo "Examples:"
    echo "  dc up                       Start everything"
    echo "  dc up :dev :base            Start everything in the 'dev' and 'base' profiles"
    echo "  dc up web                   Start services matching 'web'"
    echo "  dc up :dev web db           In 'dev' profile, start services matching 'web' or 'db'"
    echo "  dc tail web                 Follow logs for services matching 'web'"
    echo "  dc down :prod"
    return
  fi

  local CMD="$1"
  shift
  case "$CMD" in
    up)    _dc_up "$@" ;;
    stop)  _dc_stop "$@" ;;
    down)  _dc_down "$@" ;;
    pull)  _dc_pull "$@" ;;
    build) _dc_build "$@" ;;
    logs)  _dc_logs "$@" ;;
    tail)  _dc_tail "$@" ;;
    *)     echo "Unknown command: $CMD. Use 'dc help' for usage."; return 1 ;;
  esac
}
