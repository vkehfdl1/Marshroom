#!/usr/bin/env bash
# Marshroom tpm plugin entry point
# Install: set -g @plugin 'vkehfdl1/Marshroom'
# Usage:   set -g status-right '#{marshroom_status} | %H:%M'

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/cli/scripts/helpers.sh"

# ─── User options with defaults ──────────────────────────────────────

marshroom_status_interval=$(get_tmux_option "@marshroom_interval" "5")
marshroom_status_right_length=$(get_tmux_option "@marshroom_status_right_length" "80")
marshroom_open_ide_key=$(get_tmux_option "@marshroom_open_ide_key" "P")
marshroom_status_key=$(get_tmux_option "@marshroom_status_key" "I")

# ─── Status bar interpolation ────────────────────────────────────────

STATUS_SCRIPT="$CURRENT_DIR/cli/scripts/marshroom_status.sh"

marshroom_interpolation=(
  "#{marshroom_status}"
)

marshroom_commands=(
  "#($STATUS_SCRIPT #{pane_current_path})"
)

do_interpolation() {
  local result="$1"
  for ((i = 0; i < ${#marshroom_interpolation[@]}; i++)); do
    result="${result//${marshroom_interpolation[$i]}/${marshroom_commands[$i]}}"
  done
  echo "$result"
}

update_tmux_option() {
  local option="$1"
  local option_value
  option_value="$(get_tmux_option "$option")"
  local new_value
  new_value="$(do_interpolation "$option_value")"
  set_tmux_option "$option" "$new_value"
}

# Replace #{marshroom_status} in status-right and status-left
update_tmux_option "status-right"
update_tmux_option "status-left"

# ─── Settings ────────────────────────────────────────────────────────

set_tmux_option "status-interval" "$marshroom_status_interval"
set_tmux_option "status-right-length" "$marshroom_status_right_length"

# ─── Keybindings ─────────────────────────────────────────────────────

MARSH="$CURRENT_DIR/cli/marsh"

tmux bind-key "$marshroom_open_ide_key" run-shell -b "cd '#{pane_current_path}' && '$MARSH' open-ide"
tmux bind-key "$marshroom_status_key" display-popup -d '#{pane_current_path}' -E "'$MARSH' status"
