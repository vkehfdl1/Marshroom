#!/usr/bin/env bash
# Marshroom tpm plugin — status bar script
# Called by tmux via #() command substitution.
# Usage: marshroom_status.sh [pane_current_path]

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MARSH="$CURRENT_DIR/../marsh"

exec "$MARSH" hud "$@"
