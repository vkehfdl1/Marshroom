# Marshroom Claude Code Skills

Custom slash commands for Claude Code that integrate with the Marshroom app.

## Skills

### `/start-issue`
Reads the active issue from `~/.config/marshroom/state.json`, verifies you're in the correct repository, and creates the appropriate branch (`Feature/#N` or `HotFix/#N`).

### `/create-pr`
Creates a Pull Request for the active issue. Automatically includes `Closes #N` in the PR body and verifies it was added correctly.

### `/validate-pr`
Validates the current PR's branch name and body against Marshroom conventions.

## Installation

### Automatic
```bash
# From your project root:
bash /path/to/marshroom/Skills/install-skill.sh
```

### Manual
Copy the files from `.claude/commands/` to your project's `.claude/commands/` directory:
```bash
mkdir -p .claude/commands
cp /path/to/marshroom/.claude/commands/*.md .claude/commands/
```

## Requirements
- `gh` CLI (GitHub CLI) must be installed and authenticated
- `git` must be available
- Marshroom app must be running with an active issue selected
