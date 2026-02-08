#!/bin/bash
# Marshroom Claude Code Skills Installer
# Copies slash command files to the current project's .claude/commands/ directory
#
# Supports two source layouts:
#   1. Marshroom repo: .claude/commands/*.md (legacy flat layout)
#   2. marshroom-skills package: skills/*/SKILL.md (Vercel Agent Skills layout)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARSHROOM_ROOT="$(dirname "$SCRIPT_DIR")"
COMMANDS_SOURCE="$MARSHROOM_ROOT/.claude/commands"
SKILLS_SOURCE="$MARSHROOM_ROOT/marshroom-skills/skills"
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

# Skill names to install
SKILLS=("start-issue" "create-pr" "validate-pr")

installed=0
for skill in "${SKILLS[@]}"; do
    # Try Vercel Agent Skills layout first (skills/<name>/SKILL.md)
    if [ -f "$SKILLS_SOURCE/$skill/SKILL.md" ]; then
        cp "$SKILLS_SOURCE/$skill/SKILL.md" "$TARGET_DIR/$skill.md"
        echo "  Installed: $TARGET_DIR/$skill.md (from marshroom-skills package)"
        installed=$((installed + 1))
    # Fall back to legacy flat layout (.claude/commands/<name>.md)
    elif [ -f "$COMMANDS_SOURCE/$skill.md" ]; then
        cp "$COMMANDS_SOURCE/$skill.md" "$TARGET_DIR/$skill.md"
        echo "  Installed: $TARGET_DIR/$skill.md (from .claude/commands)"
        installed=$((installed + 1))
    else
        echo "  Warning: $skill not found in either source location"
    fi
done

# Also copy state-schema reference if available
if [ -f "$MARSHROOM_ROOT/marshroom-skills/references/state-schema.md" ]; then
    mkdir -p "$TARGET_DIR/../references"
    cp "$MARSHROOM_ROOT/marshroom-skills/references/state-schema.md" "$TARGET_DIR/../references/state-schema.md"
    echo "  Installed: .claude/references/state-schema.md"
fi

echo ""
echo "Done! $installed skill(s) installed to $TARGET_DIR/"
echo ""
echo "Usage in Claude Code:"
echo "  /start-issue [#N]  - Start working on a cart issue (creates branch, injects context)"
echo "  /create-pr         - Create a PR for the current issue branch"
echo "  /validate-pr       - Validate the current PR against conventions"
echo ""
echo "Optional: Install 'marsh' CLI for status updates and tmux HUD"
echo "  See: https://github.com/marshroom/marshroom"
