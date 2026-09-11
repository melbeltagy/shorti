# Snap helpers: refresh, plus reports on what a snap install accumulates.

_sn_refresh() {
  sudo snap refresh
}

_sn_yaml_field() {
  local file="/snap/$1/current/meta/snap.yaml"
  [ -r "$file" ] || return 0
  awk -v k="$2:" '$1 == k {print $2; exit}' "$file"
}

_sn_is_base() {
  [ "$(_sn_yaml_field "$1" type)" = base ]
}

_sn_format_bytes() {
  awk -v b="${1:-0}" 'BEGIN {
    split("B KB MB GB TB", u, " ")
    i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf (i == 1 ? "%d%s\n" : "%.1f%s\n"), b, u[i]
  }'
}

# The blobs are root-only but the directory holding them is world-readable,
# so their sizes need no privileges.
_sn_revision_bytes() {
  stat -c %s "/var/lib/snapd/snaps/$1_$2.snap" 2>/dev/null || echo 0
}

_sn_print_table() {
  local title="$1" header="$2" rows
  rows=$(cat)
  [ -n "$title" ] && print "$title"
  if [ -z "$rows" ]; then
    echo "None."
  else
    { printf '%s\n' "$header"; printf '%s\n' "$rows" | sort; } | column -t -s $'\t'
  fi
}

# --- old revisions ---------------------------------------------------------

_sn_old_list() {
  snap list --all 2>/dev/null | awk 'NR>1 && $NF ~ /disabled/ {print $1 "\t" $3}'
}

_sn_sized_total() {
  awk -F'\t' '{t += $3} END {print t + 0}'
}

_sn_old_total_bytes() {
  _sn_old_with_sizes | _sn_sized_total
}

_sn_old_with_sizes() {
  local name rev
  while IFS=$'\t' read -r name rev; do
    printf '%s\t%s\t%s\n' "$name" "$rev" "$(_sn_revision_bytes "$name" "$rev")"
  done
}

_sn_match() {
  local pattern
  [ $# -eq 0 ] && { cat; return; }
  pattern="$(IFS="|"; echo "$*")"
  awk -F'\t' -v p="$pattern" '$1 ~ p'
}

_sn_size_rows() {
  local name rev bytes
  while IFS=$'\t' read -r name rev bytes; do
    printf '%s\t%s\t%s\n' "$name" "$rev" "$(_sn_format_bytes "$bytes")"
  done
}

_sn_confirm() {
  local reply
  read -rp "$1 (y/N): " reply
  [[ $reply == [yY] || $reply == [yY][eE][sS] ]]
}

_sn_remove_revisions() {
  local name rev
  while IFS=$'\t' read -r name rev _; do
    sudo snap remove "$name" --revision="$rev"
  done
}

_sn_clean_revisions() {
  local sized count total
  sized=$(_sn_old_list | _sn_match "$@" | _sn_old_with_sizes)
  if [ -z "$sized" ]; then
    echo "Old revisions: none."
    return 0
  fi
  count=$(printf '%s\n' "$sized" | wc -l)
  total=$(printf '%s\n' "$sized" | _sn_sized_total)

  printf '%s\n' "$sized" | _sn_size_rows | _sn_print_table "" $'SNAP\tREVISION\tON DISK'
  _sn_confirm "Remove $count old revision(s), freeing $(_sn_format_bytes "$total")?" ||
    { echo "Skipped."; return 0; }
  printf '%s\n' "$sized" | _sn_remove_revisions
}

_sn_clean_orphans() {
  local names name
  names=$( { _sn_orphan_bases
             _sn_content_rows | _sn_provider_status | _sn_orphan_providers | cut -f1
           } | sort -u | _sn_match "$@")
  if [ -z "$names" ]; then
    echo "Orphans: none."
    return 0
  fi
  printf '%s\n' "$names"
  _sn_confirm "Remove $(printf '%s\n' "$names" | wc -l) orphaned snap(s) entirely?" ||
    { echo "Skipped."; return 0; }
  while IFS= read -r name; do
    sudo snap remove --purge "$name"
  done <<< "$names"
}

# Only with a warm sudo timestamp: reading the size is not worth a password
# prompt. Sums the files, because du on the directory reports its own 4K entry
# even when the cache is empty.
_sn_cache_bytes() {
  sudo -n true 2>/dev/null || return 0
  sudo -n find /var/lib/snapd/cache -type f -printf '%s\n' 2>/dev/null |
    awk '{t += $1} END {print t + 0}'
}

_sn_clean_cache() {
  [ -d /var/lib/snapd/cache ] || return 0
  local bytes
  bytes=$(_sn_cache_bytes)
  [ "$bytes" = "0" ] && { echo "snapd cache: already empty."; return 0; }
  _sn_confirm "Clear the snapd download cache${bytes:+ ($(_sn_format_bytes "$bytes"))}?" ||
    { echo "Skipped."; return 0; }
  sudo find /var/lib/snapd/cache -mindepth 1 -delete
}

_sn_clean() {
  _sn_clean_revisions "$@"
  echo ""
  _sn_clean_orphans "$@"
  # The download cache is shared, so a pattern cannot scope it.
  [ $# -eq 0 ] || return 0
  echo ""
  _sn_clean_cache
}

# --- orphans ---------------------------------------------------------------

# The interface column reads `content[<tag>]` once a connection exists and plain
# `content` while it doesn't, so both spellings have to match. A slot with no
# snap prefix (":cups") belongs to the system.
_sn_content_rows() {
  local iface plug slot state
  while read -r iface plug slot _; do
    case "$iface" in content | content\[*\]) ;; *) continue ;; esac
    if [ "$slot" != "-" ]; then
      [ -z "${slot%%:*}" ] && continue
      state=free
      [ "$plug" != "-" ] && state=connected
      printf 'slot\t%s\t%s\t%s\n' "${slot%%:*}" "${slot#*:}" "$state"
    elif [ "$plug" != "-" ]; then
      printf 'plug\t%s\t%s\n' "${plug#*:}" "${plug%%:*}"
    fi
  done < <(snap connections --all 2>/dev/null)
}

