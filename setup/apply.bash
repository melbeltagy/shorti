#!/usr/bin/env bash
# Apply shorti bash helpers to the current user's ~/.bashrc.
# Idempotent. No hardcoded paths: the repo can live anywhere.

# This file lives under setup/ and may get picked up by the helper-sourcing
# loop in ~/.bashrc. Do nothing when sourced; only act when executed directly.
(return 0 2>/dev/null) && return 0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKER_START='# >>> shorti >>>'
MARKER_END='# <<< shorti <<<'

if grep -qF "$MARKER_START" ~/.bashrc 2>/dev/null; then
  echo "Already applied (marker found in ~/.bashrc)."
  echo "If you moved the repo, edit or remove the block between '$MARKER_START' and '$MARKER_END' in ~/.bashrc and re-run."
  exit 0
fi

{
  echo ""
  echo "$MARKER_START"
  echo "for file in \"$REPO_ROOT\"/*/*.bash; do"
  echo "  case \"\$file\" in \"$REPO_ROOT\"/setup/*) continue ;; esac"
  echo "  [ -f \"\$file\" ] && source \"\$file\""
  echo "done"
  echo "$MARKER_END"
} >> ~/.bashrc

echo "Applied."
echo "Open a new terminal (or run 'source ~/.bashrc') to load helpers from:"
echo "  $REPO_ROOT/<folder>/*.bash"
