#!/usr/bin/env bash
# marsh-enforce.sh — PostToolUse hook for Claude Code
# Automatically updates Marshroom state.json when an agent uses git/gh directly.
# Runs after every Bash tool use. Non-Marshroom repos are silently ignored.
# Failures are swallowed (|| true) to never block agent work.

set -euo pipefail

STATE_FILE="${MARSHROOM_STATE:-$HOME/.config/marshroom/state.json}"

# Read hook input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || exit 0
[[ "$TOOL_NAME" == "Bash" ]] || exit 0

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0
[[ -n "$COMMAND" ]] || exit 0

# Must have state.json to do anything
[[ -f "$STATE_FILE" ]] || exit 0

# Must have jq
command -v jq &>/dev/null || exit 0

# ─── Detect: git checkout -b Feature/#N or HotFix/#N ────────────────

if [[ "$COMMAND" =~ git[[:space:]]+checkout[[:space:]]+-b[[:space:]]+(Feature|HotFix)/#([0-9]+) ]]; then
  ISSUE_NUM="${BASH_REMATCH[2]}"
  if command -v marsh &>/dev/null; then
    marsh start "#${ISSUE_NUM}" 2>/dev/null || true
  else
    # jq fallback: set status to running
    TMP="$(mktemp "${STATE_FILE}.XXXXXX")"
    jq --argjson n "$ISSUE_NUM" '
      .cart |= map(if .issueNumber == $n then .status = "running" else . end)
    ' "$STATE_FILE" > "$TMP" && mv -f "$TMP" "$STATE_FILE" || rm -f "$TMP"
  fi
  exit 0
fi

# ─── Detect: gh pr create ───────────────────────────────────────────

if [[ "$COMMAND" =~ gh[[:space:]]+pr[[:space:]]+create ]]; then
  if command -v marsh &>/dev/null; then
    marsh pr 2>/dev/null || true
  fi
  # No jq fallback here — marsh pr needs gh pr view for PR number/URL
  exit 0
fi

# ─── Detect: git push on a /#N branch ───────────────────────────────

if [[ "$COMMAND" =~ git[[:space:]]+push ]]; then
  BRANCH=$(git branch --show-current 2>/dev/null) || exit 0
  if [[ "$BRANCH" =~ /#([0-9]+)$ ]]; then
    ISSUE_NUM="${BASH_REMATCH[1]}"
    # Only upgrade from 'soon' → 'running'
    CURRENT_STATUS=$(jq -r --argjson n "$ISSUE_NUM" '
      .cart // [] | map(select(.issueNumber == $n)) | first // {} | .status // ""
    ' "$STATE_FILE" 2>/dev/null) || exit 0
    if [[ "$CURRENT_STATUS" == "soon" ]]; then
      if command -v marsh &>/dev/null; then
        marsh start "#${ISSUE_NUM}" 2>/dev/null || true
      else
        TMP="$(mktemp "${STATE_FILE}.XXXXXX")"
        jq --argjson n "$ISSUE_NUM" '
          .cart |= map(if .issueNumber == $n then .status = "running" else . end)
        ' "$STATE_FILE" > "$TMP" && mv -f "$TMP" "$STATE_FILE" || rm -f "$TMP"
      fi
    fi
  fi
  exit 0
fi
