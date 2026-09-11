alias o='open .'
alias cls=clear

if command -v lsd >/dev/null 2>&1; then
    alias lls='lsd -AlhF --color=auto'
fi
alias ll='ls -AlhF --color=auto'

function print() {
    echo -e "\033[0;32m$1\033[0m"
}

# Used by every shorti dispatcher to verify the underlying CLI exists.
# Returns 127 (POSIX "command not found") with a friendly message if missing.
_shorti_require() {
    command -v "$1" >/dev/null 2>&1 && return 0
    echo "shorti: '$1' is not installed or not on PATH." >&2
    return 127
}

function aup() {
    _shorti_require apt || return $?
    print "**** Updating package lists..."
    sudo apt update
    # `upgrade`, not `full-upgrade`: with -y in play we don't want removals unprompted.
    print "**** Upgrading installed packages..."
    sudo apt upgrade -y
    print "**** Removing unnecessary packages..."
    sudo apt autoremove --purge -y && sudo apt autoclean -y
    # Same require guard, silenced: snapd is optional, so skip rather than fail.
    if _shorti_require snap 2>/dev/null; then
        print "**** Refreshing snaps..."
        _sn_refresh
    fi
    print "**** System update complete."
    if [ -f /var/run/reboot-required ]; then
        print "**** Reboot required."
        [ -r /var/run/reboot-required.pkgs ] && sort -u /var/run/reboot-required.pkgs
    fi
}

function shorti() {
    cat <<'EOF'
shorti: shell helpers

Run '<cmd> help' for the full command list of any tool.

  d        docker containers     (ls, info, rm, stats, top, pid, bash, ...)
  i        docker images         (ls, pull, rm, info, who, hist, ...)
  v        docker volumes        (ls, rm, info, who, du, ...)
  n        docker networks       (ls, info, rm, mk, conn, disc, ...)
  dc       docker compose        (ls, ps, up, down, logs, tail, ...)
  k        kubernetes (kubectl)  (get, desc, logs, ctx, ns, top, events, ...)
  lx       LXD containers        (ls, bash, sh, cp, rm, start, stop, snap, ...)
  lxi      LXD images            (ls, info, rm, pull)
  lxv      LXD storage volumes   (ls, info, rm, du)
  lxn      LXD networks          (ls, info, rm, mk, leases, conn, disc)
  lxp      LXD storage pools     (ls, info, mk, rm)
  g        git passthrough       (any git subcommand; plus l, prune)
  sn       snap                  (up, orphans, clean)
  ds       disk space            (usage, top, clean [sudo])
  aup      apt + snap update, autoremove, reboot check [sudo]

[sudo] marks commands that need root.
EOF
}