# provider <TAB> orphan|stale <TAB> slots <TAB> consumers. A provider with any
# connected slot is in use and never reported. A free slot whose plug name a
# disconnected consumer asks for makes the provider stale, not orphaned.
_sn_provider_status() {
  local -A connected=() unplugged=() wanted=()
  local kind first second state provider slot unused claimed

  while IFS=$'\t' read -r kind first second state; do
    if [ "$kind" = plug ]; then
      wanted[$first]="${wanted[$first]:+${wanted[$first]} }$second"
    elif [ "$state" = connected ]; then
      connected[$first]=1
    else
      unplugged[$first]="${unplugged[$first]:+${unplugged[$first]} }$second"
    fi
  done

  for provider in "${!unplugged[@]}"; do
    [ -n "${connected[$provider]:-}" ] && continue
    unused=""
    claimed=""
    for slot in ${unplugged[$provider]}; do
      if [ -n "${wanted[$slot]:-}" ]; then
        claimed=1
        printf '%s\tstale\t%s\t%s\n' "$provider" "$slot" "${wanted[$slot]}"
      else
        unused="${unused:+$unused }$slot"
      fi
    done
    if [ -z "$claimed" ] && [ -n "$unused" ]; then
      printf '%s\torphan\t%s\t\n' "$provider" "$unused"
    fi
  done
}

_sn_orphan_bases() {
  local installed used name
  installed=$(snap list 2>/dev/null | awk 'NR>1 {print $1}')
  used=$(while IFS= read -r name; do _sn_yaml_field "$name" base; done <<< "$installed" | sort -u)
  while IFS= read -r name; do
    [ "$name" = snapd ] && continue
    _sn_is_base "$name" || continue
    printf '%s\n' "$used" | grep -qx "$name" && continue
    echo "$name"
  done <<< "$installed"
}

_sn_stale_providers() {
  awk -F'\t' '$2 == "stale" {print $1 "\t" $3 "\t" $4}'
}

_sn_orphan_providers() {
  local provider status slots
  while IFS=$'\t' read -r provider status slots _; do
    [ "$status" = orphan ] || continue
    [ "$provider" = snapd ] && continue
    _sn_is_base "$provider" && continue
    printf '%s\t%s\n' "$provider" "$slots"
  done
}

_sn_orphans() {
  local status bases orphans stale
  status=$(_sn_content_rows | _sn_provider_status)
  bases=$(_sn_orphan_bases | awk '{print $1 "\tsudo snap remove " $1}')
  orphans=$(printf '%s\n' "$status" | _sn_orphan_providers | awk -F'\t' '{print $0 "\tsudo snap remove " $1}')
  stale=$(printf '%s\n' "$status" | _sn_stale_providers)

  printf '%s\n' "$bases" |
    _sn_print_table "**** Bases no installed snap declares" $'BASE\tSUGGESTION'
  echo ""
  printf '%s\n' "$orphans" |
    _sn_print_table "**** Content providers with no connected consumer" $'PROVIDER\tUNUSED SLOTS\tSUGGESTION'
  echo ""
  printf '%s\n' "$stale" |
    _sn_print_table "**** Wanted but disconnected (not orphans, do not remove)" $'PROVIDER\tSLOT\tCONSUMER'
  [ -n "$stale" ] && echo "Reconnect with: sudo snap connect <consumer>:<plug> <provider>:<slot>"

}

_sn_help() {
  cat <<'EOF'
Usage: sn <command> [pattern ...]
Commands:
  up                   Refresh all installed snaps                      [sudo]
  orphans              List bases and content providers nothing uses
  clean [pattern ...]  Remove old revisions, then orphans (inferred: verify
                       with 'snap connections'). Without a pattern it also
                       clears the shared download cache                 [sudo]

[sudo] needs root; 'orphans' changes nothing.

Examples:
  sn up
  sn orphans
  sn clean
  sn clean code firefox
EOF
}

function sn() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _sn_help; return; fi
  _shorti_require snap || return $?
  local CMD="$1"
  shift
  case "$CMD" in
    up)      _sn_refresh ;;
    orphans) _sn_orphans ;;
    clean)   _sn_clean "$@" ;;
    *)       echo "Unknown command: $CMD" >&2; echo "" >&2; _sn_help >&2; return 1 ;;
  esac
}
