#!/bin/bash
# Marshroom Claude Code Skills Installer
# Copies slash command files to the current project's .claude/commands/ directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARSHROOM_ROOT="$(dirname "$SCRIPT_DIR")"
COMMANDS_SOURCE="$MARSHROOM_ROOT/.claude/commands"
TARGET_DIR=".claude/commands"

echo "Marshroom Skill Installer"
echo "========================="

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository. Please run this from your project root."
    exit 1
fi

# Create target directory
mkdir -p "$TARGET_DIR"

# Copy skill files
SKILLS=("start-issue.md" "create-pr.md" "validate-pr.md")
for skill in "${SKILLS[@]}"; do
    if [ -f "$COMMANDS_SOURCE/$skill" ]; then
        cp "$COMMANDS_SOURCE/$skill" "$TARGET_DIR/$skill"
        echo "  Installed: $TARGET_DIR/$skill"
    else
        echo "  Warning: $skill not found in $COMMANDS_SOURCE"
    fi
done

echo ""
echo "Done! Skills installed to $TARGET_DIR/"
echo ""
echo "Usage in Claude Code:"
echo "  /start-issue  - Start working on the active Marshroom issue"
echo "  /create-pr    - Create a PR for the active issue"
echo "  /validate-pr  - Validate the current PR"
