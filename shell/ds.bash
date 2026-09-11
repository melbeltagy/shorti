# Disk space: where it went, and reclaiming it.

# Human size of a path. `du` on an unreadable directory still exits 0 and prints
# the size of the entry itself, hence the readability test before measuring, and
# the sudo retry (never prompting) for root-only paths like the snapd cache.
_ds_size() {
  local out
  [ -e "$1" ] || { echo "-"; return; }
  if [ -r "$1" ] && [ -x "$1" ]; then
    out=$(du -sh "$1" 2>/dev/null | cut -f1)
  else
    out=$(sudo -n du -sh "$1" 2>/dev/null | cut -f1)
  fi
  [ -n "$out" ] || { echo "needs root"; return; }
  _ds_has_files "$1" && echo "$out" || echo "empty"
}

_ds_has_files() {
  [ -n "$(find "$1" -type f -print -quit 2>/dev/null)" ] ||
    [ -n "$(sudo -n find "$1" -type f -print -quit 2>/dev/null)" ]
}

# " (42M)" for a prompt, empty when the size could not be measured.
_ds_label() {
  local size
  size=$(_ds_size "$1")
  case "$size" in "needs root" | "empty" | "-") echo "" ;; *) echo " ($size)" ;; esac
}

_ds_journal_size() {
  command -v journalctl >/dev/null 2>&1 || { echo "-"; return; }
  local out
  out=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGTB]+' | head -1)
  echo "${out:-0}"
}

# Without /var/log/journal, journald keeps logs in /run (tmpfs): vacuuming then
# frees RAM, never disk.
_ds_journal_persistent() {
  [ -d /var/log/journal ]
}

_ds_journal_where() {
  _ds_journal_persistent && echo "on disk" || echo "in RAM"
}

_ds_residual() {
  command -v dpkg >/dev/null 2>&1 || return 0
  dpkg -l 2>/dev/null | awk '/^rc/ {print $2}'
}

# Disk held by old snap revisions. The listing and the byte sum live in
# snap.bash; every shell/*.bash is sourced together, so this just formats them.
_ds_old_snap_size() {
  local n bytes
  declare -F _sn_old_list >/dev/null || { echo "?"; return; }
  n=$(_sn_old_list | wc -l)
  [ "$n" -eq 0 ] && { echo "0"; return; }
  bytes=$(_sn_old_list | _sn_old_total_bytes)
  echo "$(_sn_format_bytes "$bytes") in $n"
}

_ds_confirm() {
  local reply
  read -rp "$1 (y/N): " reply
  [[ $reply == [yY] || $reply == [yY][eE][sS] ]]
}

# Mounted filesystems, minus the tmpfs/squashfs noise a snap box accumulates.
_ds_df() {
  df -h -x tmpfs -x devtmpfs -x squashfs -x overlay "$@"
}

# -x keeps ncdu on one filesystem: without it a scan of / walks into every
# /media volume and any host share, which is slow and not what you're auditing.
_ds_top() {
  _shorti_require ncdu || return $?
  ncdu -x "${1:-/}"
}

_ds_reclaimable_rows() {
  printf 'SOURCE\tAMOUNT\tRECLAIM WITH\n'
  printf 'apt cache\t%s\tds clean\n' "$(_ds_size /var/cache/apt/archives)"
  printf 'snapd cache\t%s\tds clean\n' "$(_ds_size /var/lib/snapd/cache)"
  printf 'systemd journal\t%s %s\t%s\n' "$(_ds_journal_size)" "$(_ds_journal_where)" \
    "$(_ds_journal_persistent && echo 'ds clean' || echo 'frees RAM only')"
  printf 'residual configs\t%s packages\tds clean\n' "$(_ds_residual | wc -l)"
  printf 'old snap revisions\t%s\tsn clean\n' "$(_ds_old_snap_size)"
}

_ds_usage() {
  print "**** Reclaimable"
  _ds_reclaimable_rows | column -t -s $'\t'
  echo ""
  print "**** Filesystems"
  _ds_df "$@"
}

_ds_cached_debs() {
  find /var/cache/apt/archives -maxdepth 1 -name '*.deb' -print -quit 2>/dev/null
}

_ds_clean_apt() {
  command -v apt >/dev/null 2>&1 || return 0
  [ -n "$(_ds_cached_debs)" ] || { echo "apt cache: already empty."; return 0; }
  _ds_confirm "Clear the apt cache$(_ds_label /var/cache/apt/archives)?" ||
    { echo "Skipped."; return 0; }
  sudo apt clean
}

# A size (50M) vacuums by size, a bare number (5) by file count, anything else
# (2days) by time. Without the file-count case a bare number would reach
# journalctl as --vacuum-time=5, which it reads as five seconds.
_ds_vacuum_flag() {
  case "$1" in
    *[0-9][KMGT]) echo "--vacuum-size" ;;
    *[0-9]) echo "--vacuum-files" ;;
    *) echo "--vacuum-time" ;;
  esac
}

_ds_clean_journal() {
  command -v journalctl >/dev/null 2>&1 || return 0
  _ds_journal_persistent ||
    { echo "systemd journal: $(_ds_journal_size) in RAM, no disk to reclaim."; return 0; }
  local keep="$1" flag
  flag=$(_ds_vacuum_flag "$keep")
  _ds_confirm "Vacuum the journal ($(_ds_journal_size) $(_ds_journal_where)) with $flag=$keep?" ||
    { echo "Skipped."; return 0; }
  sudo journalctl "$flag=$keep"
}

_ds_clean_residual() {
  local packages
  packages=$(_ds_residual)
  if [ -z "$packages" ]; then
    echo "Residual configs: none."
    return 0
  fi
  echo "Residual configs from removed packages:"
  echo "$packages"
  _ds_confirm "Purge these $(echo "$packages" | wc -l) leftover configs?" ||
    { echo "Skipped."; return 0; }
  echo "$packages" | xargs -r sudo apt remove --purge -y
}

_ds_clean() {
  _ds_clean_apt
  _sn_clean_cache
  _ds_clean_journal "${1:-2days}"
  _ds_clean_residual
}

_ds_help() {
  cat <<'EOF'
Usage: ds <command> [arg ...]
Commands:
  usage [path ...]   List free space per filesystem and what can be reclaimed
  top   [path]       Browse disk usage with ncdu, one filesystem only (default /)
  clean [keep]       Delete the reclaimable space, asking before each step [sudo]
                     keep = journal retention: time (2days, default), size
                     (50M), or a bare number for file count (5)

[sudo] needs root; a size 'usage' cannot read shows as 'needs root'.

Examples:
  ds usage
  ds usage /home
  ds top /var
  ds clean
  ds clean 50M
  ds clean 5
EOF
}

function ds() {
  if [ -z "$1" ] || [ "$1" == "help" ]; then _ds_help; return; fi
  local CMD="$1"
  shift
  case "$CMD" in
    usage) _ds_usage "$@" ;;
    top)   _ds_top "$@" ;;
    clean) _ds_clean "$@" ;;
    *)     echo "Unknown command: $CMD" >&2; echo "" >&2; _ds_help >&2; return 1 ;;
  esac
}
