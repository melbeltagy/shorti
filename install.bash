#!/usr/bin/env bash
# Bootstrap shorti: clone (or update) the repo, then run apply.bash.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/melbeltagy/shorti/main/install.bash | bash
#
# Optional env vars:
#   SHORTI_DIR   Clone location (default: ~/shorti)
#   SHORTI_REPO  Repo URL       (default: https://github.com/melbeltagy/shorti)

set -e

REPO_URL="${SHORTI_REPO:-https://github.com/melbeltagy/shorti}"
INSTALL_DIR="${SHORTI_DIR:-$HOME/shorti}"

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not installed." >&2
  exit 1
fi

if [ -d "$INSTALL_DIR/.git" ]; then
  echo "shorti already installed at $INSTALL_DIR. Updating..."
  git -C "$INSTALL_DIR" pull --ff-only
else
  echo "Cloning shorti to $INSTALL_DIR ..."
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

bash "$INSTALL_DIR/setup/apply.bash"
